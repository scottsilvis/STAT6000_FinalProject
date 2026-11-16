# R/05_compare.R

# ==============================================================================
# Purpose:
#   Score every model on the same cross-validation folds and rank them by ROC
#   AUC. Requires validate_workflow() from 03_validation.R and measure() from
#   metrics.R. Tables are saved to results/ as CSVs.
# ==============================================================================

source(here::here("R", "utils_plot.R"))

# 1. Compare the models --------------------------------------------------------
# workflows_to_compare is a named list, e.g. list("PCA + LDA" = workflow, ...).
compare_models <- function(workflows_to_compare, folds) {
  all_predictions <- list()
  all_fold_metrics <- list()

  for (model_name in names(workflows_to_compare)) {
    message("Evaluating: ", model_name)
    result <- validate_workflow(workflows_to_compare[[model_name]], folds, model_name)

    all_predictions[[model_name]] <- result$predictions
    all_fold_metrics[[model_name]] <- result$fold_metrics
  }

  predictions <- do.call(rbind, all_predictions)
  fold_metrics <- do.call(rbind, all_fold_metrics)

  # 2. Pool the held-out predictions from all folds for one score per model ----
  comparison <- list()
  for (model_name in names(workflows_to_compare)) {
    model_predictions <- predictions[predictions$model == model_name, ]
    comparison[[model_name]] <- data.frame(
      model = model_name,
      measure(model_predictions$actual, model_predictions$score)
    )
  }
  comparison <- do.call(rbind, comparison)

  # Best ROC AUC first
  comparison <- comparison[order(comparison$roc_auc, decreasing = TRUE), ]
  rownames(comparison) <- NULL

  # 3. Save tables --------------------------------------------------------------
  save_table(fold_metrics, "fold_metrics.csv")
  save_table(comparison, "model_comparison.csv")

  comparison
}
