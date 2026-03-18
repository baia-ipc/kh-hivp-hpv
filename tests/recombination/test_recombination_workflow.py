from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.recombination.prepare_recombination_inputs import collapse_duplicate_records
from scripts.recombination.run_3seq import parse_rec_file
from scripts.recombination.recombination_utils import determine_final_status, read_tsv, write_tsv


class RecombinationWorkflowTests(unittest.TestCase):
    def test_collapse_duplicate_records_prefers_sample_representatives(self) -> None:
        manifest, duplicate_rows = collapse_duplicate_records(
            [
                {
                    "analysis_group": "HPV16",
                    "run_id": "04",
                    "sample_id": "KHCA-001",
                    "hpv_type": "HPV16",
                    "sequence_role": "sample",
                    "background_source": "none",
                    "source_fasta": "sample.fa",
                    "source_record_id": "sample",
                    "display_name": "04:KHCA-001",
                    "normalized_record_id": "HPV16|sample|04:KHCA-001",
                    "sequence_length": 10,
                    "sequence_hash": "same",
                    "sequence": "AAAA",
                },
                {
                    "analysis_group": "HPV16",
                    "run_id": "reference",
                    "sample_id": "RefA",
                    "hpv_type": "HPV16",
                    "sequence_role": "background",
                    "background_source": "tree_selected_same_type",
                    "source_fasta": "ref.fa",
                    "source_record_id": "ref",
                    "display_name": "RefA",
                    "normalized_record_id": "HPV16|background|RefA",
                    "sequence_length": 10,
                    "sequence_hash": "same",
                    "sequence": "AAAA",
                },
            ]
        )
        kept = [row for row in manifest if row["included_in_collapsed"] == "yes"]
        self.assertEqual(len(kept), 1)
        self.assertEqual(kept[0]["sequence_role"], "sample")
        self.assertEqual(duplicate_rows[0]["collapsed_into"], kept[0]["normalized_record_id"])

    def test_parse_3seq_rec_extracts_corrected_pvalues_and_breakpoints(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            rec_path = Path(tmpdir) / "sample.3s.rec"
            rec_path.write_text(
                "PARENT_A PARENT_B CHILD 10 12 5 1e-9 0 -9 0.0003 3e-4 600 1900 3163\n",
                encoding="utf-8",
            )
            manifest_rows = {
                "CHILD": {
                    "sequence_role": "sample",
                    "sample_id": "KHCA-001",
                }
            }

            class Args:
                analysis_group = "HPV16"
                hpv_type = "HPV16"
                pvalue_threshold = 0.01
                min_segment_length = 500

            rows = parse_rec_file(rec_path, manifest_rows, Args())
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]["candidate_sequence_role"], "sample")
            self.assertEqual(rows[0]["passes_pvalue_threshold"], "yes")
            self.assertEqual(rows[0]["candidate_breakpoint_site"], 3163)

    def test_determine_final_status(self) -> None:
        self.assertEqual(determine_final_status(True, True, True, True), "candidate_recombinant")
        self.assertEqual(determine_final_status(True, True, False, True), "inconclusive")
        self.assertEqual(determine_final_status(True, False, False, False), "alignment_signal_only")
        self.assertEqual(determine_final_status(False, False, False, False), "no_evidence")

    def test_summary_script_distinguishes_candidate_inconclusive_and_no_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            manifest = tmp / "manifest.tsv"
            duplicate_map = tmp / "duplicates.tsv"
            gard_json = tmp / "gard.json"
            gard_breakpoints = tmp / "gard.breakpoints.tsv"
            gard_summary = tmp / "gard.summary.json"
            three_seq = tmp / "3seq.tsv"
            three_seq_summary = tmp / "3seq.summary.json"
            tree_confirmation = tmp / "tree.tsv"
            read_validation = tmp / "reads.tsv"
            lineage_sets = tmp / "lineages.tsv"
            database_sets = tmp / "database.tsv"

            write_tsv(
                manifest,
                [
                    {
                        "analysis_group": "HPV16",
                        "run_id": "04",
                        "sample_id": "S_PASS",
                        "hpv_type": "HPV16",
                        "sequence_role": "sample",
                        "background_source": "none",
                        "source_fasta": "sample.fa",
                        "source_record_id": "sample1",
                        "display_name": "04:S_PASS",
                        "normalized_record_id": "REC_PASS",
                        "sequence_length": 100,
                        "sequence_hash": "a",
                        "collapsed_into": "REC_PASS",
                        "included_in_collapsed": "yes",
                    },
                    {
                        "analysis_group": "HPV16",
                        "run_id": "04",
                        "sample_id": "S_INC",
                        "hpv_type": "HPV16",
                        "sequence_role": "sample",
                        "background_source": "none",
                        "source_fasta": "sample.fa",
                        "source_record_id": "sample2",
                        "display_name": "04:S_INC",
                        "normalized_record_id": "REC_INC",
                        "sequence_length": 100,
                        "sequence_hash": "b",
                        "collapsed_into": "REC_INC",
                        "included_in_collapsed": "yes",
                    },
                    {
                        "analysis_group": "HPV16",
                        "run_id": "04",
                        "sample_id": "S_NONE",
                        "hpv_type": "HPV16",
                        "sequence_role": "sample",
                        "background_source": "none",
                        "source_fasta": "sample.fa",
                        "source_record_id": "sample3",
                        "display_name": "04:S_NONE",
                        "normalized_record_id": "REC_NONE",
                        "sequence_length": 100,
                        "sequence_hash": "c",
                        "collapsed_into": "REC_NONE",
                        "included_in_collapsed": "yes",
                    },
                ],
                [
                    "analysis_group",
                    "run_id",
                    "sample_id",
                    "hpv_type",
                    "sequence_role",
                    "background_source",
                    "source_fasta",
                    "source_record_id",
                    "display_name",
                    "normalized_record_id",
                    "sequence_length",
                    "sequence_hash",
                    "collapsed_into",
                    "included_in_collapsed",
                ],
            )
            write_tsv(duplicate_map, [], ["analysis_group", "hpv_type", "collapsed_into", "duplicate_record_id", "sequence_role", "background_source", "display_name", "sequence_hash", "reason"])
            gard_json.write_text("{}", encoding="utf-8")
            gard_summary.write_text(
                json.dumps({"n_breakpoints": 1, "breakpoints": [500], "delta_aicc_vs_no_breakpoint": 12.0, "segments": [{"start": 1, "end": 500}, {"start": 501, "end": 1000}]}) + "\n",
                encoding="utf-8",
            )
            write_tsv(
                gard_breakpoints,
                [
                    {
                        "analysis_group": "HPV16",
                        "hpv_type": "HPV16",
                        "breakpoint_id": "HPV16_BP_1",
                        "breakpoint_site": "500",
                        "left_segment_start": "1",
                        "left_segment_end": "500",
                        "right_segment_start": "501",
                        "right_segment_end": "1000",
                        "site_support": "0.75",
                        "support_strength": "high",
                        "baseline_score": "0",
                        "single_tree_aicc": "12",
                        "best_model_aicc": "0",
                        "delta_aicc_vs_no_breakpoint": "12",
                    }
                ],
                [
                    "analysis_group",
                    "hpv_type",
                    "breakpoint_id",
                    "breakpoint_site",
                    "left_segment_start",
                    "left_segment_end",
                    "right_segment_start",
                    "right_segment_end",
                    "site_support",
                    "support_strength",
                    "baseline_score",
                    "single_tree_aicc",
                    "best_model_aicc",
                    "delta_aicc_vs_no_breakpoint",
                ],
            )
            write_tsv(
                three_seq,
                [
                    {
                        "analysis_group": "HPV16",
                        "hpv_type": "HPV16",
                        "candidate_id": "C_PASS",
                        "parent_major_record_id": "P1",
                        "parent_minor_record_id": "P2",
                        "candidate_record_id": "REC_PASS",
                        "candidate_sample_id": "S_PASS",
                        "candidate_sequence_role": "sample",
                        "uncorrected_p": "1e-8",
                        "used_hogan_siegmund": "0",
                        "log10_p": "-8",
                        "corrected_p": "0.0001",
                        "corrected_p_mantissa": "1e-4",
                        "min_segment_length": "600",
                        "candidate_breakpoint_site": "500",
                        "candidate_breakpoints": "500",
                        "passes_pvalue_threshold": "yes",
                        "passes_segment_length": "yes",
                        "eligible_sample_candidate": "yes",
                    },
                    {
                        "analysis_group": "HPV16",
                        "hpv_type": "HPV16",
                        "candidate_id": "C_INC",
                        "parent_major_record_id": "P3",
                        "parent_minor_record_id": "P4",
                        "candidate_record_id": "REC_INC",
                        "candidate_sample_id": "S_INC",
                        "candidate_sequence_role": "sample",
                        "uncorrected_p": "1e-6",
                        "used_hogan_siegmund": "0",
                        "log10_p": "-6",
                        "corrected_p": "0.001",
                        "corrected_p_mantissa": "1e-3",
                        "min_segment_length": "600",
                        "candidate_breakpoint_site": "500",
                        "candidate_breakpoints": "500",
                        "passes_pvalue_threshold": "yes",
                        "passes_segment_length": "yes",
                        "eligible_sample_candidate": "yes",
                    },
                ],
                [
                    "analysis_group",
                    "hpv_type",
                    "candidate_id",
                    "parent_major_record_id",
                    "parent_minor_record_id",
                    "candidate_record_id",
                    "candidate_sample_id",
                    "candidate_sequence_role",
                    "uncorrected_p",
                    "used_hogan_siegmund",
                    "log10_p",
                    "corrected_p",
                    "corrected_p_mantissa",
                    "min_segment_length",
                    "candidate_breakpoint_site",
                    "candidate_breakpoints",
                    "passes_pvalue_threshold",
                    "passes_segment_length",
                    "eligible_sample_candidate",
                ],
            )
            three_seq_summary.write_text(json.dumps({"eligible_sample_candidates": 2}) + "\n", encoding="utf-8")
            write_tsv(
                tree_confirmation,
                [
                    {
                        "analysis_group": "HPV16",
                        "hpv_type": "HPV16",
                        "candidate_id": "C_PASS",
                        "candidate_record_id": "REC_PASS",
                        "breakpoint_site": "500",
                        "left_interval": "1-500",
                        "right_interval": "501-1000",
                        "left_parent": "P1",
                        "right_parent": "P2",
                        "left_support": "99",
                        "right_support": "99",
                        "tree_confirmation_status": "confirmed",
                        "topology_switch": "yes",
                        "bootstrap_pass": "yes",
                        "notes": "",
                    },
                    {
                        "analysis_group": "HPV16",
                        "hpv_type": "HPV16",
                        "candidate_id": "C_INC",
                        "candidate_record_id": "REC_INC",
                        "breakpoint_site": "500",
                        "left_interval": "1-500",
                        "right_interval": "501-1000",
                        "left_parent": "P3",
                        "right_parent": "P4",
                        "left_support": "70",
                        "right_support": "70",
                        "tree_confirmation_status": "not_confirmed",
                        "topology_switch": "yes",
                        "bootstrap_pass": "no",
                        "notes": "",
                    },
                ],
                [
                    "analysis_group",
                    "hpv_type",
                    "candidate_id",
                    "candidate_record_id",
                    "breakpoint_site",
                    "left_interval",
                    "right_interval",
                    "left_parent",
                    "right_parent",
                    "left_support",
                    "right_support",
                    "tree_confirmation_status",
                    "topology_switch",
                    "bootstrap_pass",
                    "notes",
                ],
            )
            write_tsv(
                read_validation,
                [
                    {
                        "analysis_group": "HPV16",
                        "hpv_type": "HPV16",
                        "candidate_id": "C_PASS",
                        "candidate_record_id": "REC_PASS",
                        "sample_id": "S_PASS",
                        "informative_site_count": "8",
                        "left_site_count": "4",
                        "right_site_count": "4",
                        "sites_passing_depth": "8",
                        "sites_passing_major_af": "8",
                        "mixed_or_ambiguous_sites": "0",
                        "read_validation_status": "pass",
                        "notes": "",
                    },
                    {
                        "analysis_group": "HPV16",
                        "hpv_type": "HPV16",
                        "candidate_id": "C_INC",
                        "candidate_record_id": "REC_INC",
                        "sample_id": "S_INC",
                        "informative_site_count": "8",
                        "left_site_count": "4",
                        "right_site_count": "4",
                        "sites_passing_depth": "8",
                        "sites_passing_major_af": "5",
                        "mixed_or_ambiguous_sites": "2",
                        "read_validation_status": "mixed_or_ambiguous",
                        "notes": "",
                    },
                ],
                [
                    "analysis_group",
                    "hpv_type",
                    "candidate_id",
                    "candidate_record_id",
                    "sample_id",
                    "informative_site_count",
                    "left_site_count",
                    "right_site_count",
                    "sites_passing_depth",
                    "sites_passing_major_af",
                    "mixed_or_ambiguous_sites",
                    "read_validation_status",
                    "notes",
                ],
            )
            write_tsv(lineage_sets, [{"sample": "S_PASS", "lineage": "A1", "jaccard": "1.0"}], ["sample", "lineage", "jaccard"])
            write_tsv(database_sets, [{"sample": "S_PASS", "database_ids": "DB1,DB2"}], ["sample", "database_ids"])

            output_candidates = tmp / "candidate_samples.tsv"
            subprocess.run(
                [
                    sys.executable,
                    str(ROOT / "scripts/recombination/summarize_recombination.py"),
                    "--manifest-tsv",
                    str(manifest),
                    "--duplicate-map-tsv",
                    str(duplicate_map),
                    "--gard-json",
                    str(gard_json),
                    "--gard-breakpoints-tsv",
                    str(gard_breakpoints),
                    "--gard-summary-json",
                    str(gard_summary),
                    "--three-seq-candidates-tsv",
                    str(three_seq),
                    "--three-seq-summary-json",
                    str(three_seq_summary),
                    "--tree-confirmation-tsv",
                    str(tree_confirmation),
                    "--read-validation-tsv",
                    str(read_validation),
                    "--analysis-group",
                    "HPV16",
                    "--hpv-type",
                    "HPV16",
                    "--samples-vs-lineage-sets-tsv",
                    str(lineage_sets),
                    "--samples-vs-database-tsv",
                    str(database_sets),
                    "--output-events-tsv",
                    str(tmp / "events.tsv"),
                    "--output-events-csv",
                    str(tmp / "events.csv"),
                    "--output-events-json",
                    str(tmp / "events.json"),
                    "--output-summary-md",
                    str(tmp / "summary.md"),
                    "--output-warnings-tsv",
                    str(tmp / "warnings.tsv"),
                    "--output-type-overview-tsv",
                    str(tmp / "type_overview.tsv"),
                    "--output-candidate-samples-tsv",
                    str(output_candidates),
                    "--output-breakpoint-support-tsv",
                    str(tmp / "breakpoints.tsv"),
                    "--output-duplicate-map-tsv",
                    str(tmp / "duplicate_report.tsv"),
                ],
                check=True,
            )
            rows = {row["sample_id"]: row for row in read_tsv(output_candidates)}
            self.assertEqual(rows["S_PASS"]["final_status"], "candidate_recombinant")
            self.assertEqual(rows["S_INC"]["final_status"], "inconclusive")
            self.assertEqual(rows["S_NONE"]["final_status"], "alignment_signal_only")


if __name__ == "__main__":
    unittest.main()
