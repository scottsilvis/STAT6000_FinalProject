# STAT 6000 — ABIDE I Classification Project

This is a work in progress. Feel free to make any changes that you think will get us a better grade. 

This course project compares methods for distinguishing autism spectrum disorder (ASD) from controls using resting-state functional connectivity. The provided dataset contains 386 participants from NYU, UM_1, and USM, including 269 labeled training subjects and 117 hidden-test subjects. There are 19,900 connectivity edges per subject.

## Run the R baseline

The R baseline uses tidymodels recipes and workflows for fold-specific preprocessing and modeling. Install the packages below if necessary. 

```r
install.packages(c("R.matlab", "pROC", "tidymodels", "discrim", "kknn", "glmnet", "ggplot2", "here"))
```

The instructor-provided files are included in [`data/`](data/):

- `data/ABIDEI_Final_Project.mat`
- `data/ABIDEI_three_sites_behavior.csv`

Run these commands from the repository root.

```bash
Rscript run_analysis.R data
Rscript run_analysis.R data UM_1
Rscript run_analysis.R data ALL
```

The default is NYU. Use `UM_1` or `USM` for the other individual sites, or `ALL` for an exploratory pooled baseline. The pooled model uses connectivity only and does not adjust for site effects. Default output is `results-r/<site>/`. A third positional argument overrides the output directory.

## Reading the code

Start with [`nyu_lab.R`](nyu_lab.R) for the class-style walkthrough. With the `.mat` file in `data/`, run the script from the repository root. Edit the path at the top only if you keep the file elsewhere. It prints the NYU class counts and cross-validation metrics, with all three model fits in one loop.

```bash
Rscript nyu_lab.R
```

The main runner uses these scripts in order:

1. `R/01_load_data.R` — load connectivity data and labels.
2. `R/02_eda.R` — required EDA tables and four ggplot2 figures, using all three sites. Run it after loading data with `describe_data(study, "data", "results-r/ALL")`.
3. `R/03_validation.R` — five shared, diagnosis-stratified cross-validation folds.
4. `R/04_logistic-regression.R` — penalized logistic regression on standardized connectivity edges.
5. `R/04_pca.R` — PCA feeding LDA and KNN.
6. `R/05_compare.R` — summarize the held-out predictions using the unchanged `R/metrics.R`.
7. `R/06_predict.R` — optional final refit and hidden-test prediction export.

`run_analysis.R` sources these scripts automatically. `R/project_files.R` retains command-line options and dataset-reading utilities.

## Methods and validation

All three models use the same five diagnosis-stratified folds. Each classifier's recipe estimates imputation, filtering and scaling from **training subjects within each fold**, not from validation or hidden-test subjects.

- **Logistic regression:** `parsnip::logistic_reg()` with the `glmnet` engine, fixed L1 penalty 0.01. Regularization makes logistic regression feasible with 19,900 edges.
- **PCA + LDA:** `discrim::discrim_linear()` with `MASS`, using ten PCA components.
- **PCA + KNN:** `parsnip::nearest_neighbor()` with `kknn`, using ten PCA components and seven neighbors.

The settings are intentionally fixed for this baseline, not tuned against validation scores. `R/metrics.R` is left untouched: its `measure()` function reports ROC AUC, accuracy, sensitivity, specificity, and confusion counts. The model with the highest pooled held-out AUC is refitted on all labeled records for optional hidden predictions; the winning CV AUC is not an independently confirmed performance estimate.

**Execution status:** The modular scripts have not been run or validated in an R runtime. Existing numerical results below are historical and must not be presented as results from this refactor.

## Outputs

| File | Contents |
| --- | --- |
| `dataset_summary.csv` | Counts and age summaries by site and split, labeled class balance, and feature count |
| `sex_counts.csv` | Sex-code frequencies by site and split (1/2 codes, unverified labels) |
| `class_balance.csv`, `age_summary.csv`, `feature_summary.csv` | Labeled diagnosis counts, age descriptions, and dimensionality/completeness |
| `site_counts.png`, `class_balance.png`, `age_distribution.png`, `sex_codes.png` | ggplot2 EDA figures for the report |
| `fold_metrics.csv` | One row per held-out fold and method |
| `model_comparison.csv` | Pooled out-of-fold metrics and confusion counts |
| `run_settings.csv`, `session_info.txt` | Model settings, selected method, and R environment |

Use `--predict` to refit the selected pipeline on all labeled rows in the requested cohort and produce private predictions. Hidden rows stay in the original MAT-file order and the CSV preserves leading zeros in subject IDs.

```bash
Rscript run_analysis.R data ALL --predict
```

Only the `ALL` run covers all 117 hidden-test IDs required by the assignment. Review the pooled strategy and site effects with the team before choosing a submission. Keep subject-level predictions local. The default output directory and prediction CSV pattern are ignored by Git. Hidden labels must stay outside development and must never be reconstructed from external data.

## Round 1 submission

**Due November 24, 2026, at 11:59 PM.** The first leaderboard will be announced November 25, 2026. Teams are ranked by test ROC AUC, with accuracy as the tiebreaker.

1. Download the [official Excel template](https://auburn.instructure.com/courses/1739715/files/295332460?wrap=1).
2. Refit the team's selected model using labeled training data only. The pooled baseline command above produces a local CSV with predictions for all 117 test subjects.
3. Match the predictions to the template by subject ID, preserving leading zeros and the template's row order. Fill only the two yellow columns. Enter `0` (Control) or `1` (ASD) in `predicted_label` and an ASD probability between 0 and 1 in `predicted_probability`. Preserve all subject IDs, site values, headers, and workbook structure.
4. Verify that all 117 subjects have both values. Save as `TeamName_Round1.xlsx` and submit one completed Excel workbook per team through Canvas. The local CSV is an intermediate file.

## Historical NYU comparison (before tidymodels refactor)

| Model | R ROC AUC | Python ROC AUC | R accuracy | Python accuracy |
| --- | ---: | ---: | ---: | ---: |
| PCA + LDA | 0.647 | 0.666 | 0.608 | 0.648 |
| PCA + KNN | 0.642 | 0.616 | 0.600 | 0.608 |
| Logistic regression | 0.440 | 0.619 | 0.472 | 0.608 |

These scores predate the tidymodels implementation and must be regenerated before reporting results from the new R models. The logistic regression feature strategy and KNN probability engine changed. These historical scores use the same 125 labeled NYU subjects. See the [full R results](RESULTS.md), [aggregate metrics CSV](results/model_comparison.csv), and [EDA and validation checks](EDA_AND_VALIDATION.md).

## Historical Python reference

The [archived Python script](https://github.com/scottsilvis/STAT6000_FinalProject/blob/3e18876130647f14c1ae81aa13056cefa580d462/run_analysis.py), [Python dependencies](requirements.txt), and [historical NYU metrics](results/python_nyu_model_comparison.csv) are available for reference. Python used nested CV with different model settings, so differences between the baselines do not isolate the effect of switching languages.

The original assignment lists December 6 for final materials. Follow the course policy for acknowledging assistance.
