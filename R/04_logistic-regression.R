# Regularized logistic regression: no manual selection of individual edges.
# Regularization is important because there are far more edges than subjects.
make_logistic_workflow <- function(training) {
  preprocessing <- recipes::recipe(diagnosis ~ ., data = training) |>
    recipes::step_impute_median(recipes::all_numeric_predictors()) |>
    recipes::step_zv(recipes::all_predictors()) |>
    recipes::step_normalize(recipes::all_numeric_predictors())

  classifier <- parsnip::logistic_reg(penalty = 0.01, mixture = 1) |>
    parsnip::set_engine("glmnet") |>
    parsnip::set_mode("classification")

  workflows::workflow() |>
    workflows::add_recipe(preprocessing) |>
    workflows::add_model(classifier)
}
