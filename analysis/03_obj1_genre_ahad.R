# Objective 1 — Genre-level track popularity analysis
# Run from the repository root:
#   Rscript analysis/03_obj1_genre_ahad.R
# Required input: data/obj1_genre_popularity.csv
# Required package: sandwich

# ----------------------------- Setup ----------------------------------------

data_file <- file.path("data", "obj1_genre_popularity.csv")
output_dir <- "outputs"

if (!file.exists(data_file)) {
  stop(
    "Dataset not found at ", data_file,
    ". Place the dataset in the data/ folder or update data_file."
  )
}

if (!requireNamespace("sandwich", quietly = TRUE)) {
  stop(
    "Package 'sandwich' is required. Install it with install.packages('sandwich')."
  )
}

dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

genre_data <- read.csv(data_file, stringsAsFactors = FALSE)
required_columns <- c("track_id", "track_genre", "popularity")
missing_columns <- setdiff(required_columns, names(genre_data))
if (length(missing_columns) > 0) {
  stop("Missing required columns: ", paste(missing_columns, collapse = ", "))
}

if (anyNA(genre_data[required_columns])) {
  stop("Missing values found in track_id, track_genre or popularity. Review the data before modelling.")
}

if (!is.numeric(genre_data$popularity)) {
  stop("The popularity column must be numeric.")
}

if (anyDuplicated(genre_data[c("track_id", "track_genre")]) > 0) {
  stop("Duplicate track_id + track_genre pairs found. Review duplicate rows before analysis.")
}

cat("Rows:", nrow(genre_data), "\n")
cat("Unique track IDs:", length(unique(genre_data$track_id)), "\n")
cat("Unique genres:", length(unique(genre_data$track_genre)), "\n")

# ---------------------- Descriptive statistics -----------------------------

popularity_by_genre <- split(
  genre_data$popularity,
  genre_data$track_genre
)

genre_summary <- data.frame(
  genre = names(popularity_by_genre),
  n = vapply(popularity_by_genre, length, integer(1)),
  mean = vapply(popularity_by_genre, mean, numeric(1)),
  median = vapply(popularity_by_genre, median, numeric(1)),
  sd = vapply(popularity_by_genre, sd, numeric(1)),
  q1 = vapply(
    popularity_by_genre,
    function(x) unname(quantile(x, 0.25)),
    numeric(1)
  ),
  q3 = vapply(
    popularity_by_genre,
    function(x) unname(quantile(x, 0.75)),
    numeric(1)
  ),
  row.names = NULL
)

genre_summary <- genre_summary[order(genre_summary$mean, decreasing = TRUE), ]
write.csv(
  genre_summary,
  file.path(output_dir, "obj1_genre_summary.csv"),
  row.names = FALSE
)

# Track IDs can occur under multiple genre labels. These counts make that
# structure explicit and motivate clustering the model covariance by track_id.
track_memberships <- table(genre_data$track_id)
track_structure <- data.frame(
  track_genre_rows = nrow(genre_data),
  unique_tracks = length(track_memberships),
  tracks_in_multiple_genres = sum(track_memberships > 1),
  percent_tracks_in_multiple_genres = 100 * mean(track_memberships > 1),
  maximum_genres_per_track = max(track_memberships)
)
write.csv(
  track_structure,
  file.path(output_dir, "obj1_track_structure.csv"),
  row.names = FALSE
)

# ----------------------------- Visualisation -------------------------------

# Top and bottom ten mean popularity scores.
genre_plot_data <- rbind(head(genre_summary, 10), tail(genre_summary, 10))
genre_plot_data <- genre_plot_data[order(genre_plot_data$mean), ]
genre_plot_data$group <- ifelse(
  genre_plot_data$genre %in% head(genre_summary$genre, 10),
  "Top 10",
  "Bottom 10"
)
plot_colours <- ifelse(genre_plot_data$group == "Top 10", "steelblue", "darkorange")

draw_genre_means <- function() {
  old_par <- par(no.readonly = TRUE)
  on.exit(par(old_par))
  par(mar = c(5, 10, 4, 2))
  barplot(
    height = genre_plot_data$mean,
    names.arg = genre_plot_data$genre,
    horiz = TRUE,
    las = 1,
    col = plot_colours,
    border = NA,
    xlim = c(0, max(70, ceiling(max(genre_plot_data$mean) / 10) * 10)),
    xlab = "Mean popularity score",
    main = "Top and bottom 10 genres by mean popularity",
    cex.names = 0.8
  )
  legend(
    "bottomright",
    legend = c("Top 10", "Bottom 10"),
    fill = c("steelblue", "darkorange"),
    bty = "n"
  )
}

