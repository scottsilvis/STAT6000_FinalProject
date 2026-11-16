# STAT 6000 — ABIDE I Classification Project

This course project compares methods for distinguishing autism spectrum disorder (ASD) from controls using resting-state functional connectivity. The dataset contains 386 participants from NYU, UM_1, and USM: 269 labeled training subjects and 117 hidden-test subjects, with 19,900 connectivity edges per subject.

## Run the project

Install the packages once.

```r
install.packages(c("R.matlab", "pROC", "tidymodels", "discrim", "kknn", "glmnet", "ggplot2", "here"))
```

The instructor-provided files are in [`data/`](data/):

- `data/ABIDEI_Final_Project.mat`
- `data/ABIDEI_three_sites_behavior.csv`

From the repository root, run the whole project with one command.

```r
source("run_analysis.R")
```

or

```bash
Rscript run_analysis.R
```

The script loads the data, runs the EDA, cross-validates three models, picks the model with the highest pooled held-out ROC AUC, and predicts the 117 test subjects. All outputs are written to `results/`. Results from the last run are already in `results/`, so teammates can read them without rerunning anything.

## What each file does

[`run_analysis.R`](run_analysis.R) sources these scripts in order.

| File | Role |
| --- | --- |
| `R/metrics.R` | `measure()` returns ROC AUC, accuracy, sensitivity, specificity, and confusion counts |
| `R/01_load_data.R` | Loads connectivity data and demographics, splits training and test subjects, and checks the data |
| `R/02_eda.R` | EDA tables and four figures |
| `R/03_validation.R` | Five diagnosis-stratified folds (seed 6000) and per-fold scoring of a workflow |
| `R/04_logistic-regression.R` | Regularized logistic regression workflow |
| `R/04_pca.R` | PCA + LDA and PCA + KNN workflows |
| `R/05_compare.R` | Scores every model on the same folds and ranks them by ROC AUC |
| `R/06_predict.R` | Refits the best model on all labeled subjects and predicts the test subjects |
| `R/utils_plot.R` | `save_fig()` and `save_table()` helpers |

## Methods and validation

All models use the same five diagnosis-stratified folds. Each model's recipe learns imputation, filtering, scaling, and PCA from the **training portion of each fold only**, never from validation or test subjects.

- **Logistic regression:** `glmnet` engine, fixed L1 penalty of 0.01, on all 19,900 standardized edges. Regularization makes this feasible with far more edges than subjects.
- **PCA + LDA:** `MASS` engine on 10 principal components.
- **PCA + KNN:** `kknn` engine on 10 principal components, 7 neighbors.

The settings are fixed and were not tuned. The best model is chosen automatically by pooled out-of-fold ROC AUC, using training subjects only. That AUC is not an independent performance estimate, because the same folds were used to choose the model. See [RESULTS.md](RESULTS.md) for the numbers.

## Outputs

| File | Contents |
| --- | --- |
| `site_counts.csv`, `class_balance.csv`, `sex_counts.csv`, `age_summary.csv`, `feature_summary.csv` | EDA tables |
| `site_counts.png`, `class_balance.png`, `age_distribution.png`, `sex_codes.png` | EDA figures |
| `fold_metrics.csv` | One row per held-out fold and model |
| `model_comparison.csv` | Pooled out-of-fold metrics and confusion counts |
| `session_info.txt` | R and package versions |
| `test_predictions.csv` | Test-subject predictions. Created locally and ignored by Git |

Sex is stored as codes 1 and 2. The supplied files do not say what the codes mean, so the EDA leaves them as codes.

Keep subject-level predictions local. Hidden labels must stay outside development and must never be reconstructed from external data.

## Round 1 submission

**Due November 24, 2026, at 11:59 PM.** The first leaderboard will be announced November 25, 2026. Teams are ranked by test ROC AUC, with accuracy as the tiebreaker.

1. Download the [official Excel template](https://auburn.instructure.com/courses/1739715/files/295332460?wrap=1).
2. Run `run_analysis.R` to produce `results/test_predictions.csv`, which covers all 117 test subjects.
3. Match the predictions to the template by subject ID, preserving leading zeros and the template's row order. Fill only the two yellow columns. Enter `0` (Control) or `1` (ASD) in `predicted_label` and an ASD probability between 0 and 1 in `predicted_probability`. Preserve all subject IDs, site values, headers, and workbook structure.
4. Verify that all 117 subjects have both values. Save as `TeamName_Round1.xlsx` and submit one completed Excel workbook per team through Canvas. The local CSV is an intermediate file.

The original assignment lists December 6 for final materials. Follow the course policy for acknowledging assistance.
