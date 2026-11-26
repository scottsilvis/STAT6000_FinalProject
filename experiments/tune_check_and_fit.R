# experiments/tune_check_and_fit.R

# ==============================================================================
# Purpose:
#   1. Repeat the nested-CV comparison (baseline lasso, lambda = 0.01, against
#      tuned glmnet) on two new outer fold splits, to check the gain is not a
#      fluke of one split.
#   2. Fit the tuned model on all 269 training subjects (inner CV picks alpha
#      and lambda using training subjects only) and predict the 117 test
#      subjects. This produced Group 1's Round 1 submission.
#   Writes results/test_predictions_tuned.csv and reads
#   results/test_predictions.csv (from run_analysis.R). Run from the repo root.
# ==============================================================================

# 1. Load the data and helpers -------------------------------------------------
# Provides measure(), training_feat, training_diag, test_feat and test_ids.
# suppressMessages() hides package startup messages.
suppressMessages({
  source(here::here("R", "metrics.R"))
  source(here::here("R", "01_load_data.R"))
})

# glmnet expects a numeric matrix and 0/1 labels (1 = ASD).
X <- training_feat
y <- as.integer(training_diag == 1)

number_of_folds <- 5L

# Penalty mix to search: 0 = ridge, 1 = lasso, in between = elastic net.
alpha_grid <- c(0, 0.1, 0.5, 1)

# 2. Define the fold and tuning helpers ----------------------------------------
# Used for both the outer and the inner folds.
# y: 0/1 labels. Returns one fold ID (1 to number_of_folds) per subject, with
# each class spread evenly across the folds. The seed makes it reproducible.
make_stratified_fold_ids <- function(y, number_of_folds, seed) {
  set.seed(seed)
  fold_ids <- integer(length(y))
  for (class_label in unique(y)) {
    class_rows <- which(y == class_label)
    fold_ids[class_rows] <- sample(
      rep_len(seq_len(number_of_folds), length(class_rows))
    )
  }
  fold_ids
}

# Tunes glmnet by inner CV, so X and y must hold training subjects only.
# X: numeric matrix of edges; y: 0/1 labels. For each alpha in alpha_grid,
# cv.glmnet picks lambda by AUC, and the alpha with the highest inner AUC wins
# (a tie keeps the earlier alpha). Returns a list with alpha, lambda, auc and
# the winning cv.glmnet fit.
tune_glmnet <- function(X, y, seed) {
  inner_fold_ids <- make_stratified_fold_ids(
    y,
    number_of_folds = 5L,
    seed = seed
  )
  best_setting <- NULL
  for (alpha in alpha_grid) {
    cv_fit <- glmnet::cv.glmnet(
      X,
      y,
      family = "binomial",
      alpha = alpha,
      foldid = inner_fold_ids,
      type.measure = "auc"
    )
    best_inner_auc <- max(cv_fit$cvm)
    if (is.null(best_setting) || best_inner_auc > best_setting$auc) {
      best_setting <- list(
        alpha = alpha,
        lambda = cv_fit$lambda.min,
        auc = best_inner_auc,
        fit = cv_fit
      )
    }
  }
  best_setting
}

# predictions: data frame with actual (0/1), score and fold columns.
# Returns one AUC per fold, named by fold number.
compute_fold_auc <- function(predictions) {
  vapply(
    split(predictions, predictions$fold),
    function(fold_predictions) {
      measure(fold_predictions$actual, fold_predictions$score)$roc_auc
    },
    numeric(1)
  )
}

