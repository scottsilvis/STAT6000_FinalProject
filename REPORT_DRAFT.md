# Autism Classification Using Resting-State Functional Connectivity: NYU Site

**STAT 6000 — Individual final project | Models executed November 4, 2026; demographic EDA and instructor clarification pending**

## Abstract
This project compares three statistical learning approaches for classifying autism spectrum disorder (ASD) versus typically developing controls from resting-state functional connectivity at the NYU site of ABIDE I. The original course data contain 386 subjects across three sites; NYU contributes 179. Each participant is described by 19,900 unique Fisher-z-transformed pairwise connectivity measures among 200 brain regions. Only labeled NYU subjects are used for feature selection, training and cross-validation. Classification performance is measured by ROC AUC, accuracy, sensitivity and specificity. On 125 labeled NYU subjects, nested cross-validation favored PCA + LDA (pooled out-of-fold ROC AUC 0.666, accuracy 64.8%). Performance was modest, especially ASD sensitivity (46.2%).

## Research question
How well can connectivity features predict ASD status within NYU, and how do regularized logistic regression, PCA plus linear discriminant analysis (LDA), and PCA plus k-nearest neighbors (KNN) compare under an identical evaluation design?

## Data and exploratory analysis
The instructor-supplied MAT file holds the 19,900-feature connectivity vector for each subject and a training indicator and training-only label. The demographics file provides age, coded sex and number of resting-state time points. Restrict all analysis to NYU; NYU has 179 participants before the train/test split. Report the labeled NYU class counts, split counts, age summaries, coded sex distributions, missing data and basic feature quality from `results/dataset_summary.json` and `results/site_demographics.csv`. Do not interpret sex codes as male/female without the corresponding codebook. No hidden-test label is available or should be sought.

NYU dataset: 179 total subjects; labeled training 125 (73 controls, 52 ASD); hidden test 54. Demographic visualizations remain pending because the companion demographics CSV was not accessible in this execution environment.

## Preprocessing
Raw features are Fisher-z-transformed correlations. The algorithm imputes missing feature values with the training-fold median and standardizes features within each training fold. Logistic regression uses univariate ANOVA F-score feature selection (50 or 200 selected edges) before L2-regularized classification; PCA+LDA and PCA+KNN instead reduce standardized features to 10 or 20 components. These preprocessing steps are inside scikit-learn pipelines, preventing fold-to-validation leakage. Do not fit transformations on all subjects in advance.

## Models and evaluation design
Compare (1) L2 logistic regression (C = 0.01, 0.1, 1), (2) LDA after PCA (10 or 20 components), and (3) KNN after PCA (10 or 20 components; k = 3 or 7). Conduct **nested stratified cross-validation** exclusively on the labeled NYU training data: five outer folds estimate performance and three inner folds tune hyperparameters by ROC AUC. Use the same outer splits for each method. Each labeled subject receives one held-out probability per model. AUC is calculated from the pooled out-of-fold probabilities; at threshold 0.5 report accuracy, sensitivity and specificity. Additionally inspect per-fold variability in `outer_fold_metrics.csv`. Model selection uses highest pooled out-of-fold AUC, with no hidden-test feedback. As sample sizes are small, the CV estimates may vary substantially with splits; no confidence intervals are claimed.

## Results
Computed November 4, 2026 using the supplied MAT file and nested five-fold outer / three-fold inner stratified CV. Reported values below are pooled out-of-fold estimates, not hidden-test metrics.

| Method | ROC AUC | Accuracy | Sensitivity | Specificity |
| --- | ---: | ---: | ---: | ---: |
| L2 logistic regression + feature selection | 0.6188 | 0.608 | 0.4423 | 0.7260 |
| PCA + LDA | **0.6657** | **0.648** | **0.4615** | **0.7808** |
| PCA + KNN | 0.6164 | 0.608 | 0.3846 | 0.7671 |

The chosen model, PCA + LDA, correctly classified 57/73 controls and 24/52 ASD subjects from their respective held-out folds. Fold-wise AUC mean (SD): PCA+LDA 0.683 (0.146); logistic regression 0.648 (0.113); PCA+KNN 0.623 (0.133). These per-fold averages differ from the pooled AUC reported in the table. Sensitivity lagged specificity substantially.

## Final selection and test predictions
PCA + LDA was selected using highest pooled out-of-fold ROC AUC. A subsequent three-fold training-only hyperparameter search on all 125 labeled NYU subjects selected 20 principal components (inner CV AUC 0.6697). The model predicted the 54 NYU hidden-test subjects, of whom 16 were classified ASD at the 0.5 probability threshold. No hidden labels were accessed. `results/NYU_test_predictions.csv` includes original IDs, predicted ASD probability, and a binary label at the prespecified 0.5 threshold. **Submission caveat:** original group instructions require all 117 three-site test records. Instructor's individual-project exception permits one site, but the replacement file specification and leaderboard eligibility should be confirmed before submitting only NYU records.

## Discussion and limitations
The dataset has many more connectivity measurements than labeled NYU subjects, so strong fitting and optimistic validation are major concerns. Restricting analysis to one site reduces intersite scanner/protocol variation but limits sample size and generalization to other sites. Age and coded sex distributions could influence observed performance; demographic variables were not added to the classifiers in this baseline. Feature selection and PCA may discard distributed signals, and cross-sectional correlation-based measures cannot establish causal mechanisms. Accuracy depends on class prevalence, so sensitivity, specificity and AUC should be examined together. These predictions are for a course exercise, not clinical diagnosis.

## Reproducibility and integrity
Run `python run_analysis.py --data-dir PATH_TO_INSTRUCTOR_FILES --site NYU --out results`. Keep hidden labels unavailable; do not join on external ABIDE diagnoses or tune on held-out subjects. State any permitted AI assistance under the course policy. Classification results are based on executed code. Demographic EDA, figures, and final submission format still require completion; see RESULTS.md. The execution copy skipped loading a missing demographics CSV without changing model evaluation or selection.

## Contribution statement
Individual project: all analysis choices, validation, interpretation and final presentation are the student's responsibility; any use of AI drafting or programming assistance should be disclosed as required.
