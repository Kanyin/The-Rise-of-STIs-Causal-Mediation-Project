pacman::p_load(tidyverse, mediation, SuperLearner, xgboost,glmnet,randomForest,caret,data.table, purrr,rstatix,car)

#mediatior function
make_X <- function(data) {
  w=model.matrix(STI_rate~ ACA + Year + Disease + Section, data = data)[, -1]
  as.data.frame(w)
}

#outcome function
make_X_out <- function(data,M) {
  y=cbind(M = M, make_X(data))
  as.data.frame(y)
}


X_med_train <- make_X(tbl)

#compare ml methods with SuperLearner

sl_lib=c("SL.glm", "SL.xgboost", "SL.glmnet")


sl_med <- SuperLearner(
  Y = data$condom_pct,
  X = X_med_train,
  SL.library = sl_lib,
  family = gaussian()
)

# treatment
pre  <- tbl;      pre$ACA1 <- 0
post <- tbl.out;  post$ACA1 <- 1

X_pre  <- make_X(pre)
X_post <- make_X(post)

# predict mediator
M0_hat <- predict(sl_med, newdata = X_pre, onlySL = TRUE)$pred
M1_hat <- predict(sl_med, newdata = X_post, onlySL = TRUE)$pred


X_out_train <- make_X_out(tbl, tbl$condom_pct)

sl_out <- SuperLearner(
  Y = tbl$Y,
  X = X_out_train,
  SL.library = sl_lib,
  family = gaussian()
)


X_1M1 <- make_X_out(post, M1_hat)
X_1M0 <- make_X_out(post, M0_hat)
X_0M1 <- make_X_out(pre,  M1_hat)
X_0M0 <- make_X_out(pre,  M0_hat)

Y_1M1 <- predict(sl_out, newdata = X_1M1, onlySL = TRUE)$pred
Y_1M0 <- predict(sl_out, newdata = X_1M0, onlySL = TRUE)$pred
Y_0M1 <- predict(sl_out, newdata = X_0M1, onlySL = TRUE)$pred
Y_0M0 <- predict(sl_out, newdata = X_0M0, onlySL = TRUE)$pred

#Estimate Effects
ACME1 <- mean(Y_1M1 - Y_1M0)
ACME0 <- mean(Y_0M1 - Y_0M0)
ADE   <- mean(Y_1M0 - Y_0M0)
TE    <- mean(Y_1M1 - Y_0M0)

# Output 
cat("ACME (T=1):", ACME1, "\n")
cat("ACME (T=0):", ACME0, "\n")
cat("ADE       :", ADE, "\n")
cat("Total Eff :", TE, "\n")
