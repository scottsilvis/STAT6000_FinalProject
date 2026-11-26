# preprocessing_experiments.R
# Compare preprocessing and feature-selection strategies with nested CV.
#
# Design
# - Outer CV: two 5-fold splits of the 269 labeled training subjects
#   (split A = the team's folds, seed 6000; split B = stratified, seed 2026).
# - Every learned preprocessing step (site means/SDs, confound coefficients,
#   t-test edge ranking, PCA) is fitted on the outer training fold only and
#   then applied unchanged to the held-out fold.
# - Downstream model: penalized logistic regression with alpha in
#   {0, 0.1, 0.5, 1} and lambda chosen by inner 5-fold CV AUC on the outer
#   training fold (same as the tuned Round 1 model). PCA + LDA variants
#   choose the number of components by inner CV instead.
# - Test subjects are never touched.
#
# Usage: Rscript --max-ppsize=500000 preprocessing_experiments.R [variant ...]

suppressMessages({
  source(here::here("R", "metrics.R"))
  source(here::here("R", "01_load_data.R"))
  source(here::here("R", "03_validation.R"))
  library(glmnet)
  library(MASS)
  library(parallel)
})

X <- training_feat
y <- as.integer(training_diag == 1)
meta <- data.frame(
  site = factor(site[training]),
  age = demo$age[training],
  sex = demo$sex[training]
)
n <- nrow(X)
alphas <- c(0, 0.1, 0.5, 1)

# ROI pairs for node-level features
roi_i <- as.vector(study$roi.i); roi_j <- as.vector(study$roi.j)
incidence <- Matrix::sparseMatrix(
  i = c(seq_along(roi_i), seq_along(roi_j)),
  j = c(roi_i, roi_j), x = 1, dims = c(length(roi_i), 200)
)

# ---- outer splits --------------------------------------------------------
strat_ids <- function(y, k, seed) {
  set.seed(seed)
  id <- integer(length(y))
  for (cl in unique(y)) {
    idx <- which(y == cl)
    id[idx] <- sample(rep_len(seq_len(k), length(idx)))
  }
  id
}
team_df <- data.frame(diagnosis = factor(ifelse(y == 1, "asd", "control")))
team_folds <- make_validation_folds(team_df, seed = 6000, number_of_folds = 5)
split_A <- integer(n)
for (i in 1:5) split_A[rsample::complement(team_folds$splits[[i]])] <- i
splits <- list(A = split_A, B = strat_ids(y, 5, 2026))

# ---- downstream models ---------------------------------------------------
tuned_glmnet <- function(xtr, ytr, xte, seed) {
  fid <- strat_ids(ytr, 5, seed)
  best <- NULL
  for (a in alphas) {
    cv <- cv.glmnet(xtr, ytr, family = "binomial", alpha = a,
                    foldid = fid, type.measure = "auc")
    if (is.null(best) || max(cv$cvm) > best$auc)
      best <- list(alpha = a, auc = max(cv$cvm), fit = cv)
  }
  list(score = as.numeric(predict(best$fit, xte, s = "lambda.min", type = "response")),
       info = sprintf("alpha=%.1f", best$alpha))
}

pca_scores <- function(xtr, xte, k) {
  mu <- colMeans(xtr); s <- apply(xtr, 2, sd); s[s == 0] <- 1
  ztr <- sweep(sweep(xtr, 2, mu), 2, s, "/")
  zte <- sweep(sweep(xte, 2, mu), 2, s, "/")
  sv <- svd(ztr, nu = 0, nv = k)
  list(tr = ztr %*% sv$v, te = zte %*% sv$v)
}
lda_prob <- function(tr, ytr, te) {
  fit <- lda(tr, grouping = ytr)
  predict(fit, te)$posterior[, "1"]
}
tuned_pca_lda <- function(xtr, ytr, xte, seed, ks = c(5, 10, 20, 40, 80)) {
  fid <- strat_ids(ytr, 5, seed)
  inner <- sapply(ks, function(k) {
    sc <- numeric(length(ytr))
    for (f in 1:5) {
      p <- pca_scores(xtr[fid != f, ], xtr[fid == f, , drop = FALSE], k)
      sc[fid == f] <- lda_prob(p$tr, ytr[fid != f], p$te)
    }
    measure(ytr, sc)$roc_auc
  })
  k <- ks[which.max(inner)]
  p <- pca_scores(xtr, xte, k)
  list(score = lda_prob(p$tr, ytr, p$te), info = sprintf("k=%d", k))
}

# ---- preprocessing steps (fit on training rows, apply to both) -----------
site_center <- function(xtr, xte, mtr, mte, scale = FALSE) {
  for (s in levels(mtr$site)) {
    r_tr <- mtr$site == s; r_te <- mte$site == s
    mu <- colMeans(xtr[r_tr, , drop = FALSE])
    sdv <- if (scale) { v <- apply(xtr[r_tr, , drop = FALSE], 2, sd); v[v == 0] <- 1; v } else 1
    xtr[r_tr, ] <- sweep(sweep(xtr[r_tr, , drop = FALSE], 2, mu), 2, sdv, "/")
    if (any(r_te)) xte[r_te, ] <- sweep(sweep(xte[r_te, , drop = FALSE], 2, mu), 2, sdv, "/")
  }
  list(tr = xtr, te = xte)
}
confound_regress <- function(xtr, xte, mtr, mte) {
  ztr <- model.matrix(~ age + sex + site, mtr)
  zte <- model.matrix(~ age + sex + site, mte)
  B <- solve(crossprod(ztr), crossprod(ztr, xtr))
  list(tr = xtr - ztr %*% B, te = xte - zte %*% B)
}
ttest_rank <- function(xtr, ytr) {
  a <- xtr[ytr == 1, , drop = FALSE]; b <- xtr[ytr == 0, , drop = FALSE]
  na <- nrow(a); nb <- nrow(b)
  sp <- sqrt(((na - 1) * apply(a, 2, var) + (nb - 1) * apply(b, 2, var)) / (na + nb - 2))
  t <- (colMeans(a) - colMeans(b)) / (sp * sqrt(1 / na + 1 / nb))
  p <- 2 * pt(-abs(t), df = na + nb - 2)
  list(order = order(p), p = p)
}
node_strength <- function(x) as.matrix(x %*% incidence) / 199

