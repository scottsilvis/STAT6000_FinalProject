# experiments/tune_glmnet_nested.R

# ==============================================================================
# Purpose:
#   Nested cross-validation for penalized logistic regression (glmnet),
#   compared with the team's fixed lasso (lambda = 0.01).
#   Outer loop: the team's own 5 folds (seed 6000), so scores compare directly
#   with RESULTS.md.
#   Inner loop: inside each outer training fold only, cv.glmnet picks lambda
#   (by inner-CV AUC) for each alpha; the best alpha/lambda pair is then
#   scored once on the untouched outer fold.
#   Test subjects are never used. Run from the repo root.
# ==============================================================================

# 1. Load the data and helpers -------------------------------------------------
# Provides measure(), features, training_feat, training_diag and
# make_validation_folds(). suppressMessages() hides package startup messages.
suppressMessages({
  source(here::here("R", "metrics.R"))
  source(here::here("R", "01_load_data.R"))
  source(here::here("R", "03_validation.R"))
})

# 2. Build the training data ---------------------------------------------------
# make_validation_folds() expects a data frame with a diagnosis factor whose
# levels are "control" and "asd", the same layout run_analysis.R uses.
edge_names <- paste0("edge_", seq_len(ncol(features)))
training_data <- as.data.frame(training_feat)
names(training_data) <- edge_names
training_data$diagnosis <- factor(
  ifelse(training_diag == 1, "asd", "control"),
  levels = c("control", "asd")
)

# 3. Create the outer folds ----------------------------------------------------
# Same outer folds as run_analysis.R, so the baseline matches RESULTS.md.
number_of_folds <- 5L
folds <- make_validation_folds(
  training_data,
  seed = 6000,
  number_of_folds = number_of_folds
)

# Penalty mix to search: 0 = ridge, 1 = lasso, in between = elastic net.
alpha_grid <- c(0, 0.1, 0.5, 1)

# 4. Define the inner folds ----------------------------------------------------
# Inner folds are built from the outer training fold only, so inner CV never
# sees the outer held-out subjects.
# y: 0/1 labels for the outer training fold. Returns one fold ID
# (1 to number_of_folds) per subject, with each class spread evenly across
# the folds. The seed makes the inner split reproducible.
make_inner_fold_ids <- function(y, number_of_folds = 5L, seed) {
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

# 5. Run nested CV -------------------------------------------------------------
baseline_predictions <- vector("list", number_of_folds)
tuned_predictions <- vector("list", number_of_folds)
chosen_settings <- vector("list", number_of_folds)

for (i in seq_len(nrow(folds))) {
  fold_train <- rsample::analysis(folds$splits[[i]])
  fold_test <- rsample::assessment(folds$splits[[i]])

  # glmnet expects a numeric matrix and 0/1 labels (1 = ASD).
  X_train <- as.matrix(fold_train[, edge_names])
  y_train <- as.integer(fold_train$diagnosis == "asd")
  X_test <- as.matrix(fold_test[, edge_names])
  y_test <- as.integer(fold_test$diagnosis == "asd")

  # A different seed per outer fold gives each fold its own inner split.
  inner_fold_ids <- make_inner_fold_ids(
    y_train,
    number_of_folds = 5L,
    seed = 1000 + i
  )

  # Baseline: the team's current setting (lasso, lambda = 0.01), fitted with
  # glmnet directly so it is scored the same way as the tuned model.
  baseline_fit <- glmnet::glmnet(
    X_train,
    y_train,
    family = "binomial",
    alpha = 1,
    lambda = 0.01
  )
  baseline_predictions[[i]] <- data.frame(
    fold = i,
    actual = y_test,
    score = predict(baseline_fit, X_test, type = "response") |> as.numeric()
  )

  # Inner CV over alpha: cv.glmnet picks lambda for each alpha by AUC, and we
  # keep the alpha with the highest inner AUC (a tie keeps the earlier alpha).
  best_setting <- NULL
  for (alpha in alpha_grid) {
    cv_fit <- glmnet::cv.glmnet(
      X_train,
      y_train,
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
  chosen_settings[[i]] <- data.frame(
    fold = i,
    alpha = best_setting$alpha,
    lambda = best_setting$lambda,
    inner_auc = best_setting$auc
  )

  # Score the chosen setting once on the untouched outer fold.
  tuned_score <- predict(
    best_setting$fit,
    X_test,
    s = "lambda.min",
    type = "response"
  ) |>
    as.numeric()
  tuned_predictions[[i]] <- data.frame(
    fold = i,
    actual = y_test,
    score = tuned_score
  )

  message(sprintf(
    paste0(
      "fold %d: alpha=%.1f lambda=%.4g inner AUC=%.3f | ",
      "outer AUC tuned=%.3f baseline=%.3f"
    ),
    i,
    best_setting$alpha,
    best_setting$lambda,
    best_setting$auc,
    measure(y_test, tuned_score)$roc_auc,
    measure(y_test, baseline_predictions[[i]]$score)$roc_auc
  ))
}

# 6. Report the results --------------------------------------------------------
tuned_out_of_fold <- do.call(rbind, tuned_predictions)
baseline_out_of_fold <- do.call(rbind, baseline_predictions)

cat("\nChosen settings per outer fold:\n")
print(do.call(rbind, chosen_settings))

cat("\nPooled out-of-fold metrics (same 5 folds as RESULTS.md):\n")
pooled_metrics <- rbind(
  data.frame(
    model = "Baseline lasso, lambda 0.01",
    measure(baseline_out_of_fold$actual, baseline_out_of_fold$score)
  ),
  data.frame(
    model = "Nested-CV tuned glmnet",
    measure(tuned_out_of_fold$actual, tuned_out_of_fold$score)
  )
)
print(pooled_metrics, digits = 3)

# predictions: data frame with fold, actual (0/1) and score columns.
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

cat("\nPer-fold AUC\n")
fold_auc_table <- rbind(
  baseline = compute_fold_auc(baseline_out_of_fold),
  tuned = compute_fold_auc(tuned_out_of_fold)
)
fold_auc_table |>
  round(3) |>
  print()
