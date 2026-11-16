# Exact penalized EM / ECM for a common standardized covariance penalty:
# -(kappa/2){log|S| + tr(S^-1)}. This is a fixed positive-definite
# shrinkage target with covariance update (expected scatter+kappa I)/(n+kappa).
# It is not unpenalized maximum-likelihood EM.
fit_em <- function(raw,model,cfg) {
  raw<-as.matrix(raw); n<-nrow(raw); p<-ncol(raw)
  if(n<2L || any(colSums(!is.na(raw))<2L)) stop('Insufficient observed training values')
  center<-colMeans(raw,na.rm=TRUE); sc<-apply(raw,2,sd,na.rm=TRUE)
  sc[!is.finite(sc)|sc<1e-8]<-1
  z<-sweep(sweep(raw,2,center),2,sc,'/')
  groups<-split(seq_len(n),apply(is.na(z),1,paste0,collapse=''))
  mu<-rep(0,p); S<-diag(p); alpha<-.9; eta<-10; nu<-cfg$student_df
  kap<-cfg$covariance_penalty
  penalty<-function(S) -.5*kap*(as.numeric(determinant(S,logarithm=TRUE)$modulus)+sum(diag(chol2inv(chol(S)))))
  st<-conditional_state(z,mu,S,groups)
  ll<-observed_loglik(st,model,alpha,eta,nu)
  trace<-data.frame(Iteration=0,LogLikelihood=ll,Objective=ll+penalty(S))
  converged<-FALSE; monotone<-TRUE
  for(it in seq_len(cfg$max_iterations)) {
    w<-rep(1,n); bad<-rep(0,n)
    if(model=='Student_t') w<-(nu+st$q)/(nu+st$delta)
    if(model=='Contaminated') {
      logodds<-log(alpha/(1-alpha))+.5*(st$q*log(eta)-st$delta*(1-1/eta))
      good<-plogis(logodds); bad<-1-good; w<-good+bad/eta
    }
    mun<-colSums(st$m*w)/sum(w); D<-sweep(st$m,2,mun)
    V<-matrix(0,p,p)
    for(k in seq_along(groups)) V<-V+length(groups[[k]])*st$Cs[[k]]
    Sn<-(crossprod(D*sqrt(w))+V+kap*diag(p))/(n+kap); Sn<-(Sn+t(Sn))/2
    alphan<-alpha; etan<-eta
    if(model=='Contaminated') {
      alphan<-min(.995,max(.5,mean(1-bad)))
      inv<-chol2inv(chol(Sn)); md<-rowSums((D%*%inv)*D)
      numerator<-sum(bad*md)
      for(k in seq_along(groups)) numerator<-numerator+sum(bad[groups[[k]]])*eta*sum(inv*t(st$Cs[[k]]))
      etan<-min(1000,max(1.01,numerator/(p*sum(bad))))
    }
    stn<-conditional_state(z,mun,Sn,groups)
    lln<-observed_loglik(stn,model,alphan,etan,nu); obj<-lln+penalty(Sn)
    prev<-tail(trace$Objective,1)
    if(obj<prev-1e-7*(1+abs(prev))) {monotone<-FALSE; stop('Penalized objective decreased')}
    change<-max(abs(mun-mu),abs(Sn-S),abs(alphan-alpha),abs(log(etan/eta)))
    relative<-abs(obj-prev)/(1+abs(prev))
    trace<-rbind(trace,data.frame(Iteration=it,LogLikelihood=lln,Objective=obj))
    mu<-mun; S<-Sn; alpha<-alphan; eta<-etan; st<-stn
    if(relative<cfg$tolerance && change<sqrt(cfg$tolerance)) {converged<-TRUE; break}
  }
  list(mu=mu,S=S,center=center,scale=sc,alpha=alpha,eta=eta,nu=nu,
    converged=converged,iterations=it,trace=trace,monotone=monotone,
    condition=kappa(S),min_eigen=min(eigen(S,symmetric=TRUE,only.values=TRUE)$values))
}
gaussian_em <- function(z,cfg) fit_em(z,'Gaussian',cfg)
