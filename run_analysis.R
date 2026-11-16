#!/usr/bin/env Rscript

# Run the STAT 6000 analysis in the same order as the lab workflow.
file_arg <- grep("^--file=", commandArgs(), value = TRUE)[1]
project_root <- dirname(normalizePath(sub("^--file=", "", file_arg)))

source(file.path(project_root, "R/project_files.R"))
source(file.path(project_root, "R/metrics.R")) # User-maintained metrics
source(file.path(project_root, "R/01_load_date.R"))
source(file.path(project_root, "R/02_eda.R"))
source(file.path(project_root, "R/03_validation.R"))
source(file.path(project_root, "R/04_logistic-regression.R"))
source(file.path(project_root, "R/04_pca.R"))
source(file.path(project_root, "R/05_compare.R"))
source(file.path(project_root, "R/06_predict.R"))

# 1. Load data and select a site (or all three sites).
settings <- parse_options()
check_packages()
project <- load_project_data(settings$data_dir, settings$site)

# 2. Summarize the study data without using hidden diagnoses.
describe_data(project, settings$data_dir, settings$out_dir)

# 3. Create the five cross-validation folds shared by every method.
folds <- make_validation_folds(project$training, seed = 6000, number_of_folds = 5)

# 4. Define the classifiers; the recipes are fitted within each fold.
workflows_to_compare <- c(
  list("Logistic regression" = make_logistic_workflow(project$training)),
  make_pca_workflows(project$training, components = 10, neighbors = 7)
)

# 5. Compare the held-out predictions using R/metrics.R.
comparison <- compare_models(workflows_to_compare, folds, settings$out_dir)
winner <- comparison$model[1]
message("Selected model: ", winner)

run_settings <- data.frame(
  site = settings$site,
  seed = 6000,
  n_folds = 5,
  n_components = 10,
  neighbors = 7,
  logistic_penalty = 0.01,
  selected_model = winner,
  hidden_predictions = settings$predict_hidden
)
write.csv(run_settings, file.path(settings$out_dir, "run_settings.csv"), row.names = FALSE)
writeLines(capture.output(sessionInfo()), file.path(settings$out_dir, "session_info.txt"))

# 6. Optionally refit the selected workflow to predict hidden subjects.
if (settings$predict_hidden) {
  predict_hidden(workflows_to_compare[[winner]], project,
                 settings$out_dir, site = settings$site)
}
