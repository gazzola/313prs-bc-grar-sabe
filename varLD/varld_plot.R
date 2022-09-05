cat("Loading packages...\n")
# Load Packages
suppressPackageStartupMessages({
  library(tidyverse)
  library(janitor)
  library(parallel)
  library(doMC)
  library(webshot)
  library(cowplot)
  library(ggsci)
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

my_data <- read_tsv('<VAR_LD_OUTPUT>')

data2plot <-
  my_data |> 
  mutate(snp = str_replace(pop1,'(.*)_.*','\\1')) |>
  mutate(pop1 = str_replace(pop1, '.*_(.*)\\..*', '\\1')) |>
  mutate(pop2 = str_replace(pop2, '.*_(.*)\\..*', '\\1')) |>
  separate(col = snp, sep = '-', convert = TRUE, into = c('chr','start','end')) |>
  mutate(snp_pos = (start + end)/2) |>
  mutate(relative_pos = position - snp_pos)


data2plot |>
  ggplot(aes(x = relative_pos, y = raw_score, color = pop2, fill = pop2)) +
  geom_smooth(method = 'gam', span = 5) +
  ggsci::scale_color_locuszoom() +
  ggsci::scale_fill_locuszoom() +
  scale_x_continuous(labels = ~ (.x / 1000) ) +
  labs(y = 'Raw Score', x = 'Relative Pos (kb)') +
  coord_cartesian(expand = FALSE)