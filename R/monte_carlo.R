run_dataset <- function(d,z,hidden,replicate,experiment,seed,cfg,keep_trace=FALSE) {
  metrics<-predictions<-diagnostics<-traces<-list()
  ij<-arrayInd(hidden,dim(d$x))
  base<-data.frame(Experiment=experiment,Replicate=replicate,Seed=seed,Day=d$day,
    Id=d$meta$Id[ij[,1]],Date=d$meta$Date[ij[,1]],BootstrapRow=ij[,1],
    Hour=ij[,2]-1L,Truth=d$x[hidden])
  for(fw in c('Whole_day','Daytime','Evening')) {
    hh<-window_hours(cfg,fw); zz<-z[,hh+1L,drop=FALSE]
    pred<-base; pred$FitWindow<-fw
    # Whole-day evaluation is split by identical master-mask coordinates below.
    for(m in c('Gaussian','Contaminated','Student_t')) {
      start<-proc.time()[3]
      fit<-tryCatch(fit_em(zz,m,cfg),error=function(e)e)
      elapsed<-unname(proc.time()[3]-start)
      ok<-!inherits(fit,'error') && fit$converged
      vals<-rep(NA_real_,nrow(base))
      if(ok) {
        p<-predict_em(fit,zz); inside<-which(base$Hour %in% hh)
        vals[inside]<-p[cbind(ij[inside,1],match(base$Hour[inside],hh))]
      }
      pred[[m]]<-vals
      diagnostics[[length(diagnostics)+1L]]<-data.frame(Experiment=experiment,Replicate=replicate,
        Day=d$day,FitWindow=fw,Method=m,Runtime=elapsed,Converged=ok,
        Iterations=if(inherits(fit,'error')) NA else fit$iterations,
        MinEigen=if(inherits(fit,'error')) NA else fit$min_eigen,
        Condition=if(inherits(fit,'error')) NA else fit$condition,
        Alpha=if(m=='Contaminated'&&!inherits(fit,'error')) fit$alpha else NA,
        Eta=if(m=='Contaminated'&&!inherits(fit,'error')) fit$eta else NA,
        Error=if(inherits(fit,'error')) conditionMessage(fit) else if(!ok) 'Iteration limit' else '')
      if(keep_trace && !inherits(fit,'error')) traces[[length(traces)+1L]]<-data.frame(
        Experiment=experiment,Replicate=replicate,Day=d$day,FitWindow=fw,Method=m,fit$trace)
    }
    start<-proc.time()[3]
    means<-colMeans(zz,na.rm=TRUE); means[!is.finite(means)]<-NA_real_
    pred$Time_of_day_mean<-means[match(pred$Hour,hh)]
    mean_runtime<-unname(proc.time()[3]-start)
    pred$Zero_only<-0
    for(ew in if(fw=='Whole_day') names(cfg$windows) else fw) {
      a<-pred[pred$Hour %in% window_hours(cfg,ew),,drop=FALSE]; a$EvalWindow<-ew
      # A zero-heldout window still gets NA metrics with N=0.
      s<-score_predictions(a,cfg)
      s$Runtime<-vapply(s$Method,function(m) {
        if(m=='Zero_only') return(0)
        if(m=='Time_of_day_mean') return(mean_runtime)
        diagnostics[[match(m,c('Gaussian','Contaminated','Student_t'))+length(diagnostics)-3L]]$Runtime
      },numeric(1))
      s<-cbind(data.frame(Experiment=experiment,Replicate=replicate,Seed=seed,
        Day=d$day,FitWindow=fw,EvalWindow=ew),s)
      metrics[[length(metrics)+1L]]<-s
      predictions[[length(predictions)+1L]]<-a
    }
  }
  list(metrics=do.call(rbind,metrics),predictions=do.call(rbind,predictions),
       diagnostics=do.call(rbind,diagnostics),traces=if(length(traces))do.call(rbind,traces)else NULL)
}
run_task <- function(task,root,days,cfg) {
  path<-file.path(root,'results','checkpoints',sprintf('%s_%04d.rds',task$experiment,task$replicate))
  if(file.exists(path)) return(path)
  result<-list(); masks<-list(); rates<-list(); sampled<-NULL
  if(task$experiment=='bootstrap') {
    ids<-sort(unique(unlist(lapply(days,function(d)d$meta$Id))))
    set.seed(cfg$seed+100000L+task$replicate)
    sampled<-sample(ids,length(ids),replace=TRUE)
  }
  for(k in seq_along(days)) {
    original<-days[[k]]
    seed<-cfg$seed+1000L*k+if(task$experiment=='bootstrap')1L else task$replicate
    mask<-make_mask(original$x,seed,cfg$missing_fraction)
    if(task$experiment=='bootstrap') {
      # Linked cluster draws preserve overlap across dates; absent date rows stay absent.
      ix<-match(sampled,original$meta$Id); ix<-ix[!is.na(ix)]
      d<-original; d$x<-original$x[ix,,drop=FALSE]; d$meta<-original$meta[ix,,drop=FALSE]
      z<-mask$z[ix,,drop=FALSE]
      hidden<-which(is.na(z)&!is.na(d$x))
    } else {
      d<-original; z<-mask$z; hidden<-mask$hidden
      masks[[k]]<-mask_coordinates(d,mask,task$replicate,cfg)
      if(task$replicate==1L) {
        dd<-d$meta; dd[sprintf('Hour%02d',0:23)]<-as.data.frame(z)
        write_table(dd,file.path(root,'results','missingness',paste0(tolower(d$day),'_primary_masked.csv')))
      }
    }
    for(w in names(cfg$windows)) {
      cols<-window_hours(cfg,w)+1L
      rates[[length(rates)+1L]]<-data.frame(Experiment=task$experiment,Replicate=task$replicate,
        Day=d$day,Window=w,Observed=sum(!is.na(d$x[,cols,drop=FALSE])),
        Hidden=sum(is.na(z[,cols,drop=FALSE])&!is.na(d$x[,cols,drop=FALSE])))
    }
    result[[k]]<-run_dataset(d,z,hidden,task$replicate,task$experiment,seed,cfg,
                             keep_trace=task$experiment=='monte_carlo'&&task$replicate==1L)
  }
  ans<-list(metrics=do.call(rbind,lapply(result,`[[`,'metrics')),
    predictions=do.call(rbind,lapply(result,`[[`,'predictions')),
    diagnostics=do.call(rbind,lapply(result,`[[`,'diagnostics')),
    traces=do.call(rbind,lapply(result,`[[`,'traces')),
    masks=if(length(masks))do.call(rbind,masks)else NULL,
    rates=do.call(rbind,rates),sampled_ids=sampled)
  # Store full results once per replicate. Bootstrap predictions remain in checkpoints.
  saveRDS(ans,paste0(path,'.tmp')); file.rename(paste0(path,'.tmp'),path)
  path
}
