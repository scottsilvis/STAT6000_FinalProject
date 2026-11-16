# R/metrics.R

# ==============================================================================
# Purpose:
#   Evaluate held-out scores with ASD as the positive class. measure() returns
#   ROC AUC, accuracy, sensitivity, specificity, and confusion counts.
# ==============================================================================

# actual: true labels, 0 = control and 1 = ASD
# score:  predicted probability of ASD, classified as ASD at 0.5 or higher
measure <- function(actual, score) {
  confusion <- table(
    actual = factor(actual, levels = 0:1),
    predicted = factor(as.integer(score >= 0.5), levels = 0:1)
  )

  tn <- confusion["0", "0"] # true negative
  fp <- confusion["0", "1"] # false positive
  fn <- confusion["1", "0"] # false negative
  tp <- confusion["1", "1"] # true positive

  # Calculate accuracy, sensitivity, specificity
  accuracy <- (tp + tn) / sum(confusion)
  sensitivity <- tp / (fn + tp)
  specificity <- tn / (tn + fp)

  # Calculate ROC
  roc_curve <- pROC::roc(
    actual, score,
    levels = c(0, 1),
    direction = "<",
    quiet = TRUE
  )

  roc_auc <- as.numeric(pROC::auc(roc_curve))

  data.frame(
    roc_auc = roc_auc,
    accuracy = accuracy,
    sensitivity = sensitivity,
    specificity = specificity,
    tn = tn,
    fp = fp,
    fn = fn,
    tp = tp
  )
}
