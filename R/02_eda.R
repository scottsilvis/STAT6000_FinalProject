# Descriptive summaries use demographics; they do not reveal hidden diagnoses.
describe_data <- function(project, data_dir, out_dir) {
  demographics <- summarize_demographics(
    file.path(data_dir, "ABIDEI_three_sites_behavior.csv"),
    project$study, project$selected
  )
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  write.csv(demographics$summary, file.path(out_dir, "dataset_summary.csv"),
            row.names = FALSE)
  write.csv(demographics$sex_counts, file.path(out_dir, "sex_counts.csv"),
            row.names = FALSE)

  cat("Training class counts:\n")
  print(table(project$training$diagnosis))
  cat("Connectivity features:", ncol(project$training) - 1L, "\n")
  invisible(demographics)
}
