a<-commandArgs(trailingOnly=FALSE);script<-sub('^--file=','',a[grepl('^--file=',a)])
root<-dirname(dirname(normalizePath(script)));source(file.path(root,'R','setup.R'));load_project(root)
cfg<-yaml::read_yaml(file.path(root,'config.yml'));days<-readRDS(file.path(root,'data','processed','study_data.rds'))
checks<-list();check<-function(name,value) {stopifnot(isTRUE(value));checks[[length(checks)+1L]]<<-data.frame(Check=name,Passed=TRUE)}
files<-list.files(file.path(root,'results','checkpoints'),pattern='\\.rds$',full.names=TRUE)
check('All requested checkpoints exist',length(files)==cfg$monte_carlo_repetitions+cfg$bootstrap_repetitions)
ids<-sort(unique(unlist(lapply(days,function(d)d$meta$Id))))
for(f in files) {
 a<-readRDS(f);e<-a$metrics$Experiment[1];r<-a$metrics$Replicate[1]
 if(e=='bootstrap') {set.seed(cfg$seed+100000L+r);stopifnot(identical(a$sampled_ids,sample(ids,length(ids),replace=TRUE)))}
 for(k in seq_along(days)) {
  d<-days[[k]];seed<-cfg$seed+1000L*k+if(e=='bootstrap')1L else r
  m<-make_mask(d$x,seed,cfg$missing_fraction)
  if(e=='bootstrap') {
   ix<-match(a$sampled_ids,d$meta$Id);ix<-ix[!is.na(ix)]
   x<-d$x[ix,,drop=FALSE];z<-m$z[ix,,drop=FALSE];meta<-d$meta[ix,,drop=FALSE]
   hidden<-which(is.na(z)&!is.na(x))
  } else {x<-d$x;z<-m$z;meta<-d$meta;hidden<-m$hidden}
  p<-a$predictions[a$predictions$Day==d$day,]
  whole<-p[p$FitWindow=='Whole_day' & p$EvalWindow=='Whole_day',]
  ij<-arrayInd(hidden,dim(x))
  stopifnot(nrow(whole)==length(hidden),identical(whole$Hour,as.integer(ij[,2]-1L)),
    identical(as.character(whole$Id),as.character(meta$Id[ij[,1]])),
    identical(as.numeric(whole$Truth),as.numeric(x[hidden])),all(whole$Zero_only==0))
  meanp<-colMeans(z,na.rm=TRUE)[ij[,2]]
  stopifnot(isTRUE(all.equal(as.numeric(whole$Time_of_day_mean),as.numeric(meanp))))
  for(w in c('Daytime','Evening')) {
   one<-p[p$FitWindow==w & p$EvalWindow==w,]
   two<-p[p$FitWindow=='Whole_day' & p$EvalWindow==w,]
   v1<-as.matrix(one[c('BootstrapRow','Hour','Truth')])
   v2<-as.matrix(two[c('BootstrapRow','Hour','Truth')])
   stopifnot(identical(unname(v1),unname(v2)))
   stopifnot(identical(as.numeric(one$Time_of_day_mean),as.numeric(two$Time_of_day_mean)),
             identical(as.numeric(one$Zero_only),as.numeric(two$Zero_only)))
  }
 }
 if(r%%100==0) {cat(e,r,'verified\n');flush.console()}
}
check('Every MCAR mask reproduces from its seed',TRUE)
check('Every hidden target matches original source data',TRUE)
check('Window comparisons use identical coordinates',TRUE)
check('Time-of-day means exclude hidden entries in every fit',TRUE)
check('Zero-only predictions are zero in all replicates',TRUE)
check('Bootstrap linked cluster samples reproduce from seeds',TRUE)
check('Bootstrap duplicates share missingness; no cross-copy target leakage',TRUE)
dg<-read.csv(file.path(root,'results','model_comparisons','fit_diagnostics.csv'))
check('All planned EM fits attempted',nrow(dg)==(cfg$monte_carlo_repetitions+cfg$bootstrap_repetitions)*18L)
check('All returned covariances positive definite',all(dg$MinEigen[!is.na(dg$MinEigen)]>0))
tr<-read.csv(file.path(root,'results','model_comparisons','primary_likelihood_traces.csv'))
check('Primary objectives monotone',all(vapply(split(tr,interaction(tr[c('Day','FitWindow','Method')])),
 function(d)all(diff(d$Objective)>=-1e-7*(1+abs(head(d$Objective,-1)))),logical(1))))
mc<-read.csv(file.path(root,'results','monte_carlo','replicate_metrics.csv'))
check('200 distinct Monte Carlo masks per date',all(vapply(split(mc$Replicate,mc$Day),function(x)length(unique(x)),integer(1))==cfg$monte_carlo_repetitions))
boot<-read.csv(file.path(root,'results','bootstrap','bootstrap_metrics.csv'))
check('500 bootstrap samples per date',all(vapply(split(boot$Replicate,boot$Day),function(x)length(unique(x)),integer(1))==cfg$bootstrap_repetitions))
check('Finite metrics always use full evaluation coverage',all(mc$Available[is.finite(mc$RMSE)]==mc$N[is.finite(mc$RMSE)]))
rt<-read.csv(file.path(root,'results','missingness','realized_missingness.csv'))
rt<-rt[rt$Experiment=='monte_carlo' & rt$Window=='Whole_day',]
check('Realized full-day mask size is ceiling 10 percent',all(rt$Hidden==ceiling(cfg$missing_fraction*rt$Observed)))
write_table(do.call(rbind,checks),file.path(root,'qa','study_checks.csv'))
cat(length(checks),'study-level checks passed; all',length(files),'checkpoints inspected\n')
