library(tidyverse)
library(hrbrthemes)
library(ggtext)
library(MASS)
library(ggnewscale)

theme_set(
  theme_minimal() +
  theme(
    plot.title.position = "plot",
    plot.margin = margin(25,25,25,25),
    axis.title.x = element_markdown(hjust = .5, size = 12),
    axis.title.y = element_markdown(hjust = .5, size = 12),
		legend.position = "top"
  )
)

my_data_pca <- 
  read_tsv('<PCA OUTPUT>.tsv') %>%
  mutate(scores = str_replace(scores, '^\\[','')) %>%
  mutate(scores = str_replace(scores, '\\]$','')) %>%
  separate(scores, sep = ',', into = c(str_c("pc",seq(1,10))), convert = TRUE) %>%
  rename(s = 's')

ids_1kgp3 <- 
  read_csv('input/popinfo3main.csv')

ids_sabe <-
  read_csv('input/ids_sabe.csv')

ids_grar <-
  read_tsv('input/grar.csv')

data2plot <-
  my_data_pca |>
  left_join(ids_1kgp3 |> rename(cohort = 'ancestry'), by = 's') |>
  mutate(cohort = if_else(s %in% ids_sabe$s, 'SABE', cohort)) |>
  mutate(cohort = if_else(s %in% ids_grar$s, 'GRAR', cohort))

get_density <- function(x, y, ...) {
  dens <- MASS::kde2d(x, y, ...)
  ix <- findInterval(x, dens$x)
  iy <- findInterval(y, dens$y)
  ii <- cbind(ix, iy)
  return(dens$z[ii])
}

for (my_cohort in c("GRAR","SABE")) {
  p <- data2plot |>
    na.omit() |>
    filter(cohort %in% my_cohort) |>
    mutate(density = scale(get_density(pc1,pc2))) |>
    ggplot(aes(x = pc1, y = pc2)) +
    geom_point(data = data2plot |> na.omit() |> filter(cohort %in% c("EUR","AFR","EAS")), aes(color = cohort), 
               size = .5) +
    scale_color_manual(values = list(AFR = "#D62728FF", EUR = "#FF7F0EFF", EAS = "#1F77B4FF")) +
    new_scale_color() +
    geom_point(size = 1, alpha = .9, aes(color = density)) +
    viridis::scale_color_viridis() +
    labs(x = 'PC1', y = 'PC2', color = NULL, title = str_c(my_cohort,' PCA'), subtitle = '1KGP3, SABE and GRAR') +
    theme(
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      panel.border = element_rect(fill = NA, colour = 'grey20')) +
    coord_fixed()
  
  ggsave(p, filename = str_c(my_cohort,'_pca.svg'), width = 4, height = 4)
}