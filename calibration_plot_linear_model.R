# ============================================================================
#  NBA LOTTERY ANALYSIS: IS THE LOTTERY FAIR?
#  Statistical tests for Deviance (1990-2025)
# ============================================================================

#--------------------------------------------------------------------------------
                #### Script 3: Calibration Analysis ####
#--------------------------------------------------------------------------------
library(dplyr)
library(marginaleffects)
#--------------------------------------------------------------------------------
                       ####   ANY TOP PICK   ####
#--------------------------------------------------------------------------------

### Calibration Plot - TOP PICK  ------------------------------------------------

lot_summary <- lot %>% 
    mutate(bin = ntile(ProbTopPick, 10)) %>%
    group_by(bin) %>%
    summarise(
      p_x = mean(ProbTopPick),
      mean_prob = mean(TopPick),
      n = n(),
      se = sqrt(mean_prob * (1 - mean_prob) / n)
    )

lot %>% 
  ggplot(aes(ProbTopPick, TopPick)) + 
  geom_abline(aes(color = "Equivilance", slope = 1, intercept = 0), 
              linetype = "dashed", linewidth = 1, show.legend = FALSE) + 
  geom_point(aes(x = p_x, y = mean_prob),
             data = lot_summary, size = 4, shape = 23, fill = "#01cdfe") +
  geom_errorbar(aes(x = p_x, y = mean_prob, 
                    ymin = mean_prob - 1.96 *se,
                    ymax = mean_prob + 1.96 *se),
                data = lot_summary) + 
  theme_bw() + 
  scale_x_continuous("Published Probability", labels = scales::label_percent()) + 
  scale_y_continuous("Observed Frequency", labels = scales::label_percent()) + 
  labs(title = "Top Pick – Calibration Curve") +
  coord_equal()


### Linear Model - TOP PICK  ---------------------------------------------------

mod1 <- lm(TopPick ~ ProbTopPick,  
           data = lot)

## Model plot
lot %>% 
  ggplot(aes(ProbTopPick, TopPick)) + 
  # geom_point() + 
  geom_abline(aes(color = "Equivilance", slope = 1, intercept = 0), 
              linetype = "dashed", linewidth = 1) + 
  geom_smooth(aes(color = "Linear"),
              method = "lm", se = FALSE) + 
  geom_smooth(aes(color = "GAM"),
              method = "gam", se = TRUE) + 
  theme_bw() + 
  scale_x_continuous("Published probability", labels = scales::label_percent()) + 
  scale_y_continuous("Observed frequency", labels = scales::label_percent()) + 
  labs(title = "Top Pick – Linear and GAM Curves") +
  coord_equal()

## Test 
parameters::model_parameters(mod1, vcov = "HC3")

hypotheses(mod1, hypothesis = c("b1 = 0", "b2 = 1"), vcov = "HC3")
hypotheses(mod1, hypothesis = c("b1 = 0", "b2 = 1"), vcov = "HC3") %>% 
  hypotheses(joint = TRUE)

## Bin level R sqaured (alerting) 
# how close is the conditional mean (mean_prob) to the expected conditional mean (p_x)
cor(lot_summary$p_x, lot_summary$mean_prob)^2

#--------------------------------------------------------------------------------
                     ####   FIRST PICK ONLY   ####
#--------------------------------------------------------------------------------

#  Calibration Plot -  FIRST PICK --------------------------------------------------------------

lot_summary <- lot %>% 
  mutate(bin = ntile(Prob1, 8)) %>%
  group_by(bin) %>%
  summarise(
    p_x = mean(Prob1),
    mean_prob = mean(WonFirstPick),
    n = n(),
    se = sqrt(mean_prob * (1 - mean_prob) / n)
  )


lot %>% 
  ggplot(aes(Prob1, WonFirstPick)) + 
  # geom_point() + 
  geom_abline(aes(color = "Equivilance", slope = 1, intercept = 0), 
              linetype = "dashed", linewidth = 1, show.legend = FALSE) + 
  geom_point(aes(x = p_x, y = mean_prob),
             data = lot_summary, size = 4, shape = 23, fill = "#01cdfe") +
  geom_errorbar(aes(x = p_x, y = mean_prob, 
                      ymin = mean_prob - 1.96 *se,
                      ymax = mean_prob + 1.96 *se),
                  data = lot_summary) + 
  theme_bw() + 
  scale_x_continuous("Published Probability", labels = scales::label_percent()) + 
  scale_y_continuous("Observed Frequency", labels = scales::label_percent()) + 
  labs(title = "First Pick – Calibration Curve") +
  coord_equal()


## Linear Model - First PICK  ---------------------------------------------------

mod1 <- lm(WonFirstPick ~ Prob1, 
           data = lot)

# Model plot 
lot %>% 
  ggplot(aes(Prob1, WonFirstPick)) + 
  # geom_point() + 
  geom_abline(aes(color = "Equivilance", slope = 1, intercept = 0), 
              linetype = "dashed", linewidth = 1) + 
  geom_smooth(aes(color = "Linear"),
              method = "lm", se = FALSE) + 
  geom_smooth(aes(color = "GAM"),
              method = "gam", se = TRUE) + 
  theme_bw() + 
  scale_x_continuous("Published probability", labels = scales::label_percent()) + 
  scale_y_continuous("Observed frequency", labels = scales::label_percent()) + 
  labs(title = "First Pick – Linear and GAM Curves") +
  coord_equal()

# Test
parameters::model_parameters(mod1, vcov = "HC3")

hypotheses(mod1, hypothesis = c("b1 = 0", "b2 = 1"), vcov = "HC3")
hypotheses(mod1, hypothesis = c("b1 = 0", "b2 = 1"), vcov = "HC3") %>% 
  hypotheses(joint = TRUE)

## Bin level R sqaured (alerting) - First Pick 
cor(lot_summary$p_x, lot_summary$mean_prob)^2


