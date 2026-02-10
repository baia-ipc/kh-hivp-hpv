#!/usr/bin/env python3
import argparse
import re
from pathlib import Path


def find_balanced_block(text, start, tag):
    token_re = re.compile(rf"<{tag}\b|</{tag}>", re.IGNORECASE)
    depth = 0
    for match in token_re.finditer(text, start):
        token = match.group(0).lower()
        if token.startswith(f"<{tag}"):
            depth += 1
        else:
            depth -= 1
            if depth == 0:
                return start, match.end()
    return None


def move_module_sections(html, section_ids):
    moved = []
    for section_id in section_ids:
        marker = f'<div id="{section_id}" class="mqc-module-section">'
        start = html.find(marker)
        if start == -1:
            continue
        bounds = find_balanced_block(html, start, "div")
        if not bounds:
            continue
        block_start, block_end = bounds
        trailing_hr = re.match(r"\s*<hr>\s*", html[block_end:])
        if trailing_hr:
            block_end += trailing_hr.end()
        moved.append(html[block_start:block_end])
        html = html[:block_start] + html[block_end:]

    if not moved:
        return html, False

    module_re = re.compile(r'<div id="(?:general_stats|mqc-module-section-[^"]+)" class="mqc-module-section">')
    all_modules = list(module_re.finditer(html))
    if all_modules:
        last_start = all_modules[-1].start()
        bounds = find_balanced_block(html, last_start, "div")
        if bounds:
            insert_pos = bounds[1]
            trailing_hr = re.match(r"\s*<hr>\s*", html[insert_pos:])
            if trailing_hr:
                insert_pos += trailing_hr.end()
        else:
            insert_pos = len(html)
    else:
        insert_pos = html.rfind("</body>")
        if insert_pos == -1:
            insert_pos = len(html)

    html = html[:insert_pos] + "".join(moved) + html[insert_pos:]
    return html, True


def move_nav_items(html, nav_anchors):
    nav_start_match = re.search(r'<ul class="mqc-nav[^"]*">', html)
    if not nav_start_match:
        return html, False

    nav_start = nav_start_match.start()
    nav_bounds = find_balanced_block(html, nav_start, "ul")
    if not nav_bounds:
        return html, False

    nav_block_start, nav_block_end = nav_bounds
    nav_block = html[nav_block_start:nav_block_end]
    moved = []

    for anchor in nav_anchors:
        anchor_token = f'href="#{anchor}" class="nav-l1"'
        anchor_pos = nav_block.find(anchor_token)
        if anchor_pos == -1:
            continue
        li_start = nav_block.rfind("<li", 0, anchor_pos)
        if li_start == -1:
            continue
        li_bounds = find_balanced_block(nav_block, li_start, "li")
        if not li_bounds:
            continue
        item_start, item_end = li_bounds
        moved.append(nav_block[item_start:item_end])
        nav_block = nav_block[:item_start] + nav_block[item_end:]

    if not moved:
        return html, False

    nav_close = nav_block.rfind("</ul>")
    if nav_close == -1:
        return html, False
    nav_block = nav_block[:nav_close] + "".join(moved) + nav_block[nav_close:]
    html = html[:nav_block_start] + nav_block + html[nav_block_end:]
    return html, True


def main():
    parser = argparse.ArgumentParser(
        description="Move selected MultiQC sections and nav entries to the bottom."
    )
    parser.add_argument("--report", required=True, help="Path to the MultiQC HTML report")
    parser.add_argument(
        "--section-id",
        action="append",
        dest="section_ids",
        default=[],
        help='Section div id (e.g. "general_stats", "mqc-module-section-bcftools")',
    )
    parser.add_argument(
        "--nav-anchor",
        action="append",
        dest="nav_anchors",
        default=[],
        help='Nav href anchor without "#", e.g. "general_stats"',
    )
    args = parser.parse_args()

    report_path = Path(args.report)
    html = report_path.read_text(encoding="utf-8")

    html, _ = move_module_sections(html, args.section_ids)
    html, _ = move_nav_items(html, args.nav_anchors)

    report_path.write_text(html, encoding="utf-8")


if __name__ == "__main__":
    main()
