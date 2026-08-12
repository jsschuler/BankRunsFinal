library(tidyverse)
library(ggplot2)
setwd("~/")
read.csv("results.csv",header=FALSE) -> results
names(results) <- c("insur","prod","objP","failProb")

for (cProd in unique(results$prod)) {
  results %>% filter(prod==cProd) %>% 
    ggplot() + geom_line(aes(x=insur,y=failProb,color=objP)) + 
    labs(x="Insurance",y="Failure Probability",color="Exogenous Withdrawal Prob.",
    title="Probability of Bank Failure") + 
    theme_bw() + 
    theme(axis.text.x = element_text(angle = 90, hjust = 1)) -> p
  ggsave(paste0("results_",cProd,".pdf"),p)
}
