# Every model uses the same five held-out groups.
# A recipe is fitted afresh on the training portion of each split.
make_validation_folds <- function(training, seed = 6000, number_of_folds = 5) {
  set.seed(seed)
  rsample::vfold_cv(training, v = number_of_folds, strata = diagnosis)
}

# Evaluate one workflow against the same cross-validation folds.
validate_workflow <- function(workflow, folds, model_name) {
  all_predictions <- list()
  fold_results <- list()

  for (i in seq_len(nrow(folds))) {
    split <- folds$splits[[i]]
    training_rows <- rsample::analysis(split)
    validation_rows <- rsample::assessment(split)

    # Fitting the workflow also learns imputation, scaling and PCA.
    fitted <- workflows::fit(workflow, data = training_rows)
    scores <- predict(fitted, new_data = validation_rows, type = "prob")$.pred_asd

    actual <- as.integer(validation_rows$diagnosis == "asd")
    fold_results[[i]] <- data.frame(
      model = model_name, fold = i, measure(actual, scores)
    )
    all_predictions[[i]] <- data.frame(
      model = model_name, fold = i, actual = actual, score = scores
    )
  }

  list(predictions = do.call(rbind, all_predictions),
       fold_metrics = do.call(rbind, fold_results))
}
