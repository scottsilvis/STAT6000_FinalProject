# Fit each classifier with a tidymodels recipe and workflow.
# All learned preprocessing is estimated using training subjects only.

fit_and_score <- function(train_x, train_y, new_x, methods,
                          n_edges, n_components, neighbors) {

  # Give the connectivity columns consistent names for the recipe.
  edge_names <- paste0("edge_", seq_len(ncol(train_x)))
  colnames(train_x) <- edge_names
  colnames(new_x) <- edge_names

  # tidymodels expects a categorical outcome for classification.
  training <- as.data.frame(train_x)
  training$diagnosis <- factor(
    ifelse(train_y == 1, "asd", "control"),
    levels = c("control", "asd")
  )
  new_subjects <- as.data.frame(new_x)

  # Turn infinite measurements into missing values for imputation.
  training[edge_names] <- lapply(training[edge_names], function(x) {
    x[!is.finite(x)] <- NA_real_
    x
  })
  new_subjects[edge_names] <- lapply(new_subjects[edge_names], function(x) {
    x[!is.finite(x)] <- NA_real_
    x
  })

  # Remove edges that are entirely missing in the training data.
  available <- vapply(training[edge_names], function(x) any(!is.na(x)), logical(1))
  if (!any(available)) stop("No usable training edges.")
  training <- training[, c(edge_names[available], "diagnosis"), drop = FALSE]
  new_subjects <- new_subjects[, edge_names[available], drop = FALSE]

  # Recipes learn medians, standardization, and PCA from training data.
  # step_zv removes constant columns before scaling.
  preprocessing <- recipes::recipe(diagnosis ~ ., data = training) |>
    recipes::step_impute_median(recipes::all_numeric_predictors()) |>
    recipes::step_zv(recipes::all_predictors()) |>
    recipes::step_normalize(recipes::all_numeric_predictors()) |>
    recipes::step_pca(recipes::all_numeric_predictors(), num_comp = n_components)

  # PCA keeps the number of predictors manageable for all three models.
  # n_edges is retained in the function signature for existing callers.
  model_specs <- list(
    "Logistic regression" = parsnip::logistic_reg() |>
      parsnip::set_engine("glm") |>
      parsnip::set_mode("classification"),
    "PCA + LDA" = discrim::discrim_linear() |>
      parsnip::set_engine("MASS") |>
      parsnip::set_mode("classification"),
    "PCA + KNN" = parsnip::nearest_neighbor(neighbors = neighbors) |>
      parsnip::set_engine("kknn") |>
      parsnip::set_mode("classification")
  )

  scores <- matrix(NA_real_, nrow(new_subjects), length(methods),
                   dimnames = list(NULL, methods))

  for (method in methods) {
    workflow <- workflows::workflow() |>
      workflows::add_recipe(preprocessing) |>
      workflows::add_model(model_specs[[method]])

    fitted <- workflows::fit(workflow, data = training)
    probabilities <- predict(fitted, new_data = new_subjects, type = "prob")
    scores[, method] <- probabilities$.pred_asd
  }

  stopifnot(all(is.finite(scores)), all(scores >= 0 & scores <= 1))
  scores
}
