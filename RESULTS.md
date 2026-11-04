# Empirical Results — NYU-only Analysis

Execution date: 2026-11-04. Dataset: instructor-provided `ABIDEI_Final_Project.mat`. These are actual cross-validation computations, not hidden-test scores.

## Subjects
- 179 NYU subjects total; **125 labeled training** (73 controls, 52 ASD); **54 hidden test**.
- Each subject has 19,900 connectivity features. No missing or infinite values were detected.
- Training/test labels were kept separate. All learned preprocessing and tuning were performed exclusively on labeled training data.

## Nested cross-validation
Stratified five-fold outer CV; stratified three-fold inner hyperparameter search; ROC AUC used for tuning. Pooled out-of-fold (OOF) metrics at a fixed probability threshold of 0.5:

| Model | ROC AUC | Accuracy | Sensitivity (ASD) | Specificity (control) |
| --- | ---: | ---: | ---: | ---: |
| PCA + LDA | **0.6657** | **0.648** | 0.4615 | 0.7808 |
| L2 logistic regression + feature selection | 0.6188 | 0.608 | 0.4423 | 0.7260 |
| PCA + KNN | 0.6164 | 0.608 | 0.3846 | 0.7671 |

Fold-specific AUC means (SD): PCA+LDA **0.683 (0.146)**, logistic **0.648 (0.113)**, PCA+KNN **0.623 (0.133)**. These are per-fold AUC averages and thus differ from pooled OOF AUC.

## Model selected for held-out predictions
PCA + LDA had the highest pooled OOF ROC AUC. A new inner three-fold search using all 125 labeled NYU subjects selected **20 principal components** (mean inner CV AUC **0.6697**). The refitted model generated **54 hidden-test predictions**; at threshold 0.5, 16 were predicted ASD and 38 predicted control.

The subject-level prediction CSV is **not in this public repository**. It is delivered separately to the student. Its file has 54 original site-specific IDs, once each.

## Interpretation and safeguards
LDA demonstrated modest discrimination, with substantially lower sensitivity than specificity. In particular, it failed to flag over half of labeled ASD subjects in out-of-fold predictions. These results do not establish clinical diagnostic utility. Only NYU was analyzed; generalization to other sites remains unknown. The sample-to-feature ratio poses overfitting risk despite fold-wise preprocessing. Class-specific comparisons and sensitivity should be emphasized in the presentation.

**Instructor clarification needed:** The group assignment originally required predictions for all 117 hidden-test IDs across three sites; the online individual student has been allowed to select one site. Confirm that 54 NYU-specific predictions are the accepted submission format.

**Reproducibility note:** Executed in Python using scikit-learn 1.8.0 and SciPy 1.17.0. The initial draft script required a demographics CSV, which was not available in the execution container. To run the classification, the demographics loading block was omitted from the local execution copy; the classifier/model pipeline and CV design were unchanged. Demographic EDA remains to be completed. The original repository script still expects the demographics CSV supplied with the assignment.
