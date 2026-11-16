# R/04_logistic-regression.R

# ==============================================================================
# Purpose:
#   Build the regularized logistic regression workflow. This file only defines
#   a function; 03_validation.R scores the workflow it returns.
# ==============================================================================

# 1. Build the workflow --------------------------------------------------------
# Regularization is important because there are far more edges than subjects,
# so no individual edges are selected by hand.
# training needs a diagnosis column with levels "control" and "asd".
make_logistic_workflow <- function(training) {
  preprocessing <- recipes::recipe(diagnosis ~ ., data = training) |>
    recipes::step_impute_median(recipes::all_numeric_predictors()) |>
    recipes::step_zv(recipes::all_predictors()) |>
    recipes::step_normalize(recipes::all_numeric_predictors())

  # mixture = 1 is a lasso penalty. The penalty is fixed, not tuned.
  classifier <- parsnip::logistic_reg(penalty = 0.01, mixture = 1) |>
    parsnip::set_engine("glmnet") |>
    parsnip::set_mode("classification")

  workflows::workflow() |>
    workflows::add_recipe(preprocessing) |>
    workflows::add_model(classifier)
}
