# Exploratory analysis and validation checks

The instructor data contain 386 participants and 19,900 functional connectivity edges per participant. The R workflow matches demographics to the MAT records by subject ID and summarizes age and coded sex by site and split.

| Site | Total | Labeled | Controls | ASD | Hidden test |
| --- | ---: | ---: | ---: | ---: | ---: |
| NYU | 179 | 125 | 73 | 52 | 54 |
| UM_1 | 107 | 74 | 38 | 36 | 33 |
| USM | 100 | 70 | 30 | 40 | 30 |
| All sites | 386 | 269 | 141 | 128 | 117 |

| Site | Split | Median age (years) | Age range (years) | Sex code 1 | Sex code 2 |
| --- | --- | ---: | --- | ---: | ---: |
| NYU | Labeled | 13.72 | 6.47–38.76 | 99 | 26 |
| NYU | Hidden test | 13.29 | 7.13–39.10 | 43 | 11 |
| UM_1 | Labeled | 12.80 | 8.20–19.20 | 64 | 10 |
| UM_1 | Hidden test | 13.80 | 8.90–18.20 | 19 | 14 |
| USM | Labeled | 19.97 | 8.77–39.39 | 70 | 0 |
| USM | Hidden test | 20.17 | 9.92–50.22 | 30 | 0 |

Age and coded sex were available for all participants. The supplied files give no key for interpreting the sex codes. Age and sex-code distributions differ by site. The pooled folds preserve the site and diagnosis proportions through stratification, while the models use connectivity alone. This design estimates performance on held-out participants from the represented sites. Generalization to a new site would require a different validation design.

## Checks on the R baseline

- All three methods used the same five folds within each cohort. Imputation, scaling, feature selection, and PCA were fitted on each training split. The analysis required one finite out-of-fold score per labeled subject and method before pooling metrics.
- NYU metrics reproduced on a second run. For all four cohorts, each method's pooled confusion counts summed to the cohort's labeled sample size.
- Local prediction files contained 54 NYU, 33 UM_1, 30 USM, and 117 pooled IDs. Each file matched the original MAT-file order, with unique IDs and valid scores and labels. These files stay local.

The script writes `dataset_summary.csv` and `sex_counts.csv` for each run. See [Results](RESULTS.md) for the model comparisons and limitations.
