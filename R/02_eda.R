# Exploratory Data Analysis (EDA) for the three-site ABIDE dataset.
# Figures use ggplot2. 


# 1. Check for duplicate subject IDs
duplicate_ids <- unique(subject_ids[duplicated(subject_ids)])

if (length(duplicate_ids) > 0) {
  stop(
    "Duplicate subject IDs found in study: ",
    paste(duplicate_ids, collapse = ", ")
  )
}

# 2. Check for duplicate IDs in demographics
duplicate_demo_ids <- unique(demo$subject_id[duplicated(demo$subject_id)])

if (length(duplicate_demo_ids) > 0) {
  stop(
    "Duplicate subject IDs found in demographics: ",
    paste(duplicate_demo_ids, collapse = ", ")
  )
}
  
# Remove the temp id variables after they pass the checkpoints
remove(duplicate_ids, duplicate_demo_ids)

# 3. Summarize the sample size, sites and known diagnoses.
site_counts <- as.data.frame(
  table(
    site = site,
    training = training
  )
)

# Count ASD and control subjects at each site
class_balance <- as.data.frame(
  table(
    site = site[training],
    diagnosis = asd_diagnosis[training]
  )
)

names(class_balance)[3] <- "subjects"

print(class_balance)


# Count sex within ASD and control subjects at each site and split
sex_counts <- as.data.frame(
  table(
    site = site,
    training = training,
    sex_code = demo$sex,
    useNA = "ifany"
  )
)

names(sex_counts)[4] <- "subjects"

sex_counts <- sex_counts[sex_counts$subjects > 0, ]

print(sex_counts)

# Age is described separately by site and known/hidden split.
age_summary <- aggregate(
  demo$age,
  by = list(site = demo$site),
  FUN = function(age) c(
    mean = mean(age, na.rm = TRUE),
    median = median(age, na.rm = TRUE),
    min = min(age, na.rm = TRUE),
    max = max(age, na.rm = TRUE)
  )
)

print(age_summary)

# 4. Describe feature dimensionality and data completeness.

feature_summary <- data.frame(
  subjects = length(subject_ids),
  labeled = sum(training),
  hidden = sum(!training),
  regions = as.integer(study$n.roi),
  features = nrow(study$FC.edges),
  missing = sum(!is.finite(study$FC.edges))
)

print(feature_summary)

# 5. Save report-ready tables.
write.csv(site_counts, file.path("results/dataset_summary.csv"), row.names = FALSE)
write.csv(class_balance, file.path("results/class_balance.csv"), row.names = FALSE)
write.csv(age_summary, file.path("results/age_summary.csv"), row.names = FALSE)
write.csv(sex_counts, file.path("results/sex_counts.csv"), row.names = FALSE)
write.csv(feature_summary, file.path("results/feature_summary.csv"), row.names = FALSE)

# 6. Create figures with ggplot2.
library(ggplot2)
site_plot <- ggplot(site_counts, 
                    aes(x = site, 
                        y = subjects, 
                        fill = split)) +
  geom_col() +
  labs(title = "Subjects by study site",
       x = "Site", 
       y = "Number of subjects", 
       fill = "Dataset") +
  theme_minimal()

class_plot <- ggplot(class_balance,
                     aes(x = site, 
                         y = subjects, 
                         fill = diagnosis)) +
  geom_col(position = "dodge") +
  labs(title = "Known diagnoses in the labeled training set",
       x = "Site", 
       y = "Number of subjects", 
       fill = "Diagnosis") +
  theme_minimal()

age_plot <- ggplot(subjects,
                   aes(x = age, 
                       fill = split)) +
  geom_histogram(binwidth = 5, 
                 boundary = 0,
                 color = "white", 
                 na.rm = TRUE) +
  facet_wrap(~site) +
  labs(title = "Age distributions by study site",
       x = "Age (years)", 
       y = "Number of subjects", 
       fill = "Dataset") +
  theme_minimal()

# Do we know how male and female are coded? I assume 1 = male 2 = female but I 
# dont want to code that into the figures until we confirm that. 
sex_plot <- ggplot(sex_counts,
                   aes(x = site, 
                       y = subjects, 
                       fill = sex_code)) +
  geom_col() +
  labs(title = "Sex-code distributions by study site",
       x = "Site", 
       y = "Number of subjects", 
       fill = "Sex code") +
  theme_minimal()

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

