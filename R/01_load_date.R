# Load the instructor-provided study files and choose the analysis cohort.
load_project_data <- function(data_dir, selected_site = "ALL") {
  study <- read_study(file.path(data_dir, "ABIDEI_Final_Project.mat"))
  selected <- selected_site == "ALL" | study$site_names == selected_site
  labeled <- selected & study$is_train == 1
  hidden <- selected & study$is_train == 0

  edge_names <- paste0("edge_", seq_len(ncol(study$features)))
  training <- as.data.frame(study$features[labeled, , drop = FALSE])
  test <- as.data.frame(study$features[hidden, , drop = FALSE])
  names(training) <- edge_names
  names(test) <- edge_names

  # Probability columns correspond to the ASD class ("asd").
  training$diagnosis <- factor(ifelse(study$labels[labeled] == 1, "asd", "control"),
                               levels = c("control", "asd"))

  list(study = study, selected = selected, labeled = labeled, hidden = hidden,
       training = training, test = test,
       test_ids = study$subject_ids[hidden])
}
