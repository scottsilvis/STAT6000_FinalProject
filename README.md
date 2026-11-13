# STAT 6000 — ABIDE I Classification Project

Course project exploring whether resting-state functional connectivity can distinguish autism spectrum disorder (ASD) from typically developing controls.

## Project scope

The course assignment includes **386 participants from three ABIDE I sites** (NYU, UM_1, and USM), with 269 labeled training subjects and 117 unlabeled test subjects. Each participant has 19,900 pairwise connectivity features from 200 brain regions.

**Current work is a preliminary NYU-only analysis**, prepared before the project group formed. It is a starting point for the team, not the final group submission. The team still needs to agree on a pooled-data strategy, handle site effects, compare models, and generate predictions for **all 117** test subjects as the assignment requires.

## Repository contents

| File | Purpose |
| --- | --- |
| `run_analysis.py` | Baseline single-site model comparison (logistic regression, PCA+LDA, PCA+KNN) |
| `REPORT_DRAFT.md` | Working methods and results for the NYU baseline |
| `RESULTS.md` | NYU baseline metrics and model selection |
| `EDA_AND_VALIDATION.md` | Demographic summaries and evaluation audit |
| `PRESENTATION_OUTLINE.md` | Suggested structure for the group presentation |
| `results/model_comparison.csv` | Aggregated NYU cross-validation metrics |

## Getting started

Use Python 3.10+ and install dependencies:

```bash
python -m pip install -r requirements.txt
```

Download the two instructor-provided files and keep them locally in the same directory:
- `ABIDEI_Final_Project.mat`
- `ABIDEI_three_sites_behavior.csv`

Run the NYU baseline:

```bash
python run_analysis.py --data-dir "/path/to/course/data" --site NYU --out results
```

The script supports NYU, UM_1 and USM **separately**. It does not currently train a pooled three-site model or produce the required combined submission. Output includes per-fold metrics, out-of-fold probabilities, model summaries and site-specific predictions.

## Current NYU baseline

| Model | Out-of-fold ROC AUC | Accuracy | ASD sensitivity | Control specificity |
| --- | ---: | ---: | ---: | ---: |
| PCA + LDA | 0.666 | 0.648 | 0.462 | 0.781 |
| Logistic regression | 0.619 | 0.608 | 0.442 | 0.726 |
| PCA + KNN | 0.616 | 0.608 | 0.385 | 0.767 |

These are cross-validation estimates on **125 labeled NYU subjects**, not hidden-test performance or final group results.

## Next steps for the team

1. Agree on dataset handling, responsibilities, evaluation plan and shared coding conventions.
2. Extend EDA to all three sites, including training labels, age, coded sex and site distributions.
3. Develop a pooled-data pipeline with preprocessing entirely inside the cross-validation folds; consider site effects explicitly.
4. Compare at least three methods under the same train-only evaluation design.
5. Refit the chosen model on labeled training records; create one prediction file covering all 117 test IDs.
6. Prepare the report, presentation and reproducibility instructions.

The original assignment sets **November 19** for initial predictions and **December 6** for the final materials. Verify deadlines and submission arrangements in Canvas.

## Data and research integrity

Instructor-supplied data and subject-level predictions are not distributed here. Keep hidden-test labels out of development; do not use external ABIDE records to reconstruct diagnoses. Model choice and preprocessing must use labeled training data only.

Team members should review and understand all code, results and writing before using them in submissions, and follow the course policy for acknowledging any AI or other assistance. Commit history has been preserved.
