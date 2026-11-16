# R/06_predict.R

# ==============================================================================
# Purpose:
#   Fit the chosen model on all labeled training subjects and predict the
#   unlabeled test subjects. Only use this after the final model has been
#   chosen with 05_compare.R. The predictions are saved to results/ as a CSV.
# ==============================================================================

source(here::here("R", "utils_plot.R"))

# 1. Predict the test subjects -------------------------------------------------
# training needs a diagnosis column with levels "control" and "asd".
# test has the same predictor columns as training, and test_ids lists its
# subjects in the same row order.
predict_test_subjects <- function(chosen_workflow, training, test, test_ids) {
  fitted <- workflows::fit(chosen_workflow, data = training)
  asd_probability <- predict(fitted, new_data = test, type = "prob")$.pred_asd

  predictions <- data.frame(
    subject_id = test_ids,
    predicted_label = as.integer(asd_probability >= 0.5),
    predicted_probability = asd_probability
  )

  # 2. Check the predictions ----------------------------------------------------
  stopifnot(
    nrow(predictions) == 117,
    !anyDuplicated(predictions$subject_id),
    all(is.finite(predictions$predicted_probability)),
    all(predictions$predicted_probability >= 0),
    all(predictions$predicted_probability <= 1)
  )

  # 3. Save the table -----------------------------------------------------------
  save_table(predictions, "test_predictions.csv")

  predictions
}
