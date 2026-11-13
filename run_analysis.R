#!/usr/bin/env Rscript

# 1. Settings and input
args <- commandArgs(trailingOnly = TRUE)
usage <- paste("Usage: Rscript run_analysis.R DATA_DIR",
               "[NYU|UM_1|USM|ALL] [OUTPUT_DIR] [--predict]")
if (!length(args) || identical(args, "--help")) {
  cat(usage, "\n")
  quit(status = as.integer(!length(args)))
}

predict_hidden <- "--predict" %in% args
args <- args[args != "--predict"]
if (length(args) < 1L || length(args) > 3L || any(startsWith(args, "--"))) {
  stop(usage, call. = FALSE)
}
data_dir <- args[1]
site <- if (length(args) >= 2L) args[2] else "NYU"
site <- match.arg(site, c("NYU", "UM_1", "USM", "ALL"))
out_dir <- if (length(args) == 3L) args[3] else file.path("results-r", site)

n_folds <- 5L
n_edges <- 5L
n_components <- 10L
neighbors <- 7L
seed <- 6000L
models <- c("Logistic regression", "PCA + LDA", "PCA + KNN")
packages <- c("R.matlab", "MASS", "class")
missing_packages <- packages[!vapply(packages, requireNamespace,
                                     logical(1), quietly = TRUE)]
if (length(missing_packages)) {
  stop("Install the required R packages: ", paste(missing_packages, collapse = ", "))
}

mat <- R.matlab::readMat(file.path(data_dir, "ABIDEI_Final_Project.mat"))
features <- t(mat$FC.edges)
labels <- as.vector(mat$label.ASD.train.only)
is_train <- as.vector(mat$is.train)
site_names <- trimws(unlist(mat$site, use.names = FALSE))
subject_ids <- trimws(unlist(mat$subject.id, use.names = FALSE))
stopifnot(identical(dim(features), c(386L, 19900L)),
          all(lengths(list(labels, is_train, site_names, subject_ids)) == nrow(features)),
          all(is_train %in% 0:1), all(labels[is_train == 1] %in% 0:1),
          all(labels[is_train == 0] %in% -1L),
          all(site_names %in% c("NYU", "UM_1", "USM")),
          all(nzchar(subject_ids)), !anyDuplicated(subject_ids))

site_rows <- site == "ALL" | site_names == site
training_rows <- site_rows & is_train == 1
hidden_rows <- site_rows & is_train == 0
x <- features[training_rows, , drop = FALSE]
y <- labels[training_rows]

# 2. Fit preprocessing and models using only the supplied training split.
# This function is also used for the final refit on all labeled rows.
fit_and_score <- function(train_x, train_y, new_x, methods) {
  # Drop edges with no training values. Fill missing values with training medians.
  train_x[!is.finite(train_x)] <- NA_real_
  new_x[!is.finite(new_x)] <- NA_real_
  keep <- colSums(!is.na(train_x)) > 0L
  train_x <- train_x[, keep, drop = FALSE]
  new_x <- new_x[, keep, drop = FALSE]
  medians <- apply(train_x, 2, median, na.rm = TRUE)

  for (column in which(colSums(is.na(train_x)) + colSums(is.na(new_x)) > 0L)) {
    train_x[is.na(train_x[, column]), column] <- medians[column]
    new_x[is.na(new_x[, column]), column] <- medians[column]
  }

  # Scale the held-out data with the same center and spread as the training data.
  spread <- apply(train_x, 2, sd)
  keep <- is.finite(spread) & spread > 0
  center <- colMeans(train_x)
  train_x <- scale(train_x[, keep, drop = FALSE], center[keep], spread[keep])
  new_x <- scale(new_x[, keep, drop = FALSE],
                 center = attr(train_x, "scaled:center"), scale = spread[keep])

  scores <- matrix(NA_real_, nrow(new_x), length(methods), dimnames = list(NULL, methods))

  # Logistic regression on the strongest individual edges.
  if ("Logistic regression" %in% methods) {
    # With a binary outcome, absolute correlation ranks edges like the one-way F test.
    edge_strength <- abs(drop(crossprod(train_x, train_y - mean(train_y))))
    stopifnot(length(edge_strength) >= n_edges)
    selected <- order(edge_strength, decreasing = TRUE)[seq_len(n_edges)]
    train_edges <- as.data.frame(train_x[, selected, drop = FALSE])
    new_edges <- as.data.frame(new_x[, selected, drop = FALSE])
    fit <- glm(train_y ~ ., data = train_edges, family = binomial())
    if (!fit$converged || fit$rank < n_edges + 1L) {
      stop("Logistic regression failed to converge or has a rank-deficient design.")
    }
    scores[, "Logistic regression"] <- predict(fit, newdata = new_edges, type = "response")
  }

  # Fit one PCA for the two methods that use principal components.
  if (any(c("PCA + LDA", "PCA + KNN") %in% methods)) {
    stopifnot(nrow(train_x) > n_components + 2L, ncol(train_x) >= n_components)
    pca <- prcomp(train_x, center = FALSE, scale. = FALSE, rank. = n_components)
    train_pcs <- pca$x
    new_pcs <- predict(pca, newdata = new_x)
    group <- factor(train_y, levels = 0:1)

    if ("PCA + LDA" %in% methods) {
      fit <- MASS::lda(train_pcs, grouping = group)
      scores[, "PCA + LDA"] <- predict(fit, newdata = new_pcs)$posterior[, "1"]
    }

    if ("PCA + KNN" %in% methods) {
      classification <- class::knn(train_pcs, new_pcs, group, k = neighbors, prob = TRUE)
      vote_share <- attr(classification, "prob")
      # knn returns the winning class's vote share. Recover the ASD share.
      scores[, "PCA + KNN"] <- ifelse(classification == "1", vote_share, 1 - vote_share)
    }
  }

  stopifnot(all(is.finite(scores)), all(scores >= 0 & scores <= 1))
  scores
}

