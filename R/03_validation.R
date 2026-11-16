# R/03_validation.R

# ==============================================================================
# Purpose:
#   Cross-validation for every model. All models are scored on the same five
#   held-out folds. Requires measure() from metrics.R.
# ==============================================================================

# 1. Create the folds ----------------------------------------------------------
# Each fold keeps roughly the same share of ASD and control subjects.
# training needs a diagnosis column with levels "control" and "asd".
make_validation_folds <- function(training, seed = 6000, number_of_folds = 5) {
  set.seed(seed)
  rsample::vfold_cv(training, v = number_of_folds, strata = diagnosis)
}

# 2. Evaluate a model on the folds ---------------------------------------------
validate_workflow <- function(workflow, folds, model_name) {
  predictions <- list()
  fold_metrics <- list()

  for (i in seq_len(nrow(folds))) {
    fold_train <- rsample::analysis(folds$splits[[i]])
    fold_test <- rsample::assessment(folds$splits[[i]])

    # Fitting the workflow also learns imputation, scaling and PCA, using
    # fold_train only.
    fitted <- workflows::fit(workflow, data = fold_train)
    score <- predict(fitted, new_data = fold_test, type = "prob")$.pred_asd

    # measure() expects 0 = control and 1 = ASD.
    actual <- as.integer(fold_test$diagnosis == "asd")

    predictions[[i]] <- data.frame(
      model = model_name,
      fold = i,
      actual = actual,
      score = score
    )

    fold_metrics[[i]] <- data.frame(
      model = model_name,
      fold = i,
      measure(actual, score)
    )
  }

  list(
    predictions = do.call(rbind, predictions),
    fold_metrics = do.call(rbind, fold_metrics)
  )
}
