metric_vector <- function(truth,pred) {
  if(!length(truth) || any(!is.finite(pred))) return(c(RMSE=NA,MAE=NA,Bias=NA,MedianAE=NA,NegativeProportion=NA))
  e<-pred-truth
  c(RMSE=sqrt(mean(e^2)),MAE=mean(abs(e)),Bias=mean(e),MedianAE=median(abs(e)),NegativeProportion=mean(pred<0))
}
score_predictions <- function(pred,cfg) {
  sets<-list(All=rep(TRUE,nrow(pred)),Zero=pred$Truth==0,Positive=pred$Truth>0,
    LowPositive=pred$Truth>0 & pred$Truth<=cfg$low_positive_max,
    ModeratePositive=pred$Truth>cfg$low_positive_max & pred$Truth<=cfg$high_positive_min,
    HighPositive=pred$Truth>cfg$high_positive_min)
  cols<-c('Gaussian','Contaminated','Student_t','Zero_only','Time_of_day_mean')
  do.call(rbind,lapply(names(sets),function(group) do.call(rbind,lapply(cols,function(m) {
    a<-pred[sets[[group]],,drop=FALSE]
    data.frame(Method=m,Activity=group,N=nrow(a),Available=sum(is.finite(a[[m]])),
               as.list(metric_vector(a$Truth,a[[m]])),check.names=FALSE)
  }))))
}
summarize_metrics <- function(d,keys,metrics=c('RMSE','MAE','Bias','MedianAE','NegativeProportion','Runtime')) {
  groups<-split(seq_len(nrow(d)),interaction(d[keys],drop=TRUE,lex.order=TRUE))
  do.call(rbind,lapply(groups,function(ix) do.call(rbind,lapply(metrics,function(metric) {
    v<-d[[metric]][ix]; v<-v[is.finite(v)]; n<-length(v)
    center<-if(n)mean(v) else NA; se<-if(n>1)sd(v)/sqrt(n) else NA
    data.frame(d[ix[1],keys,drop=FALSE],Metric=metric,Attempted=length(ix),Completed=n,
      Mean=center,Median=if(n)median(v) else NA,SD=if(n>1)sd(v) else NA,
      MCSE=se,MC_Lower=center-1.96*se,MC_Upper=center+1.96*se,
      Lower=if(n)unname(quantile(v,.025)) else NA,Upper=if(n)unname(quantile(v,.975)) else NA)
  }))))
}
