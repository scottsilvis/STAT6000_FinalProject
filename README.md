# STAT 6000 — ABIDE I Classification Project

This is a work in progress. Feel free to make any changes that you think will get us a better grade. 

This course project compares methods for distinguishing autism spectrum disorder (ASD) from controls using resting-state functional connectivity. The provided dataset contains 386 participants from NYU, UM_1, and USM, including 269 labeled training subjects and 117 hidden-test subjects. There are 19,900 connectivity edges per subject.

## Run the R baseline

The R baseline uses tidymodels recipes and workflows for fold-specific preprocessing and modeling. Install the packages below if necessary. 

```r
install.packages(c("R.matlab", "pROC", "tidymodels", "discrim", "kknn"))
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

For configurable sites, report files, or private prediction export, use [`run_analysis.R`](run_analysis.R). [`R/models.R`](R/models.R) contains the tidymodels recipe and workflows used by both scripts. [`R/metrics.R`](R/metrics.R) calculates the evaluation metrics.

## Methods and validation

The script follows the Chapter 4 classification lab sequence of inspecting the data, fitting models, and evaluating predictions. It uses the same five seeded, stratified folds for all models. Pooled folds are stratified by both site and diagnosis. The number of principal components and neighbors are fixed for this baseline, so the five folds are used for assessment without a hyperparameter search.

1. **Logistic regression** uses `parsnip::logistic_reg()` with the `glm` engine on ten principal components. This replaces the previous five-edge selection approach.
2. **PCA + LDA** uses `discrim::discrim_linear()` with the `MASS` engine on the first ten principal components and takes the ASD posterior probability.
3. **PCA + KNN** uses `parsnip::nearest_neighbor()` with the `kknn` engine on the first ten principal components and seven neighbors, using its ASD class probability as the score.

Each fold learns which usable edges to keep, median imputation, centering and scaling, and PCA from its training rows. The fitted transformations are applied to its held-out rows. Site and demographics are used for stratification or description and are excluded from the model inputs.

The comparison table pools one out-of-fold score per subject and model. Report ROC AUC and, at an ASD score cutoff of 0.5, accuracy, ASD sensitivity, control specificity, and counts for the confusion matrix. The highest pooled out-of-fold AUC selects the candidate for refitting. Its cross-validation result comes from the same comparison used for selection, so it is not an independent estimate for the selected model.

**Validation status:** The tidymodels refactor has not yet been executed in an R environment or compared against the prior scores. Do not treat the historical metrics as current results. `R/metrics.R` is intentionally unchanged and continues to calculate confusion-matrix statistics and AUC using pROC.

## Outputs

| File | Contents |
| --- | --- |
| `dataset_summary.csv` | Counts and age summaries by site and split, labeled class balance, and feature count |
| `sex_counts.csv` | Sex-code frequencies by site and split |
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