png(
  file.path(output_dir, "obj1_top_bottom_genres.png"),
  width = 2400, height = 1800, res = 200
)
draw_genre_means()
dev.off()

# Popularity distributions for the five highest- and five lowest-mean genres.
selected_genres <- c(head(genre_summary$genre, 5), tail(genre_summary$genre, 5))
boxplot_data <- popularity_by_genre[selected_genres]

draw_genre_boxplots <- function() {
  old_par <- par(no.readonly = TRUE)
  on.exit(par(old_par))
  par(mar = c(5, 10, 4, 2))
  boxplot(
    boxplot_data,
    horizontal = TRUE,
    las = 1,
    col = c(rep("steelblue", 5), rep("darkorange", 5)),
    xlim = c(0, 100),
    xlab = "Popularity score",
    main = "Popularity distributions in selected genres",
    cex.axis = 0.8,
    outline = TRUE
  )
}

png(
  file.path(output_dir, "obj1_selected_genre_boxplots.png"),
  width = 2400, height = 1800, res = 200
)
draw_genre_boxplots()
dev.off()

# Q-Q plots are exploratory diagnostics of raw popularity distributions.
qq_genres <- c("pop-film", "k-pop", "pop", "latin")
missing_qq_genres <- setdiff(qq_genres, names(popularity_by_genre))
if (length(missing_qq_genres) > 0) {
  stop("Q-Q plot genres not present in data: ", paste(missing_qq_genres, collapse = ", "))
}

draw_genre_qq <- function() {
  old_par <- par(no.readonly = TRUE)
  on.exit(par(old_par))
  par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))
  for (genre in qq_genres) {
    scores <- popularity_by_genre[[genre]]
    qqnorm(
      scores,
      main = paste("Q-Q plot:", genre),
      pch = 16,
      cex = 0.4,
      col = "steelblue"
    )
    qqline(scores, col = "red", lwd = 2)
  }
}

png(
  file.path(output_dir, "obj1_genre_qq_plots.png"),
  width = 2400, height = 2000, res = 200
)
draw_genre_qq()
dev.off()

# ------------------------- Linear model -------------------------------------

genre_data$track_genre <- factor(genre_data$track_genre)
genre_model <- lm(popularity ~ track_genre, data = genre_data)
genre_model_r2 <- summary(genre_model)$r.squared

# Cluster the covariance by track ID because the same ID can occur in
# multiple track-genre rows.
genre_cluster_vcov <- sandwich::vcovCL(
  genre_model,
  cluster = genre_data$track_id,
  type = "HC1"
)

genre_levels <- levels(genre_data$track_genre)
genre_coef <- coef(genre_model)[-1]
genre_cov <- genre_cluster_vcov[
  names(genre_coef), names(genre_coef), drop = FALSE
]

if (qr(genre_cov)$rank != length(genre_coef)) {
  stop("Clustered covariance matrix is not full rank; inspect the model and data.")
}

# Report p-values without showing numerical underflow as an exact zero.
# The log p-value is retained as the high-precision representation; the
# ordinary numeric probability can underflow for extremely small values.
format_p_from_log <- function(log_p_values, digits = 3, cutoff = 0.001) {
  result <- rep(paste0("< ", format(cutoff, scientific = FALSE)), length(log_p_values))
  visible <- !is.na(log_p_values) & log_p_values >= log(cutoff)
  if (any(visible)) {
    result[visible] <- formatC(
      exp(log_p_values[visible]),
      format = "g",
      digits = digits
    )
  }
  result[is.na(log_p_values)] <- NA_character_
  result
}

wald_statistic <- as.numeric(
  crossprod(genre_coef, solve(genre_cov, genre_coef))
)
wald_df <- length(genre_coef)
wald_log_p <- pchisq(
  wald_statistic,
  df = wald_df,
  lower.tail = FALSE,
  log.p = TRUE
)
wald_log10_p <- wald_log_p / log(10)
wald_p_numeric <- exp(wald_log_p)
wald_p_report <- format_p_from_log(wald_log_p)

wald_test_output <- data.frame(
  test = "Wald test clustered by track_id",
  statistic = wald_statistic,
  df = wald_df,
  p_value = wald_p_report,
  p_value_numeric = wald_p_numeric,
  log10_p_value = wald_log10_p,
  r_squared = genre_model_r2,
  unique_tracks = length(unique(genre_data$track_id))
)
write.csv(
  wald_test_output,
  file.path(output_dir, "obj1_overall_genre_test.csv"),
  row.names = FALSE
)

# --------------------- Pairwise genre comparisons ---------------------------
# Exact log probabilities are used for inference and Holm adjustment.
# CSV p_value / p_holm columns are human-readable strings; numeric probability
# columns are included for convenience and may underflow to zero at extremes.

