# Exploratory analysis and validation checks

The instructor data contain 386 participants and 19,900 functional connectivity edges per participant (200 brain regions). `R/01_load_data.R` matches the demographics to the MAT-file subjects by subject ID, and `R/02_eda.R` summarizes site, class balance, age, and coded sex. The tables and figures are saved in [results/](results/).

| Site | Total | Training | Controls | ASD | Test |
| --- | ---: | ---: | ---: | ---: | ---: |
| NYU | 179 | 125 | 73 | 52 | 54 |
| UM_1 | 107 | 74 | 38 | 36 | 33 |
| USM | 100 | 70 | 30 | 40 | 30 |
| All sites | 386 | 269 | 141 | 128 | 117 |

Source: [site_counts.csv](results/site_counts.csv) and [class_balance.csv](results/class_balance.csv). Diagnoses are known for training subjects only.

| Site | Split | Mean age (years) | Median age (years) | Age range (years) | Sex code 1 | Sex code 2 |
| --- | --- | ---: | ---: | --- | ---: | ---: |
| NYU | Training | 15.25 | 13.72 | 6.47–38.76 | 99 | 26 |
| NYU | Test | 15.71 | 13.29 | 7.13–39.10 | 43 | 11 |
| UM_1 | Training | 13.51 | 12.80 | 8.20–19.20 | 64 | 10 |
| UM_1 | Test | 13.26 | 13.80 | 8.90–18.20 | 19 | 14 |
| USM | Training | 22.13 | 19.97 | 8.77–39.39 | 70 | 0 |
| USM | Test | 22.16 | 20.17 | 9.92–50.22 | 30 | 0 |

Source: [age_summary.csv](results/age_summary.csv) and [sex_counts.csv](results/sex_counts.csv).

Age and sex were available for all participants, and none of the connectivity values are missing or infinite ([feature_summary.csv](results/feature_summary.csv) reports 0 missing). The supplied files give no key for the sex codes, so they are shown as codes 1 and 2. Age and sex-code distributions differ by site. For example, USM subjects are older on average (about 22 years versus 13 to 15 at the other sites) and all have sex code 1. The models use connectivity alone, so these differences are a possible source of site effects.

Figures: [site_counts.png](results/site_counts.png), [class_balance.png](results/class_balance.png), [age_distribution.png](results/age_distribution.png), and [sex_codes.png](results/sex_codes.png).

## Validation design

- **Folds:** five folds stratified on diagnosis, made once from the training subjects (seed 6000). Every model is scored on the same folds.
- **Within each fold:** imputation, zero-variance filtering, scaling, and PCA are learned from the fold's training portion only, then applied to the held-out portion.
- **Pooling:** each labeled subject is scored once out of fold, and the pooled scores give the metrics in [RESULTS.md](RESULTS.md). Per-fold values are in [fold_metrics.csv](results/fold_metrics.csv).
- **Scope:** because the folds are random within the pooled data, they preserve site and diagnosis proportions. The estimates describe performance on new subjects from the same three sites. Generalization to a new site would need a different validation design.
- **Test subjects:** they are used only for the final prediction, after the model is chosen from cross-validation.

## Automatic checks

`R/01_load_data.R` stops the run if any of these fail: duplicate subject IDs, demographics that cannot be matched to the MAT subjects by ID, demographic and MAT sites that disagree, a feature matrix that is not 386 by 19,900, training and test counts that are not 269 and 117, or training labels other than 0 and 1. `R/06_predict.R` checks that the predictions contain 117 unique subject IDs with probabilities between 0 and 1.
