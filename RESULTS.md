# Preliminary results — NYU site

This analysis was completed November 4, 2026, before the team formed. It is retained as a **single-site baseline**, not the final three-site assignment.

## Dataset

NYU has 179 participants: 125 labeled training records (73 controls, 52 ASD) and 54 unlabeled test records. Each has 19,900 connectivity features.

## Nested cross-validation

Five outer stratified folds with three inner stratified folds for hyperparameter tuning, using ROC AUC. Preprocessing was fitted within the training fold.

| Model | Pooled out-of-fold ROC AUC | Accuracy | ASD sensitivity | Control specificity |
| --- | ---: | ---: | ---: | ---: |
| PCA + LDA | 0.6657 | 0.648 | 0.4615 | 0.7808 |
| Logistic regression with feature selection | 0.6188 | 0.608 | 0.4423 | 0.7260 |
| PCA + KNN | 0.6164 | 0.608 | 0.3846 | 0.7671 |

Mean outer-fold AUC (SD): PCA+LDA 0.683 (0.146); logistic 0.648 (0.113); PCA+KNN 0.623 (0.133). These are fold averages, not the pooled out-of-fold AUCs reported above.

## Baseline model selection

PCA + LDA had the highest pooled out-of-fold AUC. A three-fold search on the full labeled NYU subset selected 20 principal components (mean inner CV AUC 0.6697). A separate 54-row NYU prediction file was generated but is not included in this repository.

**Important:** The course's group assignment requires a **117-row prediction file spanning all three sites**. These site-specific outputs are not suitable for direct submission.

## Interpretation

ROC AUC of approximately 0.67 indicates modest separation on the labeled NYU data. Sensitivity (46.2%) is notably lower than specificity (78.1%), so accuracy alone would conceal an important weakness. The high feature-to-sample ratio and limited sample size make generalization uncertain.

The original analysis used Python with scikit-learn and SciPy. The modeling pipeline in `run_analysis.py` can be rerun using both supplied data files; it has not yet been established as the team's final pipeline.
