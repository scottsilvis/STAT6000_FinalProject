# Load the instructor-provided study files
study <- read_study(
    file.path(data_dir, "ABIDEI_Final_Project.mat")
)

# Subset the study to the different sites for later analysis.
NYU = study$features[study$site_names == "NYU", ]
UM_1 = study$features[study$site_names == "UM_1", ]
USM = study$features[study$site_names == "USM", ]

demo <- read.csv(
    file.path(data_dir, "ABIDEI_three_sites_behavior.csv"), 
    stringsAsFactors = FALSE
)

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
