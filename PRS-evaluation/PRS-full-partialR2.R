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

my_prs_data <- read_csv('input/prs_table.csv') |>
  filter(sex == "F") |>
  filter(!is.na(age)) |>
  filter(cohort %in% c("SABE","GRAR","UKBB")) |>
  mutate(is_case = if_else(is_case == 'Case',1,0))



partial_r_boot <- function(data, indices) {
  my_prs_data_aux <<- data[indices,]
  
  my_model_reduced <<-
    glm(data = my_prs_data_aux, formula = is_case ~  age + pc1 + pc2 + pc3 + pc4 + pc5, 
        family = "binomial")
  
  my_model_full <<-
    glm(data = my_prs_data_aux, formula = is_case ~ prs_sum + age + pc1 + pc2 + pc3 + pc4 + pc5, 
        family = "binomial")

  partial_r <- rsq::rsq.partial(
    objF = my_model_full, 
    objR = my_model_reduced, adj = TRUE)
  
  partial_r$partial.rsq
}


partial_r_list <- list()
partial_r_tbl <- tibble()
my_prs_data_aux <- tibble()
for (my_cohort_name in list(c('SABE'),c('GRAR'),c('SABE','GRAR'),c('UKBB'))) {
  string_name <- str_c(my_cohort_name, collapse = "_")
  print(string_name)
  
  my_cohort_data <-
    my_prs_data |>
    filter(cohort %in% my_cohort_name)
  
  partial_r_list[[string_name]] <-
      boot::boot(
        data = my_cohort_data,
        statistic = partial_r_boot,
        R = 1000,
        ncpus = 10,
        parallel = 'multicore',
        strata = my_cohort_data$is_case
      )
  
  my_ci <- 
    boot::boot.ci(partial_r_list[[string_name]], type = 'perc')
  
  partial_r_tbl <- bind_rows(partial_r_tbl, tibble(
    cohort = string_name,
    partial_r = partial_r_list[[string_name]]$t0,
    lower_ci = my_ci$percent[4],
    upper_ci = my_ci$percent[5]
    ))
  
}
write_csv(partial_r_tbl, file = "partial_r_list_tbl2.csv")