# 3. Repeat nested CV on new outer splits --------------------------------------
# Two outer splits not used before. Each outer fold's inner seed comes from
# the outer seed, so every fold gets its own inner split.
for (outer_seed in c(2026, 7)) {
  outer_fold_ids <- make_stratified_fold_ids(
    y,
    number_of_folds = number_of_folds,
    seed = outer_seed
  )
  baseline_predictions <- vector("list", number_of_folds)
  tuned_predictions <- vector("list", number_of_folds)

  for (i in seq_len(number_of_folds)) {
    in_train <- outer_fold_ids != i
    in_test <- outer_fold_ids == i

    # Baseline: the team's current setting (lasso, lambda = 0.01).
    baseline_fit <- glmnet::glmnet(
      X[in_train, ],
      y[in_train],
      family = "binomial",
      alpha = 1,
      lambda = 0.01
    )
    baseline_predictions[[i]] <- data.frame(
      actual = y[in_test],
      score = predict(baseline_fit, X[in_test, ], type = "response") |>
        as.numeric(),
      fold = i
    )

    # Tuned: inner CV on this outer training fold only.
    best_setting <- tune_glmnet(
      X[in_train, ],
      y[in_train],
      seed = outer_seed * 10 + i
    )
    tuned_predictions[[i]] <- data.frame(
      actual = y[in_test],
      score = predict(
        best_setting$fit,
        X[in_test, ],
        s = "lambda.min",
        type = "response"
      ) |>
        as.numeric(),
      fold = i
    )
  }

  baseline_out_of_fold <- do.call(rbind, baseline_predictions)
  tuned_out_of_fold <- do.call(rbind, tuned_predictions)
  baseline_metrics <- measure(
    baseline_out_of_fold$actual,
    baseline_out_of_fold$score
  )
  tuned_metrics <- measure(tuned_out_of_fold$actual, tuned_out_of_fold$score)
  tuned_fold_auc <- compute_fold_auc(tuned_out_of_fold)
  baseline_fold_auc <- compute_fold_auc(baseline_out_of_fold)
  tuned_fold_wins <- sum(tuned_fold_auc > baseline_fold_auc)

  cat(sprintf(
    paste0(
      "\nOuter split seed %d: pooled AUC baseline %.3f | tuned %.3f ; ",
      "accuracy baseline %.3f | tuned %.3f ; tuned wins %d of 5 folds\n"
    ),
    outer_seed,
    baseline_metrics$roc_auc,
    tuned_metrics$roc_auc,
    baseline_metrics$accuracy,
    tuned_metrics$accuracy,
    tuned_fold_wins
  ))
}

# 4. Fit the final tuned model -------------------------------------------------
# Inner CV on all 269 training subjects picks alpha and lambda; the test
# subjects are only used for prediction.
final_setting <- tune_glmnet(X, y, seed = 6000)
cat(sprintf(
  "\nFinal model: alpha = %.1f, lambda = %.4g, inner-CV AUC = %.3f\n",
  final_setting$alpha,
  final_setting$lambda,
  final_setting$auc
))

test_probability <- predict(
  final_setting$fit,
  test_feat,
  s = "lambda.min",
  type = "response"
) |>
  as.numeric()
tuned_test_predictions <- data.frame(
  subject_id = test_ids,
  predicted_label = as.integer(test_probability >= 0.5),
  predicted_probability = test_probability
)

# Check before writing: one row per test subject and valid probabilities.
stopifnot(
  nrow(tuned_test_predictions) == 117L,
  !anyDuplicated(tuned_test_predictions$subject_id),
  all(is.finite(test_probability)),
  all(test_probability >= 0 & test_probability <= 1)
)
write.csv(
  tuned_test_predictions,
  "results/test_predictions_tuned.csv",
  row.names = FALSE
)
cat(sprintf(
  "Tuned test predictions: %d ASD of 117; probability range %.3f to %.3f\n",
  sum(tuned_test_predictions$predicted_label),
  min(test_probability),
  max(test_probability)
))

# 5. Compare with the original model -------------------------------------------
# results/test_predictions.csv comes from run_analysis.R (the fixed lasso).
# Read IDs as text to keep their leading zeros, and check the row order
# matches before comparing.
original_predictions <- read.csv(
  "results/test_predictions.csv",
  colClasses = c(subject_id = "character")
)
stopifnot(
  identical(original_predictions$subject_id, tuned_test_predictions$subject_id)
)
label_agreement <- sum(
  original_predictions$predicted_label ==
    tuned_test_predictions$predicted_label
)
rank_correlation <- cor(
  original_predictions$predicted_probability,
  test_probability,
  method = "spearman"
)
cat(sprintf(
  paste0(
    "Agreement with current Round 1 labels: %d of 117; ",
    "rank correlation of probabilities %.3f\n"
  ),
  label_agreement,
  rank_correlation
))
