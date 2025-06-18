library(rvest)
library(tidyverse)

# Scrape data from CDC concerning Sexually Transmitted Infections
url= "https://www.cdc.gov/sti-statistics/data-vis/table-sticasesrates.html"
page= read_html(url)

tbl= html_table(page,fill=TRUE, header=FALSE)
tbl= as.data.frame(tbl)
tbl[1:3,]=lapply(1:ncol(tbl), function(col) {
  gsub("\n", " ",tbl[1:3,col])
})



head.row=tbl[1:3,]
names= apply(head.row, 2, paste,collapse="_")
data= tbl[-(1:3),]



vector=lapply(1:ncol(data), function(y){
  gsub("[^a-zA-Z0-9]", "",data[y])
  gsub(",", "",data[y])
  eval(parse(text = data[y])) 
})

data=as.data.frame(t(do.call(rbind,vector)))
names(data)=gsub("[†¶‖‡§,]", "", names)
data_long=pivot_longer(data, cols=-1, names_to = c("Disease", "Section", "Type"), values_to = "Value", names_sep ="_" )
data_long$Value=gsub(",", "", data_long$Value)
data_long$Value=as.numeric(data_long$Value)
data_long$Year=as.numeric(data_long$Year_Year_Year)
data_long=data_long[-1]
data_long=pivot_wider(data_long, names_from = Type, values_from = Value)
