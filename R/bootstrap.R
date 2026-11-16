# Paired comparisons use entire finite replicate scores, not disjoint available
# cell subsets. Every finite score covers the complete N heldout entries.
paired_differences <- function(d) {
  keys<-c('Experiment','Replicate','Day','FitWindow','EvalWindow','Activity')
  pairs<-combn(c('Gaussian','Contaminated','Student_t','Zero_only','Time_of_day_mean'),2,simplify=FALSE)
  do.call(rbind,lapply(pairs,function(pair) {
    a<-d[d$Method==pair[1],c(keys,'N','RMSE','MAE')]
    b<-d[d$Method==pair[2],c(keys,'N','RMSE','MAE')]
    j<-merge(a,b,by=keys,suffixes=c('_A','_B'))
    stopifnot(all(j$N_A==j$N_B))
    data.frame(j[keys],MethodA=pair[1],MethodB=pair[2],N=j$N_A,
      RMSE=j$RMSE_A-j$RMSE_B,MAE=j$MAE_A-j$MAE_B)
  }))
}
window_differences <- function(d) {
  keys<-c('Experiment','Replicate','Day','EvalWindow','Activity','Method')
  a<-d[d$FitWindow==d$EvalWindow & d$EvalWindow %in% c('Daytime','Evening'),c(keys,'N','RMSE','MAE')]
  b<-d[d$FitWindow=='Whole_day' & d$EvalWindow %in% c('Daytime','Evening'),c(keys,'N','RMSE','MAE')]
  j<-merge(a,b,by=keys,suffixes=c('_Specific','_Whole'))
  stopifnot(all(j$N_Specific==j$N_Whole))
  data.frame(j[keys],N=j$N_Specific,RMSE=j$RMSE_Specific-j$RMSE_Whole,MAE=j$MAE_Specific-j$MAE_Whole)
}
collect_results <- function(root,cfg) {
  files<-list.files(file.path(root,'results','checkpoints'),pattern='\\.rds$',full.names=TRUE)
  metrics<-diag<-masks<-rates<-traces<-list()
  predfile<-file.path(root,'results','predictions','heldout_predictions.csv')
  if(file.exists(predfile)) unlink(predfile)
  for(i in seq_along(files)) {
    a<-readRDS(files[i]); metrics[[i]]<-a$metrics; diag[[i]]<-a$diagnostics
    masks[[i]]<-a$masks; rates[[i]]<-a$rates; traces[[i]]<-a$traces
    if(a$metrics$Experiment[1]=='monte_carlo') write.table(a$predictions,predfile,sep=',',
      row.names=FALSE,col.names=!file.exists(predfile),append=file.exists(predfile),na='NA')
  }
  d<-do.call(rbind,metrics); dg<-do.call(rbind,diag)
  mc<-d[d$Experiment=='monte_carlo',]; boot<-d[d$Experiment=='bootstrap',]
  write_table(mc,file.path(root,'results','monte_carlo','replicate_metrics.csv'))
  write_table(boot,file.path(root,'results','bootstrap','bootstrap_metrics.csv'))
  keys<-c('Day','FitWindow','EvalWindow','Method','Activity')
  mcs<-summarize_metrics(mc,keys)
  bcs<-summarize_metrics(boot,keys)
  write_table(mcs,file.path(root,'results','monte_carlo','monte_carlo_summary.csv'))
  write_table(bcs,file.path(root,'results','bootstrap','bootstrap_confidence_intervals.csv'))
  pd<-paired_differences(d); wd<-window_differences(d)
  ps<-summarize_metrics(pd,c('Experiment','Day','FitWindow','EvalWindow','Activity','MethodA','MethodB'),c('RMSE','MAE'))
  ws<-summarize_metrics(wd,c('Experiment','Day','EvalWindow','Activity','Method'),c('RMSE','MAE'))
  write_table(ps,file.path(root,'results','model_comparisons','paired_model_comparisons.csv'))
  write_table(ws,file.path(root,'results','model_comparisons','window_comparisons.csv'))
  write_table(pd,file.path(root,'results','model_comparisons','paired_replicate_differences.csv'))
  write_table(wd,file.path(root,'results','model_comparisons','window_replicate_differences.csv'))
  write_table(dg,file.path(root,'results','model_comparisons','fit_diagnostics.csv'))
  g<-split(dg,interaction(dg[c('Experiment','Day','FitWindow','Method')],drop=TRUE))
  conv<-do.call(rbind,lapply(g,function(a) data.frame(a[1,c('Experiment','Day','FitWindow','Method')],
    Attempted=nrow(a),Converged=sum(a$Converged),ConvergenceRate=mean(a$Converged),
    MeanRuntime=mean(a$Runtime),MaxCondition=if(all(is.na(a$Condition)))NA else max(a$Condition,na.rm=TRUE))))
  write_table(conv,file.path(root,'results','model_comparisons','convergence_summary.csv'))
  write_table(do.call(rbind,masks),file.path(root,'results','missingness','mcar_mask_coordinates.csv'))
  rt<-do.call(rbind,rates); rt$RealizedFraction<-rt$Hidden/rt$Observed
  write_table(rt,file.path(root,'results','missingness','realized_missingness.csv'))
  write_table(do.call(rbind,traces),file.path(root,'results','model_comparisons','primary_likelihood_traces.csv'))
  # Rankings use only repetitions where ALL five methods have complete scores.
  primary<-mc[mc$Activity=='All' & mc$FitWindow==mc$EvalWindow,]
  groups<-split(primary,interaction(primary[c('Day','FitWindow')],drop=TRUE))
  ranking<-do.call(rbind,lapply(groups,function(a) {
    good<-tapply(is.finite(a$RMSE),a$Replicate,all)
    common<-a[a$Replicate %in% as.integer(names(good)[good]),]
    if(!nrow(common)) return(NULL)
    out<-aggregate(cbind(RMSE,MAE)~Day+FitWindow+Method,common,mean)
    out$CommonReplicates<-sum(good); out$AttemptedReplicates<-length(good)
    out$RankRMSE<-rank(out$RMSE,ties.method='min');out$RankMAE<-rank(out$MAE,ties.method='min'); out
  }))
  write_table(ranking,file.path(root,'results','model_comparisons','final_model_ranking.csv'))
  invisible(d)
}
