make_mask <- function(x,seed,fraction) {
  set.seed(seed)
  eligible<-which(!is.na(x))
  hidden<-sort(sample(eligible,ceiling(fraction*length(eligible)),replace=FALSE))
  z<-x; z[hidden]<-NA_real_
  stopifnot(!anyNA(x[hidden]),identical(z[-hidden],x[-hidden]))
  list(z=z,hidden=hidden,seed=seed)
}
mask_coordinates <- function(d,m,replicate,cfg) {
  ij<-arrayInd(m$hidden,dim(d$x)); h<-ij[,2]-1L
  out<-data.frame(Replicate=replicate,Seed=m$seed,Day=d$day,
    Id=d$meta$Id[ij[,1]],Date=d$meta$Date[ij[,1]],Row=ij[,1],Hour=h,Truth=d$x[m$hidden])
  for(w in names(cfg$windows)) out[[w]]<-h %in% window_hours(cfg,w)
  out
}
