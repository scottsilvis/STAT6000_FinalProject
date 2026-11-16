# NYU lab: compare three classifiers with five-fold cross-validation.
# Preprocessing and model fitting are handled by tidymodels in R/models.R.

source("R/models.R")
source("R/metrics.R")

mat <- R.matlab::readMat("data/ABIDEI_Final_Project.mat")
is_nyu_training <- trimws(unlist(mat$site)) == "NYU" &
  as.vector(mat$is.train) == 1

x <- t(mat$FC.edges[, is_nyu_training])
y <- as.vector(mat$label.ASD.train.only)[is_nyu_training]

print(dim(x))
print(table(diagnosis = y))

# Assign controls and ASD subjects evenly across five folds.
set.seed(6000)
fold <- integer(length(y))
for (diagnosis in 0:1) {
  rows <- which(y == diagnosis)
  fold[rows] <- sample(rep(1:5, length.out = length(rows)))
}

methods <- c("Logistic regression", "PCA + LDA", "PCA + KNN")
predicted <- matrix(NA_real_, length(y), length(methods),
                    dimnames = list(NULL, methods))

for (f in 1:5) {
  held_out <- fold == f
  predicted[held_out, ] <- fit_and_score(
    train_x = x[!held_out, , drop = FALSE],
    train_y = y[!held_out],
    new_x = x[held_out, , drop = FALSE],
    methods = methods,
    n_edges = 5,
    n_components = 10,
    neighbors = 7
  )
}

results <- do.call(rbind, lapply(methods, function(method) {
  cbind(model = method, measure(y, predicted[, method]))
}))
print(results[order(results$roc_auc, decreasing = TRUE), ], row.names = FALSE)
