# STAT 6000 single-site final project

**Status: runnable first draft, not yet executed against the instructor-provided functional connectivity data.**

Individual project: classify ASD versus control using resting-state functional connectivity from the NYU site of ABIDE I (179 subjects overall; labeled training and hidden-test split to be measured). Compare three course methods with training-only, nested cross-validation.

The dataset is intentionally **not redistributed** in this repository.

## Setup

Python 3.10+ recommended. Place the instructor's `ABIDEI_Final_Project.mat` and `ABIDEI_three_sites_behavior.csv` in a local directory.

```bash
python -m pip install -r requirements.txt
python run_analysis.py --data-dir '/path/to/STAT 6000 Final Project' --site NYU --out results
```

Outputs include demographic summaries, per-fold metrics, out-of-fold predictions, model comparison, selection metadata, and NYU-only hidden-test predictions. Results are omitted until actual computation.

## Outstanding work

1. Run against instructor data, verify site IDs, labels, split counts, and results.
2. Add genuine plots and results to the paper and presentation.
3. Confirm the instructor accepts NYU-only hidden-test submissions rather than all 117 three-site IDs.
4. Confirm whether group leaderboard and presentation arrangements apply to individual online students.
5. Disclose permitted AI assistance according to course policy.

See `REPORT_DRAFT.md` and `PRESENTATION_OUTLINE.md`. Do not use external ABIDE diagnoses or hidden-test feedback to tune models.