# ---- variants -------------------------------------------------------------
# Each returns list(score = held-out ASD probabilities, info = text)
variants <- list(
  baseline_raw = function(xtr, ytr, xte, mtr, mte, seed)
    tuned_glmnet(xtr, ytr, xte, seed),

  site_center = function(xtr, ytr, xte, mtr, mte, seed) {
    d <- site_center(xtr, xte, mtr, mte); tuned_glmnet(d$tr, ytr, d$te, seed)
  },

  site_standardize = function(xtr, ytr, xte, mtr, mte, seed) {
    d <- site_center(xtr, xte, mtr, mte, scale = TRUE); tuned_glmnet(d$tr, ytr, d$te, seed)
  },

  confound_age_sex_site = function(xtr, ytr, xte, mtr, mte, seed) {
    d <- confound_regress(xtr, xte, mtr, mte); tuned_glmnet(d$tr, ytr, d$te, seed)
  },

  ttest_top500 = function(xtr, ytr, xte, mtr, mte, seed) {
    keep <- ttest_rank(xtr, ytr)$order[1:500]
    tuned_glmnet(xtr[, keep], ytr, xte[, keep, drop = FALSE], seed)
  },

  ttest_top2000 = function(xtr, ytr, xte, mtr, mte, seed) {
    keep <- ttest_rank(xtr, ytr)$order[1:2000]
    tuned_glmnet(xtr[, keep], ytr, xte[, keep, drop = FALSE], seed)
  },

  ttest_top5000 = function(xtr, ytr, xte, mtr, mte, seed) {
    keep <- ttest_rank(xtr, ytr)$order[1:5000]
    tuned_glmnet(xtr[, keep], ytr, xte[, keep, drop = FALSE], seed)
  },

  fdr_bh_q10 = function(xtr, ytr, xte, mtr, mte, seed) {
    r <- ttest_rank(xtr, ytr)
    keep <- which(p.adjust(r$p, "BH") <= 0.10)
    note <- sprintf("BH kept %d", length(keep))
    if (length(keep) < 20) keep <- r$order[1:20]  # fallback so glmnet can run
    out <- tuned_glmnet(xtr[, keep, drop = FALSE], ytr, xte[, keep, drop = FALSE], seed)
    out$info <- paste(out$info, note); out
  },

  node_strength_200 = function(xtr, ytr, xte, mtr, mte, seed)
    tuned_glmnet(node_strength(xtr), ytr, node_strength(xte), seed),

  site_center_then_ttest2000 = function(xtr, ytr, xte, mtr, mte, seed) {
    d <- site_center(xtr, xte, mtr, mte)
    keep <- ttest_rank(d$tr, ytr)$order[1:2000]
    tuned_glmnet(d$tr[, keep], ytr, d$te[, keep, drop = FALSE], seed)
  },

  pca_lda_tuned_k = function(xtr, ytr, xte, mtr, mte, seed)
    tuned_pca_lda(xtr, ytr, xte, seed),

  site_center_pca_lda_tuned_k = function(xtr, ytr, xte, mtr, mte, seed) {
    d <- site_center(xtr, xte, mtr, mte); tuned_pca_lda(d$tr, ytr, d$te, seed)
  }
)

# ---- runner ---------------------------------------------------------------
run_variant <- function(name) {
  jobs <- expand.grid(split = names(splits), fold = 1:5, stringsAsFactors = FALSE)
  res <- mclapply(seq_len(nrow(jobs)), function(j) {
    sp <- jobs$split[j]; f <- jobs$fold[j]; id <- splits[[sp]]
    tr <- id != f; te <- id == f
    out <- variants[[name]](X[tr, ], y[tr], X[te, , drop = FALSE],
                            meta[tr, ], meta[te, ], seed = 100 * f + match(sp, names(splits)))
    data.frame(variant = name, split = sp, fold = f, row = which(te),
               actual = y[te], score = out$score, info = out$info)
  }, mc.cores = if (.Platform$OS.type == "windows") 1L else 2L)
  errs <- vapply(res, inherits, logical(1), "try-error")
  if (any(errs)) stop(name, ": ", res[[which(errs)[1]]])
  do.call(rbind, res)
}

dir.create("results/preprocessing", showWarnings = FALSE)
todo <- commandArgs(trailingOnly = TRUE)
if (length(todo) == 0) todo <- names(variants)
for (v in todo) {
  t0 <- Sys.time()
  out <- run_variant(v)
  write.csv(out, file.path("results/preprocessing", paste0(v, ".csv")), row.names = FALSE)
  s <- sapply(split(out, out$split), function(d) measure(d$actual, d$score)$roc_auc)
  message(sprintf("%-28s AUC A=%.3f B=%.3f mean=%.3f  (%.1f min)  %s", v, s["A"], s["B"], mean(s),
                  as.numeric(difftime(Sys.time(), t0, units = "mins")),
                  paste(unique(out$info), collapse = "; ")))
}
