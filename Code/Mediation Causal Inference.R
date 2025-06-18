pacman::p_load(tidyverse, mediation, SuperLearner, xgboost,glmnet,randomForest,caret,data.table, purrr)
STI=readRDS("Data Projects/STI/Data/data.rds")
STI$Disease=as.factor(STI$Disease) #1: Chancroid #2 Chlamydia #3Gonnorhea #Syphyilis

#Combine Males and Female Responses
Activ=read.csv("Data Projects/STI/Data/STI_Protection.csv", header = TRUE)
Activ=separate(Activ, 1, into=c("Source", "Year","Sex"), sep="-")

Activ=Activ %>% group_by(Year) %>%
  summarise(Sex="Both", condom_use=sum(condom_users), active=sum(active_population)) %>%
  mutate(crude_rate=condom_use/active)

#Activ$ACA=factor(ifelse(Activ$Year<2014, "No","Yes")) #0 = No #1= Yes
Activ$ACA=factor(ifelse(Activ$Year<2014, 0,1)) #0 = No #1= Yes

#CDC WONDER for Morbidity to 2014
# Sexually Transmitted Infections Surveillance, 2023.

# Affordable Care ACT was implemented Jan 1 2014, providing greater access to healthcare
#'causing greater increase in reporting of STIs, and not necessarily increase in actual STIs
#'Condom use was assessed by tallying the total number of condom users over the active population
#'
#'#national sti rate= year+ condom_use+ ACA


combn.table=merge(Activ,STI, by='Year')
names(combn.table)[5]="condom_pct"
names(combn.table)[10]="STI_rate"
combn.table= combn.table %>% mutate(across(c("Year", "condom_pct", "Cases", "STI_rate"),as.numeric))
combn.table$Section=factor(combn.table$Section)

med.fit=lm(condom_pct~ACA+ Disease + Year, data=combn.table)
outcome.fit=lm(STI_rate~Disease + ACA+ Year+ condom_pct, data=combn.table)

med.out = mediate(med.fit,outcome.fit, treat="ACA", mediator="condom_pct", sims=1000)

#tbl= model.matrix(~ . - 1, data = combn.table[, c("ACA", "condom_pct", "Year", "Disease")])
tbl = model.matrix(~ ACA + Year + Disease+Section, data=combn.table)[, -1] 
tbl.out = cbind(combn.table$condom_pct, tbl)[,-1]

sl_med = SuperLearner(Y=combn.table$condom_pct,
                       X=as.data.frame(tbl),
                       family=gaussian(),
                       SL.library=c("SL.nnet", "SL.glmnet", "SL.xgboost"))

sl_out = SuperLearner(Y=combn.table$STI_rate,
                       X=as.data.frame(tbl.out),
                       family=gaussian(),
                       SL.library=c("SL.nnet", "SL.glmnet", "SL.xgboost"))



post = tbl.out; tbl.out[, "ACA1"] = 1
pre =tbl; tbl[, "ACA1"] = 0

post_hat = predict(sl_med,newdata = post, onlySL = TRUE)$pred
pre_hat = predict(sl_med, newdata = pre, onlySL = TRUE)$pred


# Define base learners
sl_lib <- c("SL.ranger", "SL.xgboost", "SL.glmnet")

# Reusable matrix builder (must match in train & predict)
make_X <- function(combn.table) {
  model.matrix(~ ACA + Year + Disease + Section, data = data)[, -1]
}

# Reusable function to add mediator M to design matrix
make_X_out <- function(combn.table, ) {
  cbind(M = M, make_X(data))
}

# 1. --- Fit Mediator Model (M ~ T + Covariates) ---
X_med_train <- make_X(tbl)

sl_med <- SuperLearner(
  Y = tbl$M,
  X = X_med_train,
  SL.library = sl_lib,
  family = gaussian()
)

# 2. --- Create Treatment Conditions ---
pre  <- tbl;      pre$ACA1 <- 0
post <- tbl.out;  post$ACA1 <- 1

X_pre  <- make_X(pre)
X_post <- make_X(post)

# 3. --- Predict Mediator under T=0 and T=1 ---
M0_hat <- predict(sl_med, newdata = X_pre, onlySL = TRUE)$pred
M1_hat <- predict(sl_med, newdata = X_post, onlySL = TRUE)$pred

# 4. --- Fit Outcome Model (Y ~ M + T + Covariates) ---
X_out_train <- make_X_out(tbl, tbl$M)

sl_out <- SuperLearner(
  Y = tbl$Y,
  X = X_out_train,
  SL.library = sl_lib,
  family = gaussian()
)

# 5. --- Predict All Four Counterfactual Outcomes ---
X_1M1 <- make_X_out(post, M1_hat)
X_1M0 <- make_X_out(post, M0_hat)
X_0M1 <- make_X_out(pre,  M1_hat)
X_0M0 <- make_X_out(pre,  M0_hat)

Y_1M1 <- predict(sl_out, newdata = X_1M1, onlySL = TRUE)$pred
Y_1M0 <- predict(sl_out, newdata = X_1M0, onlySL = TRUE)$pred
Y_0M1 <- predict(sl_out, newdata = X_0M1, onlySL = TRUE)$pred
Y_0M0 <- predict(sl_out, newdata = X_0M0, onlySL = TRUE)$pred

# 6. --- Estimate Effects ---
ACME1 <- mean(Y_1M1 - Y_1M0)
ACME0 <- mean(Y_0M1 - Y_0M0)
ADE   <- mean(Y_1M0 - Y_0M0)
TE    <- mean(Y_1M1 - Y_0M0)

# 7. --- Output ---
cat("ACME (T=1):", ACME1, "\n")
cat("ACME (T=0):", ACME0, "\n")
cat("ADE       :", ADE, "\n")
cat("Total Eff :", TE, "\n")





# # Create full new X matrices
# X_1M1 = cbind(M = post_hat, post)[,-1]
# X_1M0 = cbind(M = pre_hat, post)[,-1]
# X_0M1 = cbind(M = post_hat, pre)[,-1]
# X_0M0 = cbind(M = pre_hat, pre)[,-1]
# 
# # Predict outcomes
# Y_1M1 = predict(sl_out, newdata = X_1M1)$pred
# Y_1M0 = predict(sl_out, newdata = X_1M0)$pred
# Y_0M1 = predict(sl_out, newdata = X_0M1)$pred
# Y_0M0 = predict(sl_out, newdata = X_0M0)$pred
# 
# # Estimate effects
# ACME1 = mean(Y_1M1 - Y_1M0)
# ACME0 = mean(Y_0M1 - Y_0M0)
# ADE   = mean(Y_1M0 - Y_0M0)
# TE    = mean(Y_1M1 - Y_0M0)
# 
# cat("ACME (T=1):", ACME1, "\n")
# cat("ACME (T=0):", ACME0, "\n")
# cat("ADE:", ADE, "\n")
# cat("Total Effect:", TE, "\n")
