cat("Loading packages...\n")
# Load Packages
suppressPackageStartupMessages({
  library(tidyverse)
  library(tidymodels)
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
})

# webshot::install_phantomjs() # for printing gt Tables

theme_set(
  theme_minimal() +
    theme(
      plot.title.position = "plot",
      plot.margin = margin(25,25,25,25),
      plot.title = element_text(),
      axis.title.x = element_text(hjust = .5, size = 12),
      axis.title.y = element_text(hjust = .5, size = 12),
      plot.subtitle = element_text(color = "grey60"),
      legend.position = "top"
    )
)

options(readr.show_col_types = FALSE)

my_data <- read_csv('input/prs_table_v2.csv') |>
  filter(sex == "F") |>
  filter(!is.na(age)) |>
  filter(cohort %in% c("SABE","GRAR","UKBB"))

my_data <- bind_rows(my_data,
  my_data |> 
    filter(cohort %in% c("SABE","GRAR")) |>
    mutate(cohort = "G+S"))

my_data_w_quantile <-
  my_data |>
  group_by(cohort) |>
  mutate(quantile = cut(prs_sum, quantile(prs_sum, seq(0,1, by = .1)), labels = str_c("Q",seq(1,10,by = 1)))) |>
  mutate(quantile_percent = case_when(
    quantile %in% c("Q1","Q2") ~ "0-20",
    quantile %in% c("Q3","Q4") ~ "20-40",
    quantile %in% c("Q5","Q6") ~ "40-60",
    quantile %in% c("Q7","Q8") ~ "60-80",
    quantile %in% c("Q9","Q10") ~ "80-100",
  )) |>
  ungroup() |>
  count(quantile_percent, cohort, is_case)

my_data_w_quantile_not_exposed <-
  my_data_w_quantile |> filter(quantile_percent == "40-60") |>
  pivot_wider(names_from = "is_case", values_from = "n") |>
  mutate(exposed = 'not_exposed')

my_data_w_quantile_exposed <-
  my_data_w_quantile |>
  pivot_wider(names_from = "is_case", values_from = "n") |>
  mutate(exposed = 'exposed') |> na.omit()

odds_ratio <- tibble()

for (quantile_x in unique(my_data_w_quantile_exposed$quantile_percent)) {
  for (my_cohort in unique(my_data_w_quantile_exposed$cohort)) {
    x <-
      rbind(
        my_data_w_quantile_exposed |> filter(quantile_percent == quantile_x),
        my_data_w_quantile_not_exposed
      ) |>
      filter(cohort ==  my_cohort)  |>
      pivot_longer(names_to = "is_case", values_to = "n", cols = c('Case','Control')) |>
      select(-quantile_percent) |>
      pivot_wider(names_from = c("is_case", "exposed"), values_from = n)
    
    odds_ratio <- bind_rows(
      odds_ratio,
      tibble(
        quantile = quantile_x,
        cohort = my_cohort,
        odds_ratio = (x$Case_exposed * x$Control_not_exposed) / (x$Case_not_exposed * x$Control_exposed)
      )
    )
  }
}


odds_ratio <- odds_ratio |>
  mutate(quantile = factor(quantile, levels = c('0-20','20-40','40-60','60-80','80-100')))

odds_ratio |>
  ggplot(aes(x = quantile, y = odds_ratio, color = cohort)) +
  geom_hline(yintercept = 1, color = 'grey20') +
  geom_line(show.legend = FALSE, aes(group = cohort)) +
  geom_point(show.legend = FALSE) +
  gghighlight::gghighlight(use_direct_label = FALSE, unhighlighted_params = list(size = .6, alpha = .2)) +
  facet_wrap(~cohort, ncol = 4, scales = 'free') +
  theme(panel.grid.major.x  = element_blank(), panel.grid.minor  = element_blank(), panel.border = element_rect(color = 'grey80', fill = NA)) +
  labs(x = 'PRS quantiles (%)', y = 'Odds Ratio') +
  scale_color_d3() 

# Bootstrap
my_data_w_quantile

a <-  my_data_w_quantile_exposed |>
  filter(cohort == my_cohort) |>
  filter(quantile_percent == quantile_x)

b <- my_data_w_quantile_not_exposed |>
  filter(cohort == my_cohort)


