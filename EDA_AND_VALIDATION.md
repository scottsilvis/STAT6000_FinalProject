# Preliminary NYU EDA and validation checks

## Demographics

Descriptive figures for all 179 NYU records (including the 54 unlabeled test subjects), from the provided demographics CSV:

| Measure | Value |
| --- | ---: |
| Mean / median age | 15.39 / 13.63 years |
| Age range | 6.47–39.10 years |
| Under 10 | 36 |
| 10–14 | 73 |
| 15–19 | 27 |
| 20–29 | 37 |
| 30 or older | 6 |
| Sex code 1 / code 2 | 142 / 37 |
| Recorded timepoints | 175 each |

Sex is coded as 1 or 2, without a provided key identifying the categories. This does not prevent statistical comparisons, but it limits our interpretation. Demographic summaries for all 179 NYU subjects cannot show ASD-group differences because 54 subjects have "unknown" diagnoses. However, we can compare demographic differences between the 73 controls and 52 ASD cases in the labeled subset.

## Model evaluation checks

Saved out-of-fold scores were checked against the aggregate AUCs, with one out-of-fold prediction per subject per model (125 subjects per method). See `RESULTS.md` and `results/model_comparison.csv`.

A NYU-only test file was checked for 54 distinct IDs with valid probabilities and binary labels; it remains outside the public repository. No hidden diagnoses were accessed.

## Outstanding analyses

- Compare site composition and training-class balance across NYU, UM_1 and USM.
- Inspect missing values and age/sex distributions by site and *labeled* diagnostic class.
- Document cross-validation strategy for pooled modeling, including site effects.
- Reproduce full-data model comparisons and generate figures for the group report.
