# run_analysis.R

# ==============================================================================
# Purpose:
#   Run the whole project from the repository root:
#     source("run_analysis.R")   or   Rscript run_analysis.R
#   Loads the data, runs the EDA, cross-validates three models, picks the model
#   with the highest pooled held-out ROC AUC, and predicts the test subjects.
#   Tables, figures and predictions are saved to results/.
# ==============================================================================

# 1. Load the helper functions and run the data and EDA scripts ----------------
source(here::here("R", "metrics.R"))
source(here::here("R", "01_load_data.R"))
source(here::here("R", "02_eda.R"))
source(here::here("R", "03_validation.R"))
source(here::here("R", "04_logistic-regression.R"))
source(here::here("R", "04_pca.R"))
source(here::here("R", "05_compare.R"))
source(here::here("R", "06_predict.R"))

# 2. Build the modeling data ---------------------------------------------------
# The workflows need named predictor columns and a factor outcome.
edge_names <- paste0("edge_", seq_len(ncol(features)))

training_data <- as.data.frame(training_feat)
names(training_data) <- edge_names
training_data$diagnosis <- factor(
  ifelse(training_diag == 1, "asd", "control"),
  levels = c("control", "asd")
)

test_data <- as.data.frame(test_feat)
names(test_data) <- edge_names

# 3. Cross-validate the models -------------------------------------------------
folds <- make_validation_folds(training_data, seed = 6000, number_of_folds = 5)

workflows_to_compare <- c(
  list("Logistic regression" = make_logistic_workflow(training_data)),
  make_pca_workflows(training_data, components = 10, neighbors = 7)
)

comparison <- compare_models(workflows_to_compare, folds)
comparison

# 4. Predict the test subjects with the best model -----------------------------
# The best model is chosen from training-only cross-validation, never from test
# subjects.
best_model <- comparison$model[1]
message("Best model by cross-validated ROC AUC: ", best_model)

test_predictions <- predict_test_subjects(
  chosen_workflow = workflows_to_compare[[best_model]],
  training = training_data,
  test = test_data,
  test_ids = test_ids
)

# 5. Save the R environment ----------------------------------------------------
writeLines(
  capture.output(sessionInfo()),
  here::here("results", "session_info.txt")
)
