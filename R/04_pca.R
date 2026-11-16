# R/04_pca.R

# ==============================================================================
# Purpose:
#   Build the PCA + LDA and PCA + KNN workflows. This file only defines a
#   function; 03_validation.R scores each workflow it returns.
# ==============================================================================

# The MASS engine for discrim_linear() is registered when discrim is loaded.
library(discrim)

# 1. Build the workflows -------------------------------------------------------
# PCA reduces 19,900 brain connections to a manageable set of components.
# LDA and KNN share the PCA recipe, but each fits its own classifier.
# training needs a diagnosis column with levels "control" and "asd".
make_pca_workflows <- function(training, components = 10, neighbors = 7) {
  preprocessing <- recipes::recipe(diagnosis ~ ., data = training) |>
    recipes::step_impute_median(recipes::all_numeric_predictors()) |>
    recipes::step_zv(recipes::all_predictors()) |>
    recipes::step_normalize(recipes::all_numeric_predictors()) |>
    recipes::step_pca(recipes::all_numeric_predictors(), num_comp = components)

  lda_model <- parsnip::discrim_linear() |>
    parsnip::set_engine("MASS") |>
    parsnip::set_mode("classification")

  knn_model <- parsnip::nearest_neighbor(neighbors = neighbors) |>
    parsnip::set_engine("kknn") |>
    parsnip::set_mode("classification")

  # Returned as a named list so the names can be passed to validate_workflow().
  list(
    "PCA + LDA" = workflows::workflow() |>
      workflows::add_recipe(preprocessing) |>
      workflows::add_model(lda_model),
    "PCA + KNN" = workflows::workflow() |>
      workflows::add_recipe(preprocessing) |>
      workflows::add_model(knn_model)
  )
}
