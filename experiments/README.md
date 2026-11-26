# experiments/ (not yet reviewed by the team)

Nested-CV experiments run on Nov 24, 2026, training subjects only. Run every script from the repo root, for example:

    Rscript --max-ppsize=500000 experiments/preprocessing_experiments.R

They source R/metrics.R, R/01_load_data.R and R/03_validation.R through here::here(), so the repo layout must be intact.

- tune_glmnet_nested.R: nested CV of tuned glmnet (alpha, lambda) against the fixed lasso (lambda = 0.01), on the team's seed-6000 folds.
- tune_check_and_fit.R: repeats that comparison on two more outer splits, then fits the tuned model on all 269 training subjects. Writes results/test_predictions_tuned.csv and reads results/test_predictions.csv. This script produced Group 1's Round 1 submission (tuned ridge, alpha = 0, lambda ≈ 15.41, test AUC 0.786).
- preprocessing_experiments.R: compares 12 preprocessing and feature-selection variants. Writes results/preprocessing/*.csv. On Windows it runs serially (mclapply can't fork there), so it is slow, roughly 30+ minutes. It will be restyled to the repo conventions when it moves into the pipeline.
- preprocessing_experiments_findings.md and summary.csv: results and write-up. The code that generates summary.csv isn't included yet.

Known design note: in the t-test screening variants, edges are ranked once per outer training fold, so the inner cv.glmnet choice of lambda sees features ranked using its own validation rows. The outer AUC stays honest, because the held-out fold is never used, but the inner lambda choice can be slightly optimistic. k is not tuned; each k is a separate variant.

All results use the current diagnosis-only folds and will change if the team switches to site x diagnosis strata.
