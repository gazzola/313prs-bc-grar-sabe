cat("Loading packages...\n")
# Load Packages
suppressPackageStartupMessages({
  library(tidyverse)
  library(janitor)
  
  library(parallel)
  library(doMC)

  library(progress)

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

my_prs_data <- read_csv('input/prs_table_v2.csv') |>
  filter(sex == "F") |>
  filter(!is.na(age)) |>
  filter(cohort %in% c("SABE","GRAR","UKBB")) |>
  mutate(is_case = if_else(is_case == 'Case',1,0))

or_per_sd_boot <- function(data, indices) {
  my_prs_data_aux <- 
    data[indices,]
  
  my_model <-
    glm(data = my_prs_data_aux, formula = is_case ~ prs_sum,
        family = "binomial")
  
  exp(my_model$coefficients[2])
}


or_per_sd_list <- list()
or_per_sd_tbl <- tibble()
for (my_cohort_name in list(c('GRAR'),c('SABE'),c('SABE','GRAR'),c('UKBB'))) {
  string_name <- str_c(my_cohort_name, collapse = "_")
  print(string_name)
  
  my_cohort_data <-
    my_prs_data |>
    filter(cohort %in% my_cohort_name)
  
  or_per_sd_list[[string_name]] <-
      boot::boot(
        data = my_cohort_data,
        statistic = or_per_sd_boot,
        R = 1000,
        ncpus = 10,
        parallel = 'multicore',
        strata = my_cohort_data$is_case
      )

  my_ci <-
    boot::boot.ci(or_per_sd_list[[string_name]], type = 'perc')

  or_per_sd_tbl <- bind_rows(or_per_sd_tbl, tibble(
    cohort = string_name,
    or_per_sd = or_per_sd_list[[string_name]]$t0,
    lower_ci = my_ci$percent[4],
    upper_ci = my_ci$percent[5]
    ))
  
}


write_csv(or_per_sd_tbl, file = "or_per_sd_tbl.csv")
