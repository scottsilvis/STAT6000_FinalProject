# Data file path relative to the repository root.
mat_file <- "data/ABIDEI_Final_Project.mat"

source("R/models.R")   # prepare_edges(): training medians, means, and SDs
source("R/metrics.R")  # measure(): AUC and confusion-matrix metrics

# 1. Inspect the labeled NYU data.
mat <- R.matlab::readMat(mat_file)
nyu_train <- unlist(mat$site) == "NYU" & as.vector(mat$is.train) == 1

x <- t(mat$FC.edges[, nyu_train])
y <- as.vector(mat$label.ASD.train.only)[nyu_train]
print(dim(x))
print(table(diagnosis = y))  # 0 = control, 1 = ASD

# 2. Assign cases and controls separately to five folds.
set.seed(6000)
fold <- integer(length(y))
for (diagnosis in 0:1) {
  rows <- which(y == diagnosis)
  fold[rows] <- sample(rep(1:5, length.out = length(rows)))
}

# 3. Fit all three models in each fold and save their held-out ASD scores.
logistic_score <- lda_score <- knn_score <- rep(NA_real_, length(y))
for (f in 1:5) {
  validation <- fold == f
  train_y <- y[!validation]
  edges <- prepare_edges(x[!validation, ], x[validation, ])

  # Logistic regression on the five edges most correlated with diagnosis.
  # The edges are already standardized, so this cross-product ranks their correlations.
  strength <- abs(drop(crossprod(edges$train, train_y - mean(train_y))))
  top_edges <- order(strength, decreasing = TRUE)[1:5]
  train_edges <- as.data.frame(edges$train[, top_edges])
  validation_edges <- as.data.frame(edges$new[, top_edges])

  logistic <- glm(train_y ~ ., data = train_edges, family = binomial())
  logistic_score[validation] <- predict(logistic, validation_edges, type = "response")

  # Fit PCA on the training rows. Use its first ten PCs for LDA and KNN.
  pca <- prcomp(edges$train, center = FALSE, scale. = FALSE, rank. = 10)
  train_pcs <- pca$x
  validation_pcs <- predict(pca, edges$new)
  diagnosis <- factor(train_y, levels = 0:1)

  lda <- MASS::lda(train_pcs, grouping = diagnosis)
  lda_score[validation] <- predict(lda, validation_pcs)$posterior[, "1"]

  knn <- class::knn(train_pcs, validation_pcs, diagnosis, k = 7, prob = TRUE)
  winning_share <- attr(knn, "prob")
  knn_score[validation] <- ifelse(knn == "1", winning_share, 1 - winning_share)
}

# 4. Compare the held-out scores for all 125 labeled subjects.
results <- rbind(
  "Logistic regression" = measure(y, logistic_score),
  "PCA + LDA" = measure(y, lda_score),
  "PCA + KNN" = measure(y, knn_score)
)
print(results[order(results$roc_auc, decreasing = TRUE), ])
