# Calculate metrics with the existing measure() function from metrics.R.
compare_models <- function(workflows_to_compare, folds, output_dir) {
  evaluations <- lapply(names(workflows_to_compare), function(name) {
    message("Evaluating: ", name)
    validate_workflow(workflows_to_compare[[name]], folds, name)
  })

  fold_metrics <- do.call(rbind, lapply(evaluations, function(x) x$fold_metrics))
  predictions <- do.call(rbind, lapply(evaluations, function(x) x$predictions))
  comparison <- do.call(rbind, lapply(split(predictions, predictions$model), function(x) {
    data.frame(model = x$model[1], measure(x$actual, x$score))
  }))
  comparison <- comparison[order(comparison$roc_auc, decreasing = TRUE), ,
                           drop = FALSE]
  rownames(comparison) <- NULL

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  write.csv(fold_metrics, file.path(output_dir, "fold_metrics.csv"), row.names = FALSE)
  write.csv(comparison, file.path(output_dir, "model_comparison.csv"), row.names = FALSE)
  print(comparison, row.names = FALSE)
  comparison
}
