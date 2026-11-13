parse_options <- function() {
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
  list(data_dir = data_dir, site = site, out_dir = out_dir, predict_hidden = predict_hidden)
}

check_packages <- function() {
  packages <- c("R.matlab", "MASS", "class")
  missing_packages <- packages[!vapply(packages, requireNamespace,
                                       logical(1), quietly = TRUE)]
  if (length(missing_packages)) {
    stop("Install the required R packages: ", paste(missing_packages, collapse = ", "))
  }
}

read_study <- function(path) {
  mat <- R.matlab::readMat(path)
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
  list(features = features, labels = labels, is_train = is_train,
       site_names = site_names, subject_ids = subject_ids)
}

summarize_demographics <- function(path, study, site_rows) {
  subject_ids <- study$subject_ids
  site_names <- study$site_names
  is_train <- study$is_train
  labels <- study$labels
  feature_count <- ncol(study$features)
  # Describe the cohort by site and split for the output tables.
  behavior <- read.csv(path,
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
      features = feature_count,
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
  list(summary = dataset_summary, sex_counts = sex_counts)
}

save_results <- function(out_dir, demographics, fold_metrics, comparison, run_settings) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  write.csv(demographics$summary, file.path(out_dir, "dataset_summary.csv"), row.names = FALSE)
  write.csv(demographics$sex_counts, file.path(out_dir, "sex_counts.csv"), row.names = FALSE)
  write.csv(fold_metrics, file.path(out_dir, "fold_metrics.csv"), row.names = FALSE)
  write.csv(comparison, file.path(out_dir, "model_comparison.csv"), row.names = FALSE)
  write.csv(run_settings, file.path(out_dir, "run_settings.csv"), row.names = FALSE)
  writeLines(capture.output(sessionInfo()), file.path(out_dir, "session_info.txt"))
}
