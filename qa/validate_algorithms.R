args<-commandArgs(trailingOnly=FALSE); script<-sub('^--file=','',args[grepl('^--file=',args)])
root<-dirname(dirname(normalizePath(script)))
source(file.path(root,'R','setup.R'));load_project(root)
cfg<-yaml::read_yaml(file.path(root,'config.yml')); checks<-list()
check<-function(name,value) {stopifnot(isTRUE(value));checks[[length(checks)+1L]]<<-data.frame(Check=name,Passed=TRUE)}
# Known conditional moments with one missing component.
z<-matrix(c(2,NA),1); groups<-list(1L)
st<-conditional_state(z,c(0,0),matrix(c(1,.5,.5,1),2),groups)
check('Conditional Gaussian mean',abs(st$m[1,2]-1)<1e-12)
check('Conditional Schur variance',abs(st$Cs[[1]][2,2]-.75)<1e-12)
check('Observed Mahalanobis distance',abs(st$delta-4)<1e-12)
# No observed coordinates: latent scale expected weight is exactly one.
empty<-conditional_state(matrix(NA_real_,1,2),c(1,2),diag(2),list(1L))
check('All-missing row location',identical(as.numeric(empty$m),c(1,2)))
check('Student latent scale prior for empty row',(cfg$student_df+empty$q)/(cfg$student_df+empty$delta)==1)
# One complete-data EM update has an analytic solution under the shared penalty.
set.seed(423); raw<-cbind(rnorm(80),rnorm(80)*2+.7)
c1<-cfg;c1$max_iterations<-1L
zz<-scale(raw); n<-nrow(zz); p<-ncol(zz); k<-cfg$covariance_penalty
f<-fit_em(raw,'Gaussian',c1)
check('Gaussian penalized M-step',max(abs(f$S-(crossprod(zz)+k*diag(p))/(n+k)))<1e-12)
ft<-fit_em(raw,'Student_t',c1); w<-(cfg$student_df+p)/(cfg$student_df+rowSums(zz^2))
mu<-colSums(zz*w)/sum(w); D<-sweep(zz,2,mu)
check('Student complete-data latent weights',max(abs(ft$mu-mu))<1e-12)
check('Student penalized covariance',max(abs(ft$S-(crossprod(D*sqrt(w))+k*diag(p))/(n+k)))<1e-12)
fc<-fit_em(raw,'Contaminated',c1)
tau<-plogis(log(.9/.1)+.5*(p*log(10)-rowSums(zz^2)*.9)); w<-tau+(1-tau)/10
mu<-colSums(zz*w)/sum(w); D<-sweep(zz,2,mu)
Sn<-(crossprod(D*sqrt(w))+k*diag(p))/(n+k)
eta<-sum((1-tau)*rowSums((D%*%solve(Sn))*D))/(p*sum(1-tau))
check('Contaminated ECM location',max(abs(fc$mu-mu))<1e-12)
check('Contaminated ECM covariance',max(abs(fc$S-Sn))<1e-12)
check('Contaminated ECM inflation',abs(fc$eta-min(1000,max(1.01,eta)))<1e-12)
# Missing-data second moments: independently integrate conditional draws.
set.seed(98); B<-150000L; u<-rgamma(B,(5+1)/2,rate=(5+4)/2)
ym<-rnorm(B,1,sqrt(.75/u))
check('Student missing-data weighted second moment',abs(mean(u*ym^2)-((6/9)*1^2+.75))<.025)
set.seed(99); bad_draw<-rnorm(B,1,sqrt(10*.75))
check('Contaminated missing-data component moment',abs(mean(bad_draw^2)-(1+10*.75))<.1)
masked<-make_mask(raw,321,.1)
check('Mask reproducibility',identical(masked,make_mask(raw,321,.1)))
check('Fixed-size MCAR count',length(masked$hidden)==ceiling(.1*length(raw)))
raw_na<-raw;raw_na[1,1]<-NA
check('Preexisting missing excluded',!1L %in% make_mask(raw_na,321,.1)$hidden)
for(m in c('Gaussian','Contaminated','Student_t')) {
  fit<-fit_em(masked$z,m,cfg); p<-predict_em(fit,masked$z)
  check(paste(m,'converged on synthetic missing data'),fit$converged)
  check(paste(m,'monotone penalized objective'),all(diff(fit$trace$Objective)>=-1e-7))
  check(paste(m,'positive definite'),fit$min_eigen>0)
  check(paste(m,'observed values preserved'),identical(p[!is.na(masked$z)],masked$z[!is.na(masked$z)]))
}
check('Daytime boundary',identical(window_hours(cfg,'Daytime'),9:17))
check('Evening boundary',identical(window_hours(cfg,'Evening'),18:23))
check('Nighttime boundary',identical(window_hours(cfg,'Nighttime'),0:5))
write_table(do.call(rbind,checks),file.path(root,'qa','algorithm_checks.csv'))
cat(length(checks),'algorithm checks passed\n')
