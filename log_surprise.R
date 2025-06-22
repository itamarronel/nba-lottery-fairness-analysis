# ============================================================================
#  NBA LOTTERY ANALYSIS: IS THE LOTTERY FAIR?
#  Statistical tests for Deviance (1990-2025)
# ============================================================================

#--------------------------------------------------------------------------------
#### Script 1: Simulated Log Score Distribution vs. Observed ####
#--------------------------------------------------------------------------------

library(readr)     # read_csv()
library(dplyr)
library(ggplot2)
library(ggdist)
library(car)       # linearHypothesis()

setwd("/Users/itamar/Desktop/untitled_folder")
data_file <- "lottery_sim_results.csv"   # או נתיב מלא אם צריך
lottery_data <- read_csv(data_file, show_col_types = FALSE)

lot <- lottery_data %>%
  mutate(
    Year         = as.numeric(Year),
    Chances  = as.numeric(Chances),
    Prob1        = as.numeric(gsub("%", "", Odds)) / 100,   # Probability of 1st pick
    ProbTopPick  = as.numeric(SimLotteryProb),              # Probability of any lottery win
    WonFirstPick   = as.numeric(WonFirstPick),                # Binary: won 1st pick (0/1)
    TopPick      = as.numeric(WonLotteryPick)               # Binary: won any lottery pick (0/1)
  )


#--------------------------------------------------------------------------------
####  Calculate Log scores for First Pick    ####
#--------------------------------------------------------------------------------

# 1) Extract probability vectors P(#1) for each year
prob_list <- lot %>% 
  group_by(Year) %>% 
  summarise(prob_vec = list(Prob1), .groups = "drop") %>% 
  pull(prob_vec)

# 2) Find actual winner index for each year
winner_idx <- lot %>% 
  group_by(Year) %>% 
  summarise(winner = which(WonFirstPick == 1), .groups = "drop") %>% 
  pull(winner)

# 3) Calculate observed deviance statistic
loglik_obs <- function(p_vecs, idx) {
  sum(mapply(function(p, w) log(p[w]), p_vecs, idx))
}

D_obs <- -1 * loglik_obs(prob_list, winner_idx)
D_obs

# Which years contributed most to the deviance?
contr <- mapply(function(p,w) -1*log(p[w]), prob_list, winner_idx)
data.frame(Year = unique(lottery_data$Year), contrib = contr) %>%
  arrange(desc(contrib))

#--------------------------------------------------------------------------------
## Simulate Global Log scores for First Pick Only
#--------------------------------------------------------------------------------

# 4) Parametric bootstrap under fair lottery model
B <- 10000
sim_D <- replicate(B, {
  sim_winners <- mapply(function(p) sample.int(length(p), 1, prob = p),
                        prob_list)
  -1 * loglik_obs(prob_list, sim_winners)
})

# Compere to actual results

# percentile
mean(sim_D >= D_obs)

## Base R summary
summary(sim_D)          # Min, 1st Qu., Median, Mean, 3rd Qu., Max
sd(sim_D)               # Standard deviation
IQR(sim_D)              # Inter-quartile range (Q3 − Q1)
quantile(sim_D, probs = c(.05, .95))  



#--------------------------------------------------------------------------------
####  Calculate Log scores for Any Top Pick    ####
#--------------------------------------------------------------------------------

# D_obs for TopPick — sum of -log(p) over all teams that got a top pick
D_obs_top <- lot %>%
  filter(TopPick == 1) %>%
  summarise(D_obs = sum(-log(ProbTopPick))) %>%
  pull(D_obs)

D_obs_top

# Which years contributed most to the deviance?
lot_top <- lot %>%
  select(Year, ProbTopPick, TopPick) %>%
  filter(!is.na(ProbTopPick), TopPick == 1)

lot_top <- lot_top %>%
  mutate(log_contrib = -1*log(ProbTopPick))

lot_top_contrib <- lot_top %>%
  group_by(Year) %>%
  summarise(contrib = sum(log_contrib), .groups = "drop") %>%
  arrange(desc(contrib))
print(lot_top_contrib, n = 36)

#--------------------------------------------------------------------------------
## Simulate Global Log scores for Any Top Picks
#--------------------------------------------------------------------------------

set.seed(3344788)
n_sim <- 10000

# Set up helper objects
idx_by_year   <- split(seq_len(nrow(lot)), lot$Year)        # indices for each year
combos_by_row <- lot$Chances                                # weight per team
log_published <- log(lot$ProbTopPick)                      # log(p) for each team

# number of picks per season (3 or 4)
picks_year <- ifelse(lot$Year[match(names(idx_by_year), lot$Year)] >= 2019, 4L, 3L)
names(picks_year) <- names(idx_by_year)

# storage
log_sim_Top <- numeric(n_sim)

## main simulation loop --------------------------------------------------------
for (s in seq_len(n_sim)) {
  
  total_log <- 0
  
  for (yr in names(idx_by_year)) {
    
    idx   <- idx_by_year[[yr]]                  # indices of this year
    picks <- picks_year[yr]                     # 3 or 4
    probs <- combos_by_row[idx]                 # chances this year
    
    winners <- sample(idx, picks, replace = FALSE, prob = probs)
    
    total_log <- total_log + sum(log_published[winners])
  }
  
  # total deviance for this simulated world
  log_sim_Top[s] <- -1 * total_log
}

## Compere to actual results

# percentile
mean(log_sim_Top >= D_obs_top)  # upper-tail p-value

# summary
summary(log_sim_Top)
sd(log_sim_Top)
quantile(log_sim_Top, probs = c(0.05, 0.95))


#--------------------------------------------------------------------------------
# Visualiation
#--------------------------------------------------------------------------------

# Sample 50k points for rain layer only
rain_sample_size <- 50000
log_rain_first <- sample(sim_D,       rain_sample_size)
log_rain_top   <- sample(log_sim_Top, rain_sample_size)

# Rain-cloud plot – First Pick
ggplot() +
  stat_halfeye(
    aes(x = "", y = sim_D),  # full density
    fill = "steelblue", colour = NA, position = position_nudge(x = 0.15)) +
  geom_jitter(
    aes(x = "", y = log_rain_first),  # downsampled points
    position = position_jitter(0.15),
    size = 0.1, alpha = 0.4, colour = "steelblue4") +
  geom_hline(yintercept = D_obs, colour = "red", size = 1) +
  coord_flip() +
  labs(title = "Rain-cloud plot of simulated log scores – First pick",
       y = "log-likelihood", x = NULL) +
  theme_minimal(base_size = 12)

# Rain-cloud plot – Top Picks (1–3 or 1–4)
ggplot() +
  stat_halfeye(
    aes(x = "", y = log_sim_Top),  # full density
    fill = "steelblue", colour = NA, position = position_nudge(x = 0.15)) +
  geom_jitter(
    aes(x = "", y = log_rain_top),  # downsampled points
    position = position_jitter(0.15),
    size = 0.1, alpha = 0.4, colour = "steelblue4") +
  geom_hline(yintercept = D_obs_top, colour = "red", size = 1) +
  coord_flip() +
  labs(title = "Rain-cloud plot of simulated log scores – Top picks",
       y = "log-likelihood", x = NULL) +
  theme_minimal(base_size = 12)

