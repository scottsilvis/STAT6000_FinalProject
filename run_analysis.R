#!/usr/bin/env Rscript

# Load the supporting files relative to this script, even when run from elsewhere.
script_arg <- grep("^--file=", commandArgs(), value = TRUE)[1]
script_dir <- dirname(normalizePath(sub("^--file=", "", script_arg), mustWork = TRUE))
source(file.path(script_dir, "R", "project_files.R"))
source(file.path(script_dir, "R", "models.R"))
source(file.path(script_dir, "R", "metrics.R"))

# 1. Set the baseline and select the study cohort.
options <- parse_options()
check_packages()

n_folds <- 5L
n_edges <- 5L
n_components <- 10L
neighbors <- 7L
seed <- 6000L
models <- c("Logistic regression", "PCA + LDA", "PCA + KNN")

study <- read_study(file.path(options$data_dir, "ABIDEI_Final_Project.mat"))
site <- options$site
site_rows <- site == "ALL" | study$site_names == site
training_rows <- site_rows & study$is_train == 1
hidden_rows <- site_rows & study$is_train == 0
x <- study$features[training_rows, , drop = FALSE]
y <- study$labels[training_rows]

# 2. Compare the models on the same five stratified folds.
set.seed(seed)
fold_id <- integer(length(y))
# In pooled runs, stratifying by site and diagnosis preserves both distributions.
strata <- split(seq_along(y), list(study$site_names[training_rows], y), drop = TRUE)
for (rows in strata) {
  stopifnot(length(rows) >= n_folds)
  fold_id[rows] <- sample(rep(seq_len(n_folds), length.out = length(rows)))
}

oof_scores <- matrix(NA_real_, length(y), length(models), dimnames = list(NULL, models))
fold_metrics <- NULL
for (fold in seq_len(n_folds)) {
  held_out <- fold_id == fold
  message("Fitting fold ", fold, " of ", n_folds)
  fold_train <- x[!held_out, , drop = FALSE]
  fold_validation <- x[held_out, , drop = FALSE]
  scores <- fit_and_score(fold_train, y[!held_out], fold_validation, models,
                          n_edges, n_components, neighbors)
  oof_scores[held_out, ] <- scores
  for (model in models) {
    fold_metrics <- rbind(fold_metrics, data.frame(
      model = model, fold = fold, measure(y[held_out], scores[, model])
    ))
  }
}

stopifnot(all(is.finite(oof_scores)))
comparison <- NULL
for (model in models) {
  comparison <- rbind(comparison, data.frame(model = model, measure(y, oof_scores[, model])))
}
comparison <- comparison[order(comparison$roc_auc, decreasing = TRUE), ]
winner <- comparison$model[1]

# 3. Save the comparison and the cohort summaries.
behavior_path <- file.path(options$data_dir, "ABIDEI_three_sites_behavior.csv")
demographics <- summarize_demographics(behavior_path, study, site_rows)
run_settings <- data.frame(site, seed, n_folds, n_edges, n_components, neighbors,
                           selected_model = winner, hidden_predictions = options$predict_hidden)
save_results(options$out_dir, demographics, fold_metrics, comparison, run_settings)

# 4. If requested, refit the winner and score the hidden-test subjects.
if (options$predict_hidden) {
  set.seed(seed)
  test_features <- study$features[hidden_rows, , drop = FALSE]
  test_scores <- fit_and_score(x, y, test_features, winner,
                               n_edges, n_components, neighbors)
  asd_score <- test_scores[, winner]
  predictions <- data.frame(subject_id = study$subject_ids[hidden_rows],
                            predicted_label = as.integer(asd_score >= 0.5),
                            predicted_probability = asd_score)
  prediction_path <- file.path(options$out_dir, paste0(site, "_test_predictions.csv"))
  write.csv(predictions, prediction_path, row.names = FALSE)
}

print(comparison, row.names = FALSE)
message("Results saved to ", normalizePath(options$out_dir))
