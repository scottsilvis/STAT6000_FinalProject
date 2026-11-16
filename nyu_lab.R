# Classroom-style example: NYU-only model comparison.
# Run from the repository root: Rscript nyu_lab.R

source("R/project_files.R")
source("R/metrics.R")
source("R/01_load_date.R")
source("R/03_validation.R")
source("R/04_logistic-regression.R")
source("R/04_pca.R")
source("R/05_compare.R")

# Import the NYU training subjects.
project <- load_project_data("data", "NYU")
training <- project$training
print(table(diagnosis = training$diagnosis))

# Compare all models on the same five held-out folds.
folds <- make_validation_folds(training, seed = 6000, number_of_folds = 5)
models <- c(
  list("Logistic regression" = make_logistic_workflow(training)),
  make_pca_workflows(training, components = 10, neighbors = 7)
)

# Calculate the same metrics used by the main project.
compare_models(models, folds, output_dir = "results-r/NYU")
