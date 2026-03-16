#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path


def load_json(path: Path):
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in {path}: {exc}") from exc


def resolve_path(root: Path, value: str | None):
    if not value:
        return None
    p = Path(value)
    return p if p.is_absolute() else root / p


def _is_under(path_str: str, root: Path):
    try:
        resolved = Path(path_str).expanduser().resolve()
    except OSError:
        return False
    return resolved == root or root in resolved.parents


def _path_list_contains_under(value: str, root: Path):
    for part in value.split(os.pathsep):
        candidate = part.strip()
        if candidate and _is_under(candidate, root):
            return True
    return False


def configure_runtime_env(repo_root: Path):
    """Keep Nextflow/Conda runtime paths pinned to repo-root caches."""
    bad_conda_root = repo_root / "pipelines" / ".conda"
    defaults = {
        "NXF_HOME": str(repo_root / ".nextflow"),
        "CONDA_ENVS_PATH": str(repo_root / ".conda" / "envs"),
        "CONDA_PKGS_DIRS": str(repo_root / ".conda" / "pkgs"),
    }

    for key, default_value in defaults.items():
        current = os.environ.get(key, "").strip()
        if not current:
            os.environ[key] = default_value
            continue
        if _path_list_contains_under(current, bad_conda_root):
            print(
                f"Warning: overriding {key}={current} (must not use pipelines/.conda)",
                file=sys.stderr,
            )
            os.environ[key] = default_value


def read_threads(user_config: Path):
    if not user_config.exists():
        return None
    pattern = re.compile(r"^[\s]*threads[\s]*=[\s]*([0-9]+)")
    with user_config.open("r", encoding="utf-8") as handle:
        for line in handle:
            match = pattern.search(line)
            if match:
                return int(match.group(1))
    return None


def ensure_nextflow():
    if shutil_which("nextflow") is None:
        raise SystemExit("Error: nextflow was not found in PATH")


def ensure_conda():
    conda_exe = os.environ.get("CONDA_EXE")
    if conda_exe and Path(conda_exe).is_file():
        os.environ["PATH"] = f"{Path(conda_exe).parent}:{os.environ.get('PATH','')}"
        return
    if shutil_which("conda") is None:
        raise SystemExit(
            "Error: conda was not found in PATH. Set PATH or CONDA_EXE to your conda binary."
        )


def shutil_which(cmd: str):
    for path_dir in os.environ.get("PATH", "").split(os.pathsep):
        candidate = Path(path_dir) / cmd
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def normalize_args(args, arg_transforms):
    normalized = []
    for arg in args:
        replaced = False
        for src, dst in arg_transforms.items():
            if arg == src:
                normalized.append(dst)
                replaced = True
                break
            if arg.startswith(src + "="):
                normalized.append(dst + "=" + arg.split("=", 1)[1])
                replaced = True
                break
        if not replaced:
            normalized.append(arg)
    return normalized


def apply_flag_behaviors(args, behaviors):
    extra_args = []
    cleaned = []
    skip_lookup = {}
    for behavior in behaviors:
        key = behavior.get("key")
        if key:
            skip_lookup[key] = behavior

    for arg in args:
        handled = False
        for behavior in behaviors:
            flags = behavior.get("flags", [])
            if arg in flags or any(arg.startswith(f + "=") for f in flags):
                handled = True
                if behavior.get("drop", False):
                    break
                if behavior.get("append"):
                    extra_args.extend(behavior["append"])
                break
        if not handled:
            cleaned.append(arg)
    return cleaned, extra_args


def check_required_flag(args, spec):
    if not spec:
        return True
    names = spec.get("names", [])
    truthy = set(spec.get("truthy_values", ["true", "1"]))
    for arg in args:
        if arg in names:
            return True
        for name in names:
            if arg.startswith(name + "="):
                value = arg.split("=", 1)[1].lower()
                return value in truthy
    return False


def main():
    parser = argparse.ArgumentParser(description="Run a pipeline step from JSON config.")
    parser.add_argument("config_json", help="Path to step JSON config")
    parser.add_argument("args", nargs=argparse.REMAINDER, help="Args to pass to Nextflow")
    opts = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[2]
    configure_runtime_env(repo_root)
    cfg_path = resolve_path(repo_root, opts.config_json)
    if not cfg_path or not cfg_path.exists():
        raise SystemExit(f"Config JSON not found: {opts.config_json}")
    cfg = load_json(cfg_path)

    if cfg.get("require_conda"):
        ensure_conda()
    ensure_nextflow()

    pipeline_nf = resolve_path(repo_root, cfg.get("pipeline_nf"))
    if not pipeline_nf or not pipeline_nf.exists():
        raise SystemExit(f"Pipeline not found: {cfg.get('pipeline_nf')}")

    configs = [resolve_path(repo_root, p) for p in cfg.get("configs", [])]
    for conf in configs:
        if conf and not conf.exists():
            raise SystemExit(f"Config not found: {conf}")

    user_config = resolve_path(repo_root, cfg.get("user_config", "config/user.config"))
    threads = read_threads(user_config) if user_config else None
    if threads is None:
        threads = cfg.get("default_threads", 24)

    args = opts.args
    if args and args[0] == "--":
        args = args[1:]

    arg_transforms = cfg.get("arg_transforms", {})
    args = normalize_args(args, arg_transforms)

    if cfg.get("require_flag"):
        if not check_required_flag(args, cfg["require_flag"]):
            message = cfg["require_flag"].get(
                "message", "Required flag not set; skipping step."
            )
            print(message)
            return 0

    args, extra_args = apply_flag_behaviors(args, cfg.get("flag_behaviors", []))
    args.extend(extra_args)

    if not any(arg in ("-resume", "--resume") for arg in args):
        args.append("-resume")

    cmd = ["nextflow", "run", str(pipeline_nf)]
    for conf in configs:
        if conf:
            cmd.extend(["-c", str(conf)])
    if threads:
        cmd.extend(
            [
                "-process.maxForks",
                str(threads),
                "-executor.queueSize",
                str(threads),
                "-process.cpus",
                str(threads),
            ]
        )
    profile = cfg.get("profile")
    if profile:
        cmd.extend(["-profile", profile])
    cmd.extend(args)

    subprocess.run(cmd, check=True, cwd=str(repo_root))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
