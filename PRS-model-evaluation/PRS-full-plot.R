cat("Loading packages...\n")
# Load Packages
suppressPackageStartupMessages({
  library(tidyverse)
  library(janitor)

  library(parallel)
  library(doMC)
  
  library(vip)
  
  library(progress)
  
  library(gt)
  library(gtExtras)
  library(webshot)
  library(cowplot)
  library(ggsci)
  library(pROC)
  library(ggtext)
})

theme_set(
  theme_minimal() +
    theme(
      plot.title.position = "plot",
      plot.margin = margin(25,25,25,25),
      axis.title.x = element_markdown(hjust = .5, size = 12),
      axis.title.y = element_markdown(hjust = .5, size = 12),
      legend.position = "top",
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      panel.border = element_rect(fill = NA, colour = 'black')
    )
)

options(readr.show_col_types = FALSE)

data2plot <-
  bind_rows(read_csv('partial_r_tbl.csv') |>
    mutate(y = partial_r, statistic = 'Partial R2') |>
    select(-partial_r),
    read_csv('roc_tbl.csv') |>
    mutate(y = or_per_sd, statistic = 'ROC') |>
    select(-or_per_sd),
    read_csv('or_per_sd_tbl.csv') |>
    mutate(y = or_per_sd, statistic = 'OR per SD') |>
    select(-or_per_sd))

data2plot |>
  ggplot(aes(x = cohort, y = y)) +
  geom_col(fill = '#3B4992') +
  facet_wrap(~statistic, scales = 'free_y') +
  geom_errorbar(aes(ymin = lower_ci, ymax = upper_ci), width = .5) +
  scale_y_continuous(expand = c(0,0,.1,0))
