# Results

Three models were scored with the same five diagnosis-stratified folds on the 269 labeled training subjects (all three sites pooled, seed 6000). Each metric below pools one held-out score per subject. Sensitivity is for ASD and specificity is for controls. Accuracy, sensitivity, and specificity use an ASD score cutoff of 0.5.

| Model | ROC AUC | Accuracy | Sensitivity | Specificity |
| --- | ---: | ---: | ---: | ---: |
| Logistic regression | 0.741 | 0.677 | 0.641 | 0.709 |
| PCA + LDA | 0.696 | 0.636 | 0.570 | 0.695 |
| PCA + KNN | 0.683 | 0.613 | 0.656 | 0.574 |

Logistic regression had the highest AUC and accuracy, so the script selected it for the test predictions. See [model_comparison.csv](results/model_comparison.csv) for full precision and confusion counts.

## Variation across folds

Each fold holds out about 54 subjects, so fold-level values are noisy. Per-fold ROC AUC ranged from 0.67 to 0.81 for logistic regression (mean 0.75), 0.63 to 0.76 for PCA + LDA (mean 0.70), and 0.62 to 0.74 for PCA + KNN (mean 0.68). Logistic regression had the highest AUC in three of the five folds. The ranges overlap, so with this sample size the differences between models are suggestive and not conclusive. See [fold_metrics.csv](results/fold_metrics.csv).

## Limitations

- **Settings were not tuned.** The glmnet penalty (0.01), the 10 PCA components, and the 7 neighbors are fixed choices.
- **Optimistic selection.** The same folds were used to rank the models and to report the winning score, so 0.741 is likely somewhat optimistic for new subjects.
- **Site effects.** The models use connectivity only, with no adjustment for site. Age and the sex codes differ across sites (see the EDA tables), and site could contribute to apparent signal. The folds preserve site and diagnosis proportions through stratification, so these results describe performance on new subjects from the same three sites, not on an unseen site.
- **No test performance.** The 117 test predictions have no measured accuracy here, because the test labels are hidden.
- **Class balance.** The training set has 141 controls and 128 ASD subjects, so accuracy is not distorted by a large imbalance.

## Next steps

This is a first attempt with fixed settings. Ideas for improving the scores are listed below, roughly in order of expected payoff versus effort. The rules from the assignment apply to all of them: tune and select models using training-only cross-validation, never the test subjects, and never leaderboard feedback.

1. **Tune the hyperparameters.** This is the most obvious gap, and the assignment asks us to explain tuning.
   - Logistic regression: the glmnet `penalty` (try a log-spaced grid such as 0.0001 to 1) and `mixture` (0 = ridge, 1 = lasso). Change these in `R/04_logistic-regression.R`.
   - PCA models: the number of components (for example 5, 10, 20, 40) and the KNN `neighbors`. Change these in `R/04_pca.R`.
   - Use `tune::tune()` and `tune_grid()` on the existing recipes and folds. Tuning on the same folds used for the final comparison makes the reported score optimistic, so nested cross-validation (tune inside each training fold) gives a more honest estimate.
2. **Use repeated cross-validation.** Five folds of about 54 subjects give noisy scores, and the models' per-fold AUC ranges overlap. Repeating the folds (for example `rsample::vfold_cv(repeats = 5)`) gives a steadier ranking. This touches `R/03_validation.R`.
3. **Try more model types.** The assignment lists SVM and random forest as options. Each is a new workflow function in the style of `R/04_*.R`, and `compare_models()` accepts any named list of workflows.
4. **Address site effects.** The models use connectivity alone, while age and the sex codes differ by site. Options:
   - Compare cross-validated performance within each site to see whether one site drives the result.
   - Add site, age, and sex as predictors. The demographics file has them for every subject, including the test subjects. This would need a change in `R/01_load_data.R` and `run_analysis.R` to join them into `training_data` and `test_data`.
   - Try a harmonization method such as ComBat, fitted inside each training fold.
5. **Reduce the features before the model.** Examples are keeping the edges most related to diagnosis within each training fold (the selection must happen inside the fold), or grouping edges by brain region.
6. **Check the decision threshold.** Accuracy, sensitivity, and specificity use a 0.5 cutoff. Sensitivity and specificity differ across models, and the leaderboard ranks on ROC AUC, so this matters mainly for the report. It does not change AUC.
7. **Look at calibration.** `predicted_probability` is submitted along with the label. Check how well the predicted probabilities match observed rates, particularly for the glmnet model.

Whatever we change, rerun `run_analysis.R` and compare against the table above. Keep the seed fixed so differences come from the change, not from the folds.

Earlier results from a previous version of this pipeline (per-site runs, different preprocessing, PCA + LDA ahead of logistic regression) were removed. They do not describe the current models.
