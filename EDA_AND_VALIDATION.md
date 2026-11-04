# NYU Demographic and Validation Audit

## Demographics (all NYU participants, not only labeled subjects)
These figures come from the supplied `ABIDEI_three_sites_behavior.csv`; the CSV carries no diagnosis labels.

| Item | Value |
| --- | ---: |
| Subjects | 179 |
| Mean age | 15.39 years |
| Median age | 13.63 years |
| Age range | 6.47–39.10 years |
| Age under 10 | 36 |
| Age 10–14 | 73 |
| Age 15–19 | 27 |
| Age 20–29 | 37 |
| Age 30+ | 6 |
| Sex code 1 | 142 |
| Sex code 2 | 37 |
| Timepoints | 175 for every participant |

The meaning of the sex code is **unverified**. These statistics include 54 unlabeled test participants; they are descriptive only and were **not** used to tune or select models. The class balance of the 125 labeled subjects was 73 control and 52 ASD.

## Cross-validation audit
Independently recalculated ROC AUC from the saved out-of-fold probabilities. All three models have 125 unique out-of-fold subjects with 73 controls and 52 ASD, and the recomputed AUC agrees with `results/model_comparison.csv`.

| Model | Pooled out-of-fold ROC AUC | Mean outer-fold AUC (SD) |
| --- | ---: | ---: |
| PCA + LDA | 0.6657 | 0.6831 (0.1460) |
| Logistic regression | 0.6188 | 0.6479 (0.1127) |
| PCA + KNN | 0.6164 | 0.6230 (0.1326) |

The 54-row NYU-only prediction CSV was verified to have unique, nonmissing IDs, probabilities and binary labels; 16 were classified ASD and 38 control. Its subject-level contents remain outside this public repository.

## Generated visuals
Four figures were generated in the student's downloadable analysis materials: class balance, NYU age distribution, ROC comparison, and PCA+LDA confusion matrix. They have not yet been added to this GitHub repository.

## Remaining limitations
Diagnosis-stratified demographic summaries need subject-ID joins; site-level demographics may include unlabeled test participants. No second independent holdout labeled set is available for validation. The instructor needs to confirm whether 54 NYU-only predictions satisfy the individual assignment's leaderboard rules.