genre_design <- model.matrix(
  ~ track_genre,
  data = data.frame(track_genre = factor(genre_levels, levels = genre_levels)),
  contrasts.arg = genre_model$contrasts
)

genre_means <- as.vector(genre_design %*% coef(genre_model))
genre_mean_cov <- genre_design %*% genre_cluster_vcov %*% t(genre_design)
genre_pairs <- combn(seq_along(genre_levels), 2)

pairwise_rows <- lapply(seq_len(ncol(genre_pairs)), function(k) {
  i <- genre_pairs[1, k]
  j <- genre_pairs[2, k]
  difference <- genre_means[i] - genre_means[j]
  se <- sqrt(
    genre_mean_cov[i, i] + genre_mean_cov[j, j] -
      2 * genre_mean_cov[i, j]
  )
  if (!is.finite(se) || se <= 0) {
    stop("Non-positive or non-finite clustered standard error in pairwise comparison.")
  }
  z_value <- difference / se
  log_p <- log(2) + pnorm(abs(z_value), lower.tail = FALSE, log.p = TRUE)
  data.frame(
    genre_1 = genre_levels[i],
    genre_2 = genre_levels[j],
    mean_difference = difference,
    clustered_se = se,
    z = z_value,
    log_p_value = log_p,
    p_value_numeric = exp(log_p)
  )
})

genre_pairwise <- do.call(rbind, pairwise_rows)

# Holm adjustment performed on log p-values to retain values smaller than
# the machine's smallest representable positive double.
holm_adjust_log <- function(log_p_values) {
  m <- length(log_p_values)
  order_index <- order(log_p_values)
  ordered_adjusted <- log_p_values[order_index] + log(m - seq_len(m) + 1)
  ordered_adjusted <- pmin(0, cummax(ordered_adjusted))
  adjusted <- numeric(m)
  adjusted[order_index] <- ordered_adjusted
  adjusted
}

genre_pairwise$log_p_holm <- holm_adjust_log(genre_pairwise$log_p_value)
genre_pairwise$p_holm_numeric <- exp(genre_pairwise$log_p_holm)

# The exported p_value and p_holm fields are report-friendly strings.
# Numeric probability columns are retained separately; they can underflow
# to zero, while the corresponding log columns retain the probability.
genre_pairwise$p_value <- format_p_from_log(genre_pairwise$log_p_value)
genre_pairwise$p_holm <- format_p_from_log(genre_pairwise$log_p_holm)

# Bonferroni simultaneous 95% confidence intervals for all pairwise contrasts.
number_of_comparisons <- nrow(genre_pairwise)
critical_value <- qnorm(1 - 0.05 / (2 * number_of_comparisons))
genre_pairwise$ci_low_bonferroni <-
  genre_pairwise$mean_difference - critical_value * genre_pairwise$clustered_se
genre_pairwise$ci_high_bonferroni <-
  genre_pairwise$mean_difference + critical_value * genre_pairwise$clustered_se

genre_pairwise <- genre_pairwise[
  order(abs(genre_pairwise$mean_difference), decreasing = TRUE),
]
write.csv(
  genre_pairwise,
  file.path(output_dir, "obj1_pairwise_genre_comparisons.csv"),
  row.names = FALSE
)

# Export the ten largest absolute estimated differences for easier review.
comparison_columns <- c(
  "genre_1", "genre_2", "mean_difference",
  "ci_low_bonferroni", "ci_high_bonferroni",
  "p_value", "p_holm", "log_p_value", "log_p_holm"
)
write.csv(
  head(genre_pairwise[comparison_columns], 10),
  file.path(output_dir, "obj1_largest_genre_differences.csv"),
  row.names = FALSE
)

# --------------------------- Key results ------------------------------------

objective1_summary <- data.frame(
  track_genre_rows = nrow(genre_data),
  unique_tracks = length(unique(genre_data$track_id)),
  genres = length(genre_levels),
  wald_statistic = wald_statistic,
  wald_df = wald_df,
  wald_p_value = wald_p_report,
  wald_log10_p_value = wald_log10_p,
  r_squared = genre_model_r2,
  total_pairwise_comparisons = nrow(genre_pairwise),
  holm_significant_pairs = sum(genre_pairwise$log_p_holm <= log(0.05)),
  highest_mean_genre = genre_summary$genre[1],
  highest_mean = genre_summary$mean[1],
  lowest_mean_genre = tail(genre_summary$genre, 1),
  lowest_mean = tail(genre_summary$mean, 1)
)

write.csv(
  objective1_summary,
  file.path(output_dir, "obj1_key_results.csv"),
  row.names = FALSE
)

cat("\nKey results\n")
print(objective1_summary)
cat("\nAnalysis complete. Outputs written to:", output_dir, "\n")
