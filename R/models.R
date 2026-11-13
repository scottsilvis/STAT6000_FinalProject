# Estimate preprocessing from the training rows and apply it to both sets.
prepare_edges <- function(train_x, new_x) {
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
  list(train = train_x, new = new_x)
}

# Use the same fitting code for a CV fold and for the final refit.
fit_and_score <- function(train_x, train_y, new_x, methods, n_edges, n_components, neighbors) {
  edges <- prepare_edges(train_x, new_x)
  train_x <- edges$train
  new_x <- edges$new

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
  if ("PCA + LDA" %in% methods || "PCA + KNN" %in% methods) {
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
