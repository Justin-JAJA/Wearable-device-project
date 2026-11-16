make_figures <- function(root) {
  library(ggplot2);library(patchwork)
  read_result<-function(p)read.csv(file.path(root,'results',p))
  days<-readRDS(file.path(root,'data','processed','study_data.rds'))
  desc<-read_result('descriptive/window_activity_summary.csv')
  mc<-read_result('monte_carlo/replicate_metrics.csv')
  boot<-read_result('bootstrap/bootstrap_confidence_intervals.csv')
  wd<-read_result('model_comparisons/window_comparisons.csv')
  primary<-do.call(rbind,lapply(list.files(file.path(root,'results','checkpoints'),
    pattern='monte_carlo_0001.rds',full.names=TRUE),function(f)readRDS(f)$predictions))
  cols<-c(Gaussian='#0072B2',Contaminated='#009E73',Student_t='#D55E00',
           Zero_only='#7A5195',Time_of_day_mean='#666666')
  theme_set(theme_minimal(base_size=11)+theme(panel.grid.minor=element_blank(),
    legend.position='bottom',plot.title=element_text(face='bold'),strip.text=element_text(face='bold')))
  save_plot<-function(p,name,width=11,height=6) {
    if(!is.null(p$labels$caption)) p<-p+labs(caption=paste(strwrap(p$labels$caption,width=130),collapse='\n'))
    p<-p+theme(plot.caption=element_text(hjust=0),plot.margin=margin(12,15,12,15))
    ggsave(file.path(root,'results','figures',paste0(name,'.pdf')),p,width=width,height=height,device='pdf')
    ggsave(file.path(root,'results','figures',paste0(name,'.png')),p,width=width,height=height,dpi=320,bg='white')
    p
  }
  long<-do.call(rbind,lapply(days,`[[`,'long'))
  profiles<-aggregate(Value~Day+Hour,long,mean)
  write_table(profiles,file.path(root,'results','descriptive','hourly_profiles.csv'))
  plots<-list()
  plots$profile<-save_plot(ggplot(profiles,aes(Hour,Value,color=Day))+
    geom_line(linewidth=.8)+geom_point(size=1.7)+
    geom_vline(xintercept=c(6,9,18),linetype='dashed',color='grey60')+
    scale_x_continuous(breaks=seq(0,24,3),limits=c(0,24))+
    labs(title='Mean hourly activity on the two selected dates',y='Steps per hour',x='Hour at interval start',
      caption='Dashed lines: end of nighttime (06), start of daytime (09), start of evening (18).'),
    '01_daily_profiles')
  dist<-do.call(rbind,lapply(c('Whole_day','Daytime','Evening','Nighttime'),function(w) {
    a<-long[long$Hour %in% window_hours(yaml::read_yaml(file.path(root,'config.yml')),w),];a$Window<-w;a
  }))
  a<-ggplot(dist,aes(Window,log1p(Value),fill=Day))+geom_boxplot(outlier.size=.35)+
    labs(y='log(1 + steps)',x=NULL,title='Activity distribution, including observed zeros')
  b<-ggplot(desc,aes(Window,ZeroProportion,fill=Day))+geom_col(position='dodge')+
    scale_y_continuous(labels=scales::percent)+labs(y='Observed zero proportion',x=NULL)
  plots$distribution<-save_plot(a/b+patchwork::plot_layout(guides='collect'),'02_distribution_zeros',height=8)
  main<-mc[mc$Activity=='All' & mc$FitWindow==mc$EvalWindow,]
  ml<-rbind(transform(main,Metric='RMSE',Error=RMSE),transform(main,Metric='MAE',Error=MAE))
  plots$accuracy<-save_plot(ggplot(ml,aes(Method,Error,fill=Method))+
    geom_boxplot(outlier.size=.25,na.rm=TRUE)+facet_grid(Metric+Day~FitWindow,scales='free_y')+
    scale_fill_manual(values=cols)+theme(axis.text.x=element_blank(),axis.ticks.x=element_blank())+
    labs(title='Accuracy across Monte Carlo masks',x=NULL,y='Steps per hidden hour',
      caption='Each box summarizes the same 200 masks. Missing failed-fit scores remain unavailable.'),
    '03_monte_carlo_accuracy',height=9)
  w<-wd[wd$Experiment=='bootstrap' & wd$Activity=='All' & wd$Metric=='RMSE',]
  plots$window<-save_plot(ggplot(w,aes(Method,Mean,color=Method))+
    geom_hline(yintercept=0,color='grey55')+geom_pointrange(aes(ymin=Lower,ymax=Upper),na.rm=TRUE)+
    facet_grid(Day~EvalWindow,scales='free_y')+scale_color_manual(values=cols)+
    theme(axis.text.x=element_blank(),axis.ticks.x=element_blank())+
    labs(title='Window-specific minus whole-day RMSE',x=NULL,y='Paired RMSE difference (steps)',
      caption='Points: bootstrap mean differences; bars: participant-bootstrap percentile 95% intervals, conditional on the primary mask.'),
    '04_fitting_window_effect',height=7)
  level<-mc[mc$Activity %in% c('Zero','LowPositive','ModeratePositive','HighPositive') &
    mc$FitWindow==mc$EvalWindow,]
  sums<-aggregate(MAE~Day+EvalWindow+Activity+Method,level,mean)
  plots$levels<-save_plot(ggplot(sums,aes(Activity,MAE,color=Method,group=Method))+
    geom_point(position=position_dodge(.5))+facet_grid(Day~EvalWindow,scales='free_y')+
    scale_color_manual(values=cols)+theme(axis.text.x=element_text(angle=25,hjust=1))+
    labs(title='Prediction errors by true activity level',x=NULL,y='Mean absolute error',
      caption='Low: 1–100 steps; moderate: 101–1000; high: >1000. Categories are prespecified, not fitted to heldout values.'),
    '05_activity_level_errors',height=7)
  prim<-primary[primary$FitWindow=='Whole_day' & primary$EvalWindow=='Whole_day',]
  scat<-do.call(rbind,lapply(names(cols),function(m)data.frame(prim[c('Day','Id','Hour','Truth')],Method=m,Prediction=prim[[m]])))
  plots$scatter<-save_plot(ggplot(scat,aes(Truth,Prediction,color=Method))+
    geom_abline(slope=1,intercept=0,color='grey50')+geom_point(alpha=.55,size=1,na.rm=TRUE)+
    facet_grid(Day~Method)+scale_color_manual(values=cols,guide='none')+
    labs(title='Original versus imputed values: primary mask, whole-day fit',x='Recorded steps',y='Predicted steps'),
    '06_original_imputed',height=6)
  # Deterministic example: first participant with any primary-mask heldout entries.
  trajectories<-do.call(rbind,lapply(days,function(d) {
    id<-sort(unique(prim$Id[prim$Day==d$day]))[1]; actual<-d$long[d$long$Id==id,]
    pred<-scat[scat$Id==id & scat$Day==d$day & scat$Method %in% c('Gaussian','Contaminated','Student_t'),]
    rbind(data.frame(Day=d$day,Id=id,Hour=actual$Hour,Value=actual$Value,Method='Original'),
          data.frame(Day=pred$Day,Id=pred$Id,Hour=pred$Hour,Value=pred$Prediction,Method=pred$Method))
  }))
  write_table(trajectories,file.path(root,'results','predictions','example_trajectories.csv'))
  plots$trajectories<-save_plot(ggplot(trajectories,aes(Hour,Value,color=Method))+
    geom_line(data=subset(trajectories,Method=='Original'),linewidth=.65)+
    geom_point(data=subset(trajectories,Method!='Original'),size=2,alpha=.8,na.rm=TRUE)+
    facet_grid(Day+Id~.)+scale_color_manual(values=c(cols,Original='#222222'))+
    scale_x_continuous(breaks=seq(0,23,3))+labs(title='Example participant trajectories',
      x='Hour at interval start',y='Steps',caption='Black line: original record. Colored points: predictions at masked hours only. Participant chosen by ID, not accuracy.'),
    '07_example_trajectories',height=7)
  mcs<-read_result('monte_carlo/monte_carlo_summary.csv')
  mcs<-mcs[mcs$Activity=='All' & mcs$FitWindow==mcs$EvalWindow & mcs$Metric=='RMSE',]
  bs<-boot[boot$Activity=='All' & boot$FitWindow==boot$EvalWindow & boot$Metric=='RMSE',]
  mcs$Source<-'Mask variability';bs$Source<-'Participant bootstrap (fixed mask)'
  combined<-rbind(mcs,bs)
  plots$uncertainty<-save_plot(ggplot(combined,aes(Method,Mean,color=Method))+
    geom_pointrange(aes(ymin=Lower,ymax=Upper),na.rm=TRUE)+facet_grid(Source+Day~EvalWindow,scales='free_y')+
    scale_color_manual(values=cols)+theme(axis.text.x=element_blank(),axis.ticks.x=element_blank())+
    labs(title='Two distinct sources of uncertainty',x=NULL,y='RMSE (steps)',
      caption='Mask bars: empirical central 95% range across masks. Bootstrap bars: participant percentile 95% interval under one fixed mask; estimands differ.'),
    '08_stability_uncertainty',height=9)
  invisible(plots)
}
