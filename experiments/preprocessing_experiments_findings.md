# Preprocessing and feature-selection experiments (Nov 24, 2026)

All results come from nested cross-validation on the 269 labeled training subjects. The test subjects were never used. There were two outer 5-fold splits: split A is the team's folds (seed 6000) and split B is a new stratified split (seed 2026). Every learned step (site means and SDs, confound coefficients, t-test edge ranking, PCA) was fitted on the outer training fold only. The downstream model was penalized logistic regression, with α ∈ {0, 0.1, 0.5, 1} and λ tuned by inner 5-fold CV AUC. The exceptions are the PCA + LDA variants, where the number of components was tuned instead. Script: `preprocessing_experiments.R`.

"Paired Δ" is the mean per-fold AUC difference against the baseline on the same 10 folds (± standard error). Rerunning the baseline with different inner folds moved its AUC by about 0.01–0.015, so smaller differences are noise.

| Variant | Pooled AUC (mean of A, B) | Accuracy | Paired Δ vs baseline | Folds better (of 10) |
|---|---|---|---|---|
| t-test screening, top 5,000 edges | 0.786 | 0.706 | +0.007 ± 0.007 | 6 |
| PCA + LDA, components tuned (chose k = 80, the grid maximum) | 0.779 | 0.688 | 0.000 ± 0.009 | 6 |
| Site centering, then top 2,000 edges | 0.772 | 0.695 | −0.004 ± 0.012 | 5 |
| **Baseline: all 19,900 edges, tuned glmnet** | **0.767** | **0.695** | — | — |
| Site centering, then PCA + LDA | 0.764 | 0.677 | −0.018 ± 0.013 | 4 |
| t-test screening, top 2,000 | 0.763 | 0.686 | −0.004 ± 0.009 | 4 |
| Site centering (per-site edge means) | 0.762 | 0.688 | −0.007 ± 0.010 | 3 |
| Site standardizing (per-site means and SDs) | 0.745 | 0.678 | −0.017 ± 0.011 | 2 |
| BH-FDR screening, q = 0.10 (kept 319–1,916 edges) | 0.744 | 0.682 | −0.026 ± 0.005 | 0 |
| Confound regression (age, sex, site) | 0.737 | 0.651 | −0.032 ± 0.014 | 1 |
| t-test screening, top 500 | 0.737 | 0.678 | −0.031 ± 0.006 | 0 |
| Node strength (200 ROI averages) | 0.607 | 0.584 | −0.178 ± 0.034 | 0 |

## Findings

1. **Removing information hurts.** Every aggressive reduction lost AUC consistently: the top 500 edges, FDR-selected edges, and 200 node averages. The signal appears to be spread thinly across thousands of edges. That fits the inner CV repeatedly choosing ridge or near-ridge penalties (α = 0 in 5 of 10 folds, 0.1 in 4, 0.5 in 1).
2. **Nothing clearly beats tuned ridge on all edges.** The best variants (top 5,000 edges, tuned PCA + LDA) are within noise of the baseline on paired comparisons. Top 5,000's small lead goes away when screening is done fully nested (see below), so it shouldn't be picked as the final model on the strength of its 0.786.
3. **No evidence that site adjustment helps.** Centering made no difference, and standardizing or regressing out age, sex and site both trended worse. With the corrected standard errors below, those drops are suggestive rather than conclusive. Removing age- or site-related variation may also remove some diagnostic signal. This is worth discussing in the report rather than just dropping.
4. **Tuning the number of PCA components matters a lot for PCA + LDA.** On the team folds it rose from 0.696 at the fixed k = 10 (run_analysis.R) to 0.766 when k was tuned (0.779 averaged over both splits). k = 80 was the largest value tried, so the grid should be extended to 120 and 160 (k must stay below the inner training size of about 172).
5. **Many edges pass univariate tests, but some may reflect site.** BH-FDR at q = 0.10 kept 319–1,916 edges per fold. Those tests pooled all three sites, and the ASD share (0.42 / 0.49 / 0.57) and mean connectivity both differ by site, so some hits may be site effects rather than diagnosis effects. Site alone predicts diagnosis poorly (AUC 0.568 in-sample, 0.533 out of fold), so site doesn't explain the model's performance overall. Testing within each site, or fitting edge ~ diagnosis + site, would separate the two. Even with these edges, a classifier built on only them did worse than one using all edges with shrinkage.

## Fully nested screening check (Nov 24)

As run, the screening variants ranked edges once per outer training fold, so the inner choice of λ saw features ranked partly from its own validation rows. The outer AUCs were still honest. Rerunning each screening variant with edges re-ranked inside every inner fold, using the same folds and seeds, gave:

| Variant | As run | Fully nested | Fully nested vs baseline (0.767) |
|---|---|---|---|
| Top 500 | 0.737 | 0.730 | −0.040 |
| Top 2,000 | 0.763 | 0.728 | −0.027 |
| Top 5,000 | 0.786 | 0.755 | −0.012 |
| BH-FDR q = 0.10 | 0.744 | 0.719 | −0.030 |

Both procedures give honest outer AUCs; the fully nested one also avoids an optimistic inner choice of λ. Fully nested, every screening variant's point estimate fell below the baseline. The drops are clear for top 2,000 and BH-FDR, while top 5,000 remains within noise. Top 5,000's earlier lead was within noise and didn't hold up, which supports findings 1 and 2.

## Caveats

- Picking the best of 12 variants on the same outer folds slightly overstates the winner's score. Report the full table, not only the top row.
- Pooled AUC can differ from the per-fold comparison, because pooling also rewards probabilities that are on a consistent scale across folds. The paired per-fold Δ is the fairer test.
- **The ± standard errors in the table are too small.** They treat the 10 folds as independent, but the two splits reuse the same 269 subjects. The Nadeau–Bengio correction makes them about 1.9× larger, for example top 500 −0.031 ± 0.012, BH-FDR −0.026 ± 0.009, site standardizing −0.017 ± 0.021, and confound regression −0.032 ± 0.027.
- The "baseline lasso, λ = 0.01" comparisons in the tuning scripts fit glmnet at that single λ, which glmnet's documentation discourages. Fitting the full path and predicting at s = 0.01 is closer to the team pipeline.
- All results use folds stratified on diagnosis only. The team plans to switch to site × diagnosis strata, after which every number here should be rerun.

## Suggested next steps (for Dec 6)

- Extend the PCA + LDA component grid, and repeat the outer CV with more splits (for example, 5 × repeated 5-fold) for the top 3–4 variants.
- Try averaging the tuned ridge and tuned PCA + LDA probabilities. Ensembles of different models often improve AUC.
- Keep the current tuned ridge as the default unless a variant wins clearly on repeated paired comparisons.
