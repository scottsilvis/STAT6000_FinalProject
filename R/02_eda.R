# Exploratory Data Analysis (EDA) for the three-site ABIDE dataset.
# Figures use ggplot2. Hidden-test diagnoses are never inferred.

describe_data <- function(study, data_dir = "data", out_dir = "results-r/ALL") {

  # 1. Extract subject information from the imported MATLAB file.
  subject_id <- trimws(unlist(study$subject.id, use.names = FALSE))
  site <- trimws(unlist(study$site, use.names = FALSE))
  is_train <- as.logical(as.vector(study$is.train))
  diagnosis <- as.vector(study$label.ASD.train.only)

  # 2. Match demographics to the MATLAB subjects by ID, not row position.
  demographics <- read.csv(
    file.path(data_dir, "ABIDEI_three_sites_behavior.csv"),
    colClasses = c(subject_id = "character")
  )

  stopifnot(!anyDuplicated(subject_id),
            !anyDuplicated(demographics$subject_id))
  demographics <- demographics[match(subject_id, demographics$subject_id), ]
  stopifnot(!anyNA(demographics$subject_id),
            all(as.character(demographics$site) == site))

  # Keep the unknown diagnosis as "Hidden", never as a third clinical class.
  subjects <- data.frame(
    subject_id = subject_id,
    site = site,
    split = ifelse(is_train, "Labeled", "Hidden"),
    diagnosis = ifelse(!is_train, "Hidden",
                       ifelse(diagnosis == 1, "ASD", "Control")),
    age = as.numeric(demographics$age),
    sex_code = as.character(demographics$sex)
  )

  # 3. Summarize the sample size, sites and known diagnoses.
  site_counts <- as.data.frame(table(site = subjects$site, split = subjects$split))
  names(site_counts)[3] <- "subjects"

  labeled_subjects <- subjects[is_train, ]
  class_balance <- as.data.frame(table(
    site = labeled_subjects$site, diagnosis = labeled_subjects$diagnosis
  ))
  names(class_balance)[3] <- "subjects"

  sex_counts <- as.data.frame(table(
    site = subjects$site, split = subjects$split,
    sex_code = subjects$sex_code, useNA = "ifany"
  ))
  names(sex_counts)[4] <- "subjects"
  sex_counts <- sex_counts[sex_counts$subjects > 0, ]

  # Age is described separately by site and known/hidden split.
  age_groups <- split(subjects, list(subjects$site, subjects$split),
                      drop = TRUE)
  age_summary <- do.call(rbind, lapply(age_groups, function(group) {
    known_ages <- group$age[!is.na(group$age)]
    data.frame(
      site = group$site[1],
      split = group$split[1],
      subjects = nrow(group),
      age_available = length(known_ages),
      mean_age = if (length(known_ages)) mean(known_ages) else NA_real_,
      median_age = if (length(known_ages)) median(known_ages) else NA_real_,
      min_age = if (length(known_ages)) min(known_ages) else NA_real_,
      max_age = if (length(known_ages)) max(known_ages) else NA_real_
    )
  }))
  rownames(age_summary) <- NULL

  # 4. Describe feature dimensionality and data completeness.
  # The instructor supplies the same 19,900 edges for every subject.
  feature_summary <- data.frame(
    subjects = length(subject_id),
    labeled = sum(is_train),
    hidden = sum(!is_train),
    regions = as.integer(study$n.roi),
    connectivity_features = nrow(study$FC.edges),
    missing_or_nonfinite_features = sum(!is.finite(study$FC.edges))
  )

  # 5. Save report-ready tables.
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  write.csv(site_counts, file.path(out_dir, "dataset_summary.csv"), row.names = FALSE)
  write.csv(class_balance, file.path(out_dir, "class_balance.csv"), row.names = FALSE)
  write.csv(age_summary, file.path(out_dir, "age_summary.csv"), row.names = FALSE)
  write.csv(sex_counts, file.path(out_dir, "sex_counts.csv"), row.names = FALSE)
  write.csv(feature_summary, file.path(out_dir, "feature_summary.csv"), row.names = FALSE)

  # 6. Create figures with ggplot2.
  site_plot <- ggplot2::ggplot(site_counts,
                              ggplot2::aes(x = site, y = subjects, fill = split)) +
    ggplot2::geom_col() +
    ggplot2::labs(title = "Subjects by study site",
                  x = "Site", y = "Number of subjects", fill = "Dataset") +
    ggplot2::theme_minimal()

  class_plot <- ggplot2::ggplot(class_balance,
                               ggplot2::aes(x = site, y = subjects, fill = diagnosis)) +
    ggplot2::geom_col(position = "dodge") +
    ggplot2::labs(title = "Known diagnoses in the labeled training set",
                  x = "Site", y = "Number of subjects", fill = "Diagnosis") +
    ggplot2::theme_minimal()

  age_plot <- ggplot2::ggplot(subjects,
                             ggplot2::aes(x = age, fill = split)) +
    ggplot2::geom_histogram(binwidth = 5, boundary = 0,
                            color = "white", na.rm = TRUE) +
    ggplot2::facet_wrap(~site) +
    ggplot2::labs(title = "Age distributions by study site",
                  x = "Age (years)", y = "Number of subjects", fill = "Dataset") +
    ggplot2::theme_minimal()

  # Sex codes are intentionally not translated to male/female without a key.
  sex_plot <- ggplot2::ggplot(sex_counts,
                             ggplot2::aes(x = site, y = subjects, fill = sex_code)) +
    ggplot2::geom_col() +
    ggplot2::labs(title = "Sex-code distributions by study site",
                  x = "Site", y = "Number of subjects", fill = "Sex code") +
    ggplot2::theme_minimal()

  ggplot2::ggsave(file.path(out_dir, "site_counts.png"),
                  site_plot, width = 7, height = 4, dpi = 300)
  ggplot2::ggsave(file.path(out_dir, "class_balance.png"),
                  class_plot, width = 7, height = 4, dpi = 300)
  ggplot2::ggsave(file.path(out_dir, "age_distribution.png"),
                  age_plot, width = 8, height = 4, dpi = 300)
  ggplot2::ggsave(file.path(out_dir, "sex_codes.png"),
                  sex_plot, width = 7, height = 4, dpi = 300)

  print(site_counts)
  print(class_balance)
  print(feature_summary)

  invisible(list(subjects = subjects,
                 site_counts = site_counts,
                 class_balance = class_balance,
                 age_summary = age_summary,
                 sex_counts = sex_counts,
                 feature_summary = feature_summary))
}
