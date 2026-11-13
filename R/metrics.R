# Evaluate held-out scores with ASD as the positive class.
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
