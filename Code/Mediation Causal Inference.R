pacman::p_load(tidyverse, mediation, SuperLearner, xgboost,glmnet,randomForest,caret,data.table, purrr)
STI=readRDS("Data/data.rds")
STI$Disease=as.factor(STI$Disease) #1: Chancroid #2 Chlamydia #3Gonnorhea #Syphyilis

#Combine Males and Female Responses
Activ=read.csv("Data/STI_Protection.csv", header = TRUE)
Activ=separate(Activ, 1, into=c("Source", "Year","Sex"), sep="-")

Activ=Activ %>% group_by(Year) %>%
  summarise(Sex="Both", condom_use=sum(condom_users), active=sum(active_population)) %>%
  mutate(crude_rate=condom_use/active)

#Activ$ACA=factor(ifelse(Activ$Year<2014, "No","Yes")) #0 = No #1= Yes
Activ$ACA=factor(ifelse(Activ$Year<2014, 0,1)) #0 = No #1= Yes


combn.table=merge(Activ,STI, by='Year')
names(combn.table)[5]="condom_pct"
names(combn.table)[10]="STI_rate"
combn.table= combn.table %>% mutate(across(c("Year", "condom_pct", "Cases", "STI_rate"),as.numeric))
combn.table$Section=factor(combn.table$Section)

med.fit=lm(condom_pct~ACA+ Disease + Year, data=combn.table)
outcome.fit=lm(STI_rate~Disease + ACA+ Year+ condom_pct, data=combn.table)

med.out = mediate(med.fit,outcome.fit, treat="ACA", mediator="condom_pct", sims=1000)
