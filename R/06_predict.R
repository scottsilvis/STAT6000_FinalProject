# Only use this step after choosing the final model on labeled data.
predict_hidden <- function(chosen_workflow, project, output_dir, site = "ALL") {
  fitted <- workflows::fit(chosen_workflow, data = project$training)
  asd_probability <- predict(fitted, new_data = project$test, type = "prob")$.pred_asd

  predictions <- data.frame(
    subject_id = project$test_ids,
    predicted_label = as.integer(asd_probability >= 0.5),
    predicted_probability = asd_probability
  )
  stopifnot(!anyDuplicated(predictions$subject_id),
            all(is.finite(predictions$predicted_probability)),
            all(predictions$predicted_probability >= 0 &
                predictions$predicted_probability <= 1))
  if (site == "ALL") stopifnot(nrow(predictions) == 117L)

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  destination <- file.path(output_dir, paste0(site, "_test_predictions.csv"))
  write.csv(predictions, destination, row.names = FALSE)
  message("Private prediction file saved: ", destination)
  invisible(predictions)
}
