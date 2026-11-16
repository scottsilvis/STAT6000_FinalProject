# R/01_load_data.R

# ==============================================================================
# Purpose:
#   Load the ABIDE connectivity data (.mat) and demographics (.csv), then split
#   subjects into training and test sets.
# ==============================================================================

library(R.matlab)

# 1. Load connectivity data ----------------------------------------------------
# Based on the provided import instructions
study <- readMat(here::here("data", "ABIDEI_Final_Project.mat"))

# The dataset doesn't import in the correct orientation, so we transpose it.
features <- t(study$FC.edges)

subject_ids <- as.vector(unlist(study$subject.id))
site <- as.vector(unlist(study$site))
training <- as.logical(as.vector(study$is.train))

# Labels are known for training subjects only. Test subjects are coded as -1.
asd_diagnosis <- as.vector(study$label.ASD.train.only)

# 2. Split into training and test sets -----------------------------------------
# Fit preprocessing and models using training subjects only.
# Use test_ids in the same order when submitting predictions.
training_feat <- features[training, , drop = FALSE]
training_diag <- asd_diagnosis[training]
training_ids <- subject_ids[training]

test_feat <- features[!training, , drop = FALSE]
test_ids <- subject_ids[!training]

# 3. Load demographics ---------------------------------------------------------
demo <- read.csv(
  here::here("data", "ABIDEI_three_sites_behavior.csv"),
  colClasses = c(subject_id = "character")
)

# Check for duplicate IDs before matching, since match() would hide them.
if (anyDuplicated(subject_ids) > 0) {
  stop("Duplicate subject IDs found in study.")
}
if (anyDuplicated(demo$subject_id) > 0) {
  stop("Duplicate subject IDs found in demographics.")
}

# Match demographics to the .mat file by ID instead of assuming the same order.
demo <- demo[match(subject_ids, demo$subject_id), ]

# 4. Check the loaded data -----------------------------------------------------
stopifnot(
  nrow(features) == length(subject_ids),
  ncol(features) == 19900,
  nrow(training_feat) == 269,
  nrow(test_feat) == 117,
  all(training_diag %in% 0:1),
  !anyNA(demo$subject_id),
  all(demo$site == site)
)
