# R/02_eda.R

# ==============================================================================
# Purpose:
#   Exploratory data analysis (EDA) for the three-site ABIDE dataset. Run
#   01_load_data.R first. Tables are saved to results/ as CSVs and figures as
#   PNGs.
# ==============================================================================

library(ggplot2)
source(here::here("R", "utils_plot.R"))

# 1. Build one table with a row per subject ------------------------------------
# demo was already matched to subject_ids in 01_load_data.R.
subjects <- data.frame(
  subject_id = subject_ids,
  site       = demo$site,
  age        = demo$age,
  sex_code   = factor(demo$sex),
  split      = ifelse(training, "Training", "Test"),
  diagnosis  = ifelse(training,
                      ifelse(asd_diagnosis == 1, "ASD", "Control"),
                      NA)
)

# 2. Summary tables ------------------------------------------------------------
# Subjects per site, split by training/test
site_counts <- as.data.frame(table(
  site = subjects$site,
  split = subjects$split
))

names(site_counts)[3] <- "subjects"

# ASD vs control within the labeled training subjects
class_balance <- as.data.frame(table(
  site = subjects$site[training],
  diagnosis = subjects$diagnosis[training]
))

names(class_balance)[3] <- "subjects"

# Sex codes by site and split. We have not confirmed what 1 and 2 mean.
sex_counts <- as.data.frame(table(
  site = subjects$site,
  split = subjects$split,
  sex_code = subjects$sex_code
))

names(sex_counts)[4] <- "subjects"

# Age by site and split
age_summary <- aggregate(
  age ~ site + split,
  data = subjects,
  FUN = function(x) round(c(mean = mean(x),
                            median = median(x),
                            min = min(x),
                            max = max(x)),
                          2)
)
# aggregate() returns the four statistics as one matrix column; split them out
age_summary <- do.call(data.frame, age_summary)
names(age_summary) <- sub("^age\\.", "", names(age_summary))

# Size and completeness of the connectivity features
feature_summary <- data.frame(
  subjects = nrow(features),
  training = sum(training),
  test     = sum(!training),
  regions  = as.integer(study$n.roi),
  features = ncol(features),
  missing  = sum(!is.finite(features))
)

site_counts
class_balance
sex_counts
age_summary
feature_summary

# 3. Save tables ---------------------------------------------------------------
save_table(site_counts,     "site_counts.csv")
save_table(class_balance,   "class_balance.csv")
save_table(sex_counts,      "sex_counts.csv")
save_table(age_summary,     "age_summary.csv")
save_table(feature_summary, "feature_summary.csv")

# 4. Figures -------------------------------------------------------------------
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
                 color = "white") +
  facet_wrap(~site) +
  labs(title = "Age distributions by study site",
       x = "Age (years)", 
       y = "Number of subjects", 
       fill = "Dataset") +
  theme_minimal()

# Sex codes are left as 1 and 2 until we confirm the labels.
sex_plot <- ggplot(subjects, 
                   aes(x = site, 
                       fill = sex_code)) +
  geom_bar() +
  labs(title = "Sex-code distributions by study site",
       x = "Site", 
       y = "Number of subjects", 
       fill = "Sex code") +
  theme_minimal()

save_fig(site_plot,  "site_counts.png")
save_fig(class_plot, "class_balance.png")
save_fig(age_plot,   "age_distribution.png")
save_fig(sex_plot,   "sex_codes.png")
