# PCA reduces 19,900 brain connections to a manageable set of components.
# LDA and KNN share the PCA recipe, but each fits its own classifier.
make_pca_workflows <- function(training, components = 10, neighbors = 7) {
  preprocessing <- recipes::recipe(diagnosis ~ ., data = training) |>
    recipes::step_impute_median(recipes::all_numeric_predictors()) |>
    recipes::step_zv(recipes::all_predictors()) |>
    recipes::step_normalize(recipes::all_numeric_predictors()) |>
    recipes::step_pca(recipes::all_numeric_predictors(), num_comp = components)

  lda_model <- discrim::discrim_linear() |>
    parsnip::set_engine("MASS") |>
    parsnip::set_mode("classification")

  knn_model <- parsnip::nearest_neighbor(neighbors = neighbors) |>
    parsnip::set_engine("kknn") |>
    parsnip::set_mode("classification")

  list(
    "PCA + LDA" = workflows::workflow() |>
      workflows::add_recipe(preprocessing) |>
      workflows::add_model(lda_model),
    "PCA + KNN" = workflows::workflow() |>
      workflows::add_recipe(preprocessing) |>
      workflows::add_model(knn_model)
  )
}
