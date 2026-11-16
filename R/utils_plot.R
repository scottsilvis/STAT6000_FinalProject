# R/utils_plot.R

# ==============================================================================
# Purpose:
#   Helper functions for saving figures and tables to results/ in a consistent
#   way.
# ==============================================================================

save_fig <- function(plot, filename, width = 6.5, height = 4.5, dpi = 600,
                     folder = here::here("results"), device = NULL) {
  if (!dir.exists(folder)) dir.create(folder, recursive = TRUE)

  out_path <- file.path(folder, filename)

  ggplot2::ggsave(
    filename = out_path,
    plot = plot,
    width = width,
    height = height,
    units = "in",
    dpi = dpi,
    device = device
  )

  message("Saved: ", out_path)
  invisible(out_path)
}

save_table <- function(data, filename, folder = here::here("results")) {
  if (!dir.exists(folder)) dir.create(folder, recursive = TRUE)

  out_path <- file.path(folder, filename)

  write.csv(data, out_path, row.names = FALSE)

  message("Saved: ", out_path)
  invisible(out_path)
}