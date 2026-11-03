# 10–12 minute presentation outline (individual, online)

1. Title and question (0:45): classify ASD from NYU functional connectivity.
2. Data and subset (1:15): three-site dataset, NYU-only n=179, labeled/test split to be computed, 19,900 features.
3. EDA (1:15): class balance, age/sex distributions, missingness and high dimensionality.
4. Leakage-safe pipeline (1:30): fold-wise imputation, scaling, selection or PCA.
5. Three model families (1:30): logistic, PCA/LDA, PCA/KNN and hyperparameters.
6. Validation (1:15): 5 outer / 3 inner stratified folds, ROC AUC and confusion-matrix metrics.
7. Results (1:45): fill with computed comparison table and fold variability.
8. Final model and predictions (0:45): retrain on labeled NYU, predict NYU-only hidden test IDs.
9. Limitations and conclusions (1:00): sample size, site-specific generalization, confounding, nonclinical use.
10. Discussion/questions.

Do not show invented metrics. Replace all future-tense and placeholders after actual execution.