# 3. Use the same stratified folds for all three methods.
measure <- function(actual, score) {
  confusion <- table(actual = factor(actual, levels = 0:1),
                     predicted = factor(as.integer(score >= 0.5), levels = 0:1))
  tn <- confusion["0", "0"]
  fp <- confusion["0", "1"]
  fn <- confusion["1", "0"]
  tp <- confusion["1", "1"]
  # Rank-based ROC AUC gives half credit to ties.
  positives <- sum(actual == 1)
  negatives <- sum(actual == 0)
  auc <- (sum(rank(score)[actual == 1]) - positives * (positives + 1) / 2) /
    (positives * negatives)
  data.frame(roc_auc = auc, accuracy = (tp + tn) / sum(confusion),
             sensitivity = tp / (tp + fn), specificity = tn / (tn + fp),
             tn, fp, fn, tp)
}

set.seed(seed)
fold_id <- integer(length(y))
# In pooled runs, stratifying by site and diagnosis preserves both distributions.
strata <- split(seq_along(y), list(site_names[training_rows], y), drop = TRUE)
for (rows in strata) {
  stopifnot(length(rows) >= n_folds)
  fold_id[rows] <- sample(rep(seq_len(n_folds), length.out = length(rows)))
}

oof_scores <- matrix(NA_real_, length(y), length(models), dimnames = list(NULL, models))
fold_metrics <- NULL
for (fold in seq_len(n_folds)) {
  held_out <- fold_id == fold
  message("Fitting fold ", fold, " of ", n_folds)
  scores <- fit_and_score(x[!held_out, , drop = FALSE], y[!held_out],
                          x[held_out, , drop = FALSE], models)
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

# 4. Save aggregate results and optionally predict the local hidden-test records.
# Describe the cohort by site and split for the output tables.
behavior <- read.csv(file.path(data_dir, "ABIDEI_three_sites_behavior.csv"),
                     colClasses = c(subject_id = "character"))
stopifnot(!anyDuplicated(behavior$subject_id))
demographics <- behavior[match(subject_ids, behavior$subject_id), ]
if (anyNA(demographics$subject_id) || any(demographics$site != site_names)) {
  stop("Demographic IDs or sites do not match the MAT file.")
}

cohort <- data.frame(
  site = site_names[site_rows],
  split = ifelse(is_train[site_rows] == 1, "train", "test"),
  diagnosis = labels[site_rows],
  age = demographics$age[site_rows],
  sex = demographics$sex[site_rows]
)
groups <- split(cohort, list(cohort$site, cohort$split), drop = TRUE)
dataset_summary <- lapply(groups, function(group) {
  age <- group$age[!is.na(group$age)]
  data.frame(
    site = group$site[1], split = group$split[1], subjects = nrow(group),
    features = ncol(x),
    controls = if (group$split[1] == "train") sum(group$diagnosis == 0) else NA,
    asd = if (group$split[1] == "train") sum(group$diagnosis == 1) else NA,
    age_observed = length(age),
    age_mean = if (length(age)) mean(age) else NA,
    age_median = if (length(age)) median(age) else NA,
    age_min = if (length(age)) min(age) else NA,
    age_max = if (length(age)) max(age) else NA
  )
})
dataset_summary <- do.call(rbind, dataset_summary)
sex_counts <- as.data.frame(with(cohort, table(site, split, sex_code = sex, useNA = "ifany")))
names(sex_counts)[4] <- "subjects"
sex_counts <- subset(sex_counts, subjects > 0)

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
write.csv(dataset_summary, file.path(out_dir, "dataset_summary.csv"), row.names = FALSE)
write.csv(sex_counts, file.path(out_dir, "sex_counts.csv"), row.names = FALSE)
write.csv(fold_metrics, file.path(out_dir, "fold_metrics.csv"), row.names = FALSE)
write.csv(comparison, file.path(out_dir, "model_comparison.csv"), row.names = FALSE)
run_settings <- data.frame(site, seed, n_folds, n_edges, n_components, neighbors,
                           selected_model = winner, hidden_predictions = predict_hidden)
write.csv(run_settings, file.path(out_dir, "run_settings.csv"), row.names = FALSE)
writeLines(capture.output(sessionInfo()), file.path(out_dir, "session_info.txt"))

if (predict_hidden) {
  set.seed(seed)
  hidden_scores <- fit_and_score(x, y, features[hidden_rows, , drop = FALSE], winner)[, winner]
  predictions <- data.frame(subject_id = subject_ids[hidden_rows],
                            predicted_label = as.integer(hidden_scores >= 0.5),
                            predicted_probability = hidden_scores)
  write.csv(predictions, file.path(out_dir, paste0(site, "_test_predictions.csv")),
            row.names = FALSE)
}

print(comparison, row.names = FALSE)
message("Results saved to ", normalizePath(out_dir))
