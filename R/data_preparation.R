prepare_data <- function(root, cfg) {
  hours <- sprintf('Hour%02d',0:23)
  days <- lapply(names(cfg$sources), function(day) {
    f <- file.path(root,'data','raw',cfg$sources[[day]])
    header <- day=='Weekday'
    d <- as.data.frame(readxl::read_excel(f, col_names=header,
                          .name_repair='minimal', col_types='text'))
    stopifnot(ncol(d)==28L)
    if (!header) names(d) <- c('Participant','Id','Date','Weekend',hours)
    stopifnot(identical(names(d),c('Participant','Id','Date','Weekend',hours)))
    d$Id <- sub('\\.0$','',d$Id)
    # Date cells can be ISO dates or Excel serials when imported as text.
    dates <- suppressWarnings(as.numeric(d$Date))
    d$Date <- ifelse(is.finite(dates),as.character(as.Date(dates,origin='1899-12-30')),substr(d$Date,1,10))
    stopifnot(length(unique(d$Date))==1L, !anyDuplicated(d$Id), !anyNA(d$Id))
    expected_weekend <- as.POSIXlt(as.Date(d$Date))$wday %in% c(0,6)
    stopifnot(all(as.integer(d$Weekend)==as.integer(expected_weekend)),
              all(expected_weekend==(day=='Weekend')))
    x <- sapply(d[hours],as.numeric)
    stopifnot(all(is.na(x) | (is.finite(x) & x>=0 & x==floor(x))))
    storage.mode(x)<-'double'; rownames(x)<-d$Id
    coordinates <- expand.grid(row=seq_len(nrow(x)),hour=0:23)
    long <- data.frame(Id=d$Id[coordinates$row],Date=d$Date[coordinates$row],
                       Day=day,Hour=coordinates$hour,Value=as.vector(x),
                       OriginallyMissing=as.vector(is.na(x)))
    write_table(long,file.path(root,'data','processed',paste0(tolower(day),'_observations.csv')))
    list(x=x,meta=d[c('Participant','Id','Date','Weekend')],day=day,long=long)
  }); names(days)<-names(cfg$sources)
  audit <- do.call(rbind,lapply(days,function(d) data.frame(Day=d$day,
    Date=d$meta$Date[1],Participants=nrow(d$x),Intervals=ncol(d$x),
    Observed=sum(!is.na(d$x)),OriginalMissing=sum(is.na(d$x)),
    Zero=sum(d$x==0,na.rm=TRUE),CompleteMatrixRank=if(!anyNA(d$x)) qr(scale(d$x,scale=FALSE))$rank else NA)))
  write_table(audit,file.path(root,'results','descriptive','data_audit.csv'))
  ids <- sort(unique(unlist(lapply(days,function(d)d$meta$Id))))
  linkage <- data.frame(Id=ids)
  for(day in names(days)) linkage[[day]]<-ids %in% days[[day]]$meta$Id
  write_table(linkage,file.path(root,'data','processed','participant_linkage.csv'))
  write_table(data.frame(UniqueParticipants=nrow(linkage),
    LinkedParticipants=sum(rowSums(as.matrix(linkage[-1]))==length(days))),
    file.path(root,'results','descriptive','participant_counts.csv'))
  desc <- do.call(rbind,lapply(days,function(d) do.call(rbind,lapply(names(cfg$windows),function(w) {
    h<-window_hours(cfg,w); v<-as.vector(d$x[,h+1L,drop=FALSE]); v<-v[!is.na(v)]; pos<-v[v>0]
    q<-if(length(pos)) quantile(pos,c(.25,.5,.75,.95),names=FALSE) else rep(NA,4)
    data.frame(Day=d$day,Window=w,Observed=length(v),Missing=sum(is.na(d$x[,h+1L,drop=FALSE])),
      ZeroProportion=mean(v==0),PositiveProportion=mean(v>0),Mean=mean(v),Median=median(v),SD=sd(v),
      PositiveQ25=q[1],PositiveMedian=q[2],PositiveQ75=q[3],PositiveQ95=q[4],
      Skewness=if(sd(v)>0) mean((v-mean(v))^3)/mean((v-mean(v))^2)^1.5 else NA,
      HighCount=sum(v>cfg$high_positive_min),HighProportion=mean(v>cfg$high_positive_min))
  }))))
  write_table(desc,file.path(root,'results','descriptive','window_activity_summary.csv'))
  saveRDS(days,file.path(root,'data','processed','study_data.rds'))
  days
}
window_hours <- function(cfg,w) seq.int(cfg$windows[[w]][1],cfg$windows[[w]][2]-1L)