get_or_boot_percentile <- function(data, indices, quantile_x, my_cohort){
  
  my_data <- data[indices,]

  my_data_w_quantile <-
    my_data |>
    mutate(quantile = cut(prs_sum, quantile(prs_sum, seq(0,1, by = .1)), labels = str_c("Q",seq(1,10,by = 1)))) |>
    mutate(quantile_percent = case_when(
      quantile %in% c("Q1","Q2") ~ "0-20",
      quantile %in% c("Q3","Q4") ~ "20-40",
      quantile %in% c("Q5","Q6") ~ "40-60",
      quantile %in% c("Q7","Q8") ~ "60-80",
      quantile %in% c("Q9","Q10") ~ "80-100",
    )) |>
    count(quantile_percent, cohort, is_case)
  
  my_data_w_quantile_not_exposed <-
    my_data_w_quantile |> filter(quantile_percent == "40-60") |>
    pivot_wider(names_from = "is_case", values_from = "n") |>
    mutate(exposed = 'not_exposed')
  
  my_data_w_quantile_exposed <-
    my_data_w_quantile |>
    pivot_wider(names_from = "is_case", values_from = "n") |>
    mutate(exposed = 'exposed') |>
    filter(!is.na(quantile_percent)) %>%
    replace(is.na(.), 0)
  
  x <-
    bind_rows(
      my_data_w_quantile_exposed |> filter(quantile_percent == quantile_x),
      my_data_w_quantile_not_exposed
    ) |>
    filter(cohort ==  my_cohort)  |>
    pivot_longer(names_to = "is_case", values_to = "n", cols = c('Case','Control')) |>
    select(-quantile_percent) |>
    pivot_wider(names_from = c("is_case", "exposed"), values_from = n)
  
  odds_ratio <- 
    (x$Case_exposed * x$Control_not_exposed) / (x$Case_not_exposed * x$Control_exposed)

  odds_ratio
}

odds_ratio <- tibble()
for (quantile_x in unique(my_data_w_quantile_exposed$quantile_percent)) {
  for (my_cohort in unique(my_data_w_quantile_exposed$cohort)) {
    print(str_c(my_cohort, " ", quantile_x))
    data2boot <- my_data |> filter(cohort == my_cohort)
    
    data2boot <- data2boot |>
      mutate(strata = if_else(is_case == "Case", 1, 0))
    
    if (quantile_x != '40-60') {
      my_boot <- 
        boot::boot(
          data = data2boot,
          statistic = get_or_boot_percentile, 
          R = 1000, 
          quantile_x = quantile_x,
          my_cohort = my_cohort,
          strata = data2boot$strata,
          parallel = "multicore",
          ncpus = 16)
    
   
      ci <- boot::boot.ci(my_boot, type = "perc")
    } else {
      my_boot <- list(t0 = 1)
      ci <- list(percent = c(1,1,1,1,1))
    }
    
    odds_ratio <- bind_rows(
      odds_ratio,
      tibble(
        quantile = quantile_x,
        cohort = my_cohort,
        odds_ratio = my_boot$t0,
        ci_lower = ci$percent[4],
        ci_higher = ci$percent[5]
      )
    )
  }
}
odds_ratio <- odds_ratio |>
  mutate(quantile = factor(quantile, levels = c('0-20','20-40','40-60','60-80','80-100')))

write_csv(odds_ratio, "odds_ratio_table.csv")

p <-
  read_csv("odds_ratio_table.csv") |>
  ggplot(aes(x = quantile, y = odds_ratio)) +
  geom_hline(yintercept = 1, color = 'grey20') +
  geom_line(show.legend = FALSE, aes(group = cohort), color = "#3B4992") +
  geom_point(show.legend = FALSE,  color = "#3B4992") +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_higher), width = .4,  color = "#3B4992") +
  facet_wrap(~cohort, ncol = 4) +
  theme(axis.ticks = element_line(color = 'grey20')) +
  theme(panel.grid.major.x  = element_blank(), panel.grid.minor  = element_blank(), panel.border = element_rect(color = 'grey20', fill = NA)) +
  labs(x = 'PRS quantiles (%)', y = 'Odds Ratio')

ggsave(p, filename = 'or.pdf', width = 10.1, height = 2.6)

