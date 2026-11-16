library(R.matlab)

# Based on the provided import instructions
study <- readMat("data/ABIDEI_Final_Project.mat")

# The dataset doesn't import in the correct orientation, so we transpose it. 
features <- t(study$FC.edges)
asd_diagnosis <- as.vector(study$label.ASD.train.only)
training <- as.logical(as.vector(study$is.train))

subject_ids <- unlist(study$subject.id)
training_feat <- features[training, , drop = FALSE]
training_diag <- asd_diagnosis[training]
training_ids <- subject_ids[training]
test_feat <- features[!training, , drop = FALSE]
test_ids <- subject_ids[!training]

# dim(X_train)  # 269 x 19900 - Correct
# dim(X_test)   # 117 x 19900 - Correct
# table(y_train) # correct
# Fit preprocessing and models using training subjects only.
# Use test_ids in the same order when submitting predictions.

demo <- read.csv(
  "data/ABIDEI_three_sites_behavior.csv",
  colClasses = c(subject_id = "character")
)

site <- unlist(study$site)