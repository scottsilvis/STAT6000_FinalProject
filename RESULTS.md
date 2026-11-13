# Baseline results

The R baseline uses five stratified folds and fixed model settings. Each metric below pools one held-out score per labeled subject and method. Sensitivity is for ASD, and specificity is for controls. Accuracy, sensitivity, and specificity use an ASD score cutoff of 0.5.

| Cohort | Model | ROC AUC | Accuracy | Sensitivity | Specificity |
| --- | --- | ---: | ---: | ---: | ---: |
| NYU | PCA + LDA | 0.647 | 0.608 | 0.615 | 0.603 |
| NYU | PCA + KNN | 0.642 | 0.600 | 0.442 | 0.712 |
| NYU | Logistic regression | 0.440 | 0.472 | 0.288 | 0.603 |
| UM_1 | PCA + KNN | 0.775 | 0.689 | 0.722 | 0.658 |
| UM_1 | PCA + LDA | 0.760 | 0.635 | 0.722 | 0.553 |
| UM_1 | Logistic regression | 0.584 | 0.527 | 0.639 | 0.421 |
| USM | PCA + LDA | 0.704 | 0.700 | 0.825 | 0.533 |
| USM | Logistic regression | 0.667 | 0.657 | 0.725 | 0.567 |
| USM | PCA + KNN | 0.658 | 0.657 | 0.725 | 0.567 |
| ALL | PCA + LDA | 0.714 | 0.625 | 0.750 | 0.511 |
| ALL | Logistic regression | 0.711 | 0.669 | 0.672 | 0.667 |
| ALL | PCA + KNN | 0.705 | 0.639 | 0.523 | 0.745 |


PCA + LDA had the highest AUC for NYU, USM, and the pooled cohort. PCA + KNN led at UM_1. In the pooled run, PCA + LDA had the highest AUC (0.714), while logistic regression had the highest accuracy (66.9%). Under the prespecified AUC rule, the script selected PCA + LDA for the pooled refit. The differences in pooled AUC are small, and these same folds were used for model selection.

The UM_1 logistic fit warned about fitted probabilities near zero or one. The pooled analysis uses connectivity alone and has no explicit adjustment for site effects. These results describe cross-validation on labeled subjects. The 117 private predictions have no measured hidden-test performance here.

See the [aggregate metrics CSV](results/model_comparison.csv) for full precision and confusion counts and the [EDA and validation notes](EDA_AND_VALIDATION.md) for cohort sizes and verification.

## Historical Python NYU baseline

The original Python baseline used five outer stratified folds and three inner folds for hyperparameter tuning. PCA + LDA led with AUC 0.666 and accuracy 64.8%. Its full-label tuning selected 20 components. The [historical Python CSV](results/python_nyu_model_comparison.csv) preserves all three model results. The R baseline uses different folds, settings, and model selection procedures, which limits the comparison.
