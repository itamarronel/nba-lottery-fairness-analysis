# ============================================================================
#  NBA LOTTERY ANALYSIS: IS THE LOTTERY FAIR?
#  Statistical tests for Deviance (1990-2025)
# ============================================================================

#--------------------------------------------------------------------------------
#### Script 2: Simulated Brier Distribution vs. Observed ####
#--------------------------------------------------------------------------------
library(dplyr)
library(readr) 
library(ggplot2)
library(car) 
library(marginaleffects)

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
          ####  Calculate Brier scores for Top & First Picks    ####
#--------------------------------------------------------------------------------

p_First       <- lot$Prob1
obs_First     <- lot$WonFirstPick
obs_Brier_First  <- mean((p_First - obs_First)^2)

p_Top       <- lot$ProbTopPick
obs_Top     <- lot$TopPick
obs_Brier_Top  <- mean((p_Top - obs_Top)^2)

# Brier First Pick
obs_Brier_First

# Brier Top Pick
obs_Brier_Top

brier_by_year <- lot %>% 
  group_by(Year) %>% 
  summarise(
    Brier_First = mean((Prob1 - WonFirstPick)^2),   # ממוצע השגיאה-בריבוע
    .groups = "drop"
  ) %>% 
  arrange(desc(Brier_First))     # למיין מהעונות ה"גרועות" לטובות

print(brier_by_year, n = 36)

#--------------------------------------------------------------------------------
## Simulate Global Brier scores for Any Top Picks
#--------------------------------------------------------------------------------

set.seed(123)
n_sim <- 10000          

# helper objects 
idx_by_year   <- split(seq_len(nrow(lot)), lot$Year)      # row indices per season
combos_by_row <- lot$Chances                              # balls per team
p_pred        <- lot$ProbTopPick                                # published
picks_year    <- ifelse(lot$Year[match(names(idx_by_year),
                                       lot$Year)] >= 2019, 4L, 3L)
names(picks_year) <- names(idx_by_year)                   # 3 vs 4 picks by season

# storage for results 
brier_sim_Top <- numeric(n_sim)

## main simulation loop ---------------------------------------------------------

for (s in seq_len(n_sim)) {
  
  y_bin <- integer(nrow(lot))        # 0/1 winners over *all* seasons
  
  for (yr in names(idx_by_year)) {
    
    idx   <- idx_by_year[[yr]]             # rows of this season
    picks <- picks_year[yr]                # 3 or 4
    
    winners <- sample(idx, picks,
                      replace = FALSE,
                      prob    = combos_by_row[idx])
    y_bin[winners] <- 1L
  }
  
  # global Brier score for this simulation
  brier_sim_Top[s] <- mean((y_bin - p_pred)^2)
}

# brier_sim now holds 100k scores
summary(brier_sim_Top)          # quick sanity check

## percentile (one-sided and two-sided if you like)
pct_below <- mean(brier_sim_Top <= obs_Brier_Top)      # lower-tail percentile
pct_above <- mean(brier_sim_Top >= obs_Brier_Top)      # upper-tail
pct_two   <- 2 * min(pct_below, pct_above)     # two-sided p-value

cat(sprintf(
  "\nObserved Brier = %.5f\nPercentile (lower tail) = %.4f\nPercentile (upper tail) = %.4f\nTwo-sided p-value ≈ %.4f\n",
  obs_Brier_Top, pct_below, pct_above, pct_two))

#--------------------------------------------------------------------------------
## Simulate Global Brier scores for First Pick Only
#--------------------------------------------------------------------------------

# published probabilities for pick-1
p_vec <- lot$Prob1                 # same length as number of rows

brier_sim_first <- numeric(n_sim)            # store 100k Brier scores

for(b in seq_len(n_sim)) {
  
  # ---- 1. simulate one winner per season --------------------------------------
  y_bin <- numeric(length(p_vec))  # 0/1 outcomes for this universe
  
  for(idx in idx_by_year){         # idx = row numbers of one season
    winner <- sample(idx, 1, prob = p_vec[idx])  # draw 1 winner
    y_bin[winner] <- 1
  }
  
  # ---- 2. compute Brier score -------------------------------------------------
  brier_sim_first[b] <- mean( (y_bin - p_vec)^2 )
}

# quick check: distribution of simulated Brier scores
summary(brier_sim_first)

# percentile (one-sided and two-sided if you like)
pct_below <- mean(brier_sim_first <= obs_Brier_First)      # lower-tail percentile
pct_above <- mean(brier_sim_first >= obs_Brier_First)      # upper-tail
pct_two   <- 2 * min(pct_below, pct_above)     # two-sided p-value

cat(sprintf(
  "\nObserved Brier = %.5f\nPercentile (lower tail) = %.4f\nPercentile (upper tail) = %.4f\nTwo-sided p-value ≈ %.4f\n",
  obs_Brier_First, pct_below, pct_above, pct_two))


#--------------------------------------------------------------------------------
##  Visualise simulated Brier distributions vs. observed
#--------------------------------------------------------------------------------

library(ggplot2)
library(ggdist)

## Rain-cloud plot of simulated Brier scores - Top pick

# Sample 50k points for rain layer only
rain_sample_size <- 50000
brier_sim_first <- sample(brier_sim_first,       rain_sample_size)
brier_sim_Top   <- sample(brier_sim_Top, rain_sample_size)

ggplot() +
  stat_halfeye(
    aes(x = "", y = brier_sim_Top),
    fill = "steelblue", colour = NA, position = position_nudge(x = 0.15) ) +
  # rain – jittered points
  geom_jitter(
    aes(x = "", y = brier_sim_Top), position =  position_jitter(0.15),
    size = 0.3, alpha = 0.4, colour = "steelblue4") +
  # reference line for the observed Brier
  geom_hline(yintercept = obs_Brier_Top, colour = "red", size = 1) +
  coord_flip() +
  labs(title = "Rain-cloud plot of simulated Brier scores - Top pick",
       y      = "Brier score", x = NULL) +
  theme_minimal(base_size = 12) 


## Rain-cloud plot of simulated Brier scores - First pick

ggplot() +
  stat_halfeye(
    aes(x = "", y = brier_sim_first),
    fill = "steelblue", colour = NA, position = position_nudge(x = 0.15) ) +
  # rain – jittered points
  geom_jitter(
    aes(x = "", y = brier_sim_first), position =  position_jitter(0.15),
    size = 0.3, alpha = 0.4, colour = "steelblue4") +
  # reference line for the observed Brier
  geom_hline(yintercept = obs_Brier_First, colour = "red", size = 1) +
  coord_flip() +
  labs(title = "Rain-cloud plot of simulated Brier scores - First pick",
       y      = "Brier score", x = NULL) +
  theme_minimal(base_size = 12) 


