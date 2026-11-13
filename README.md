# STAT 6000 — ABIDE I Classification Project

This is a work in progress. Feel free to make any changes that you think will get us a better grade. 

This course project compares methods for distinguishing autism spectrum disorder (ASD) from controls using resting-state functional connectivity. The provided dataset contains 386 participants from NYU, UM_1, and USM, including 269 labeled training subjects and 117 hidden-test subjects. There are 19,900 connectivity edges per subject.

## Run the R baseline

The packages `MASS` and `class` are used with the code in this repository. Use the code below to install the packages, if you don't already have them installed. 

```r
install.packages(c("R.matlab", "MASS", "class"))
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

For configurable sites, report files, or private prediction export, use [`run_analysis.R`](run_analysis.R). [`R/models.R`](R/models.R) contains the shared fold preprocessing and the full runner's model fits. [`R/metrics.R`](R/metrics.R) calculates the evaluation metrics.

## Methods and validation

The script follows the Chapter 4 classification lab sequence of inspecting the data, fitting models, and evaluating predictions. It uses the same five seeded, stratified folds for all models. Pooled folds are stratified by both site and diagnosis. The model settings are fixed for this baseline, so the five folds are used for assessment without a hyperparameter search.

1. **Logistic regression** uses `glm(..., family = binomial())` on the five edges with the largest absolute training-only correlations with diagnosis. A small edge count limits the number of coefficients relative to each site's sample size.
2. **PCA + LDA** uses `MASS::lda()` with the first ten principal components and takes the ASD posterior probability.
3. **PCA + KNN** uses `class::knn()` with the first ten principal components and seven neighbors, using the ASD vote share as the score.

Each fold learns which edges to keep, median imputation, centering and scaling, and feature selection or PCA from its training rows. The fitted transformations are applied to its held-out rows. Site and demographics are used for stratification or description and are excluded from the model inputs.

The comparison table pools one out-of-fold score per subject and model. Report ROC AUC and, at an ASD score cutoff of 0.5, accuracy, ASD sensitivity, control specificity, and counts for the confusion matrix. The highest pooled out-of-fold AUC selects the candidate for refitting. Its cross-validation result comes from the same comparison used for selection, so it is not an independent estimate for the selected model.

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

## Verified NYU comparison

| Model | R ROC AUC | Python ROC AUC | R accuracy | Python accuracy |
| --- | ---: | ---: | ---: | ---: |
| PCA + LDA | 0.647 | 0.666 | 0.608 | 0.648 |
| PCA + KNN | 0.642 | 0.616 | 0.600 | 0.608 |
| Logistic regression | 0.440 | 0.619 | 0.472 | 0.608 |

These scores use the same 125 labeled NYU subjects. See the [full R results](RESULTS.md), [aggregate metrics CSV](results/model_comparison.csv), and [EDA and validation checks](EDA_AND_VALIDATION.md).

## Historical Python reference

The [archived Python script](https://github.com/scottsilvis/STAT6000_FinalProject/blob/3e18876130647f14c1ae81aa13056cefa580d462/run_analysis.py), [Python dependencies](requirements.txt), and [historical NYU metrics](results/python_nyu_model_comparison.csv) are available for reference. Python used nested CV with different model settings, so differences between the baselines do not isolate the effect of switching languages.

The assignment lists November 19 for initial predictions and December 6 for the final materials. Verify submission details in Canvas and follow the course policy for acknowledging assistance.
