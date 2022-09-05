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


calc_auc_boot <- function(data, indices) {
  my_prs_data <- data[indices,]
  
  my_model <-
    glm(data = my_prs_data, formula = is_case ~ prs_sum, 
        family = "binomial")
  
  my_roc <-
    pROC::roc(
      my_prs_data$is_case,
      my_prs_data$prs_sum,
      levels = c(0, 1),
      direction = "<"
      )
  
  my_roc$auc |> as.numeric()
}


roc_list <- list()
auc_boot_list <- list()
auc_boot_tbl <- tibble()
for (my_cohort_name in list(c('SABE'),c('GRAR'),c('SABE','GRAR'),c('UKBB'))) {
  string_name <- str_c(my_cohort_name, collapse = "_")
  print(string_name)
  
  my_cohort_data <-
    my_prs_data |>
    filter(cohort %in% my_cohort_name)
  
  my_model <-
    glm(data = my_cohort_data, formula = is_case ~ prs_sum, 
        family = "binomial")
  
  my_roc <-
    pROC::roc(
      my_cohort_data$is_case,
      my_cohort_data$prs_sum,
      levels = c(control = 0, case = 1),
      direction = "<")
  
  
  roc_list[[string_name]] <- my_roc
  
  auc_boot_list[[string_name]] <- 
    boot::boot(
      data = my_cohort_data,
      statistic = calc_auc_boot,
      R = 1000,
      ncpus = 10,
      parallel = 'multicore',
      strata = my_cohort_data$is_case
    )
  
  my_ci <-
    boot::boot.ci(auc_boot_list[[string_name]], type = 'perc') 
  
  auc_boot_tbl <- bind_rows(auc_boot_tbl,
    tibble(
      cohort = string_name,
      auc = auc_boot_list[[string_name]]$t0,
      ci_lower = my_ci$percent[4],
      ci_upper = my_ci$percent[5],
    ))
}

roc_tbl <- tibble()
for (string_name in names(roc_list)) {
  roc_tbl <- bind_rows(roc_tbl,
                       tibble(
                         sensitivities = roc_list[[string_name]]$sensitivities,
                         specificities = roc_list[[string_name]]$specificities,
                         cohort = string_name)
  )
}

roc_tbl |>
  ggplot(aes(x = 1 - specificities, y = sensitivities)) +
  geom_abline(intercept = 0, linetype = 2, alpha = .3) +
  geom_line(aes(color = cohort, group = cohort, linetype = cohort), size = .5) +
  scale_color_manual(
    values = 
      c(GRAR = "#3B4992", 
        SABE = "#A9B0D3",
        SABE_GRAR = "#3B4992",
        UKBB = "grey50")) +
  scale_linetype_manual(
    values = 
      c(GRAR = 'solid', 
        SABE = 'solid',
        SABE_GRAR = 'dotted',
        UKBB = 'solid')) +
  coord_fixed(expand = FALSE)
