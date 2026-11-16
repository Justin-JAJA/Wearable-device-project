# Conditional Gaussian location and Schur covariance. Scale-mixture conditional
# locations coincide, but their second moments and latent weights do not.
conditional_state <- function(z,mu,S,groups) {
  n<-nrow(z); p<-ncol(z); m<-z; Cs<-vector('list',length(groups))
  delta<-ld<-q<-numeric(n)
  for(k in seq_along(groups)) {
    ix<-groups[[k]]; O<-which(!is.na(z[ix[1],])); M<-which(is.na(z[ix[1],]))
    C<-matrix(0,p,p); q[ix]<-length(O)
    if(length(O)) {
      U<-chol(S[O,O,drop=FALSE]); inv<-chol2inv(U)
      D<-sweep(z[ix,O,drop=FALSE],2,mu[O]); delta[ix]<-rowSums((D%*%inv)*D)
      ld[ix]<-2*sum(log(diag(U)))
      if(length(M)) {
        B<-S[M,O,drop=FALSE]%*%inv
        m[ix,M]<-sweep(D%*%t(B),2,mu[M],'+')
        C[M,M]<-S[M,M,drop=FALSE]-B%*%S[O,M,drop=FALSE]
      }
    } else {m[ix,]<-matrix(mu,length(ix),p,byrow=TRUE); C<-S}
    Cs[[k]]<-(C+t(C))/2
  }
  list(m=m,Cs=Cs,delta=pmax(delta,0),ld=ld,q=q)
}
observed_loglik <- function(st,model,alpha,eta,nu) {
  a<--.5*(st$q*log(2*pi)+st$ld+st$delta)
  if(model=='Contaminated') {
    b<-log1p(-alpha)-.5*(st$q*log(2*pi)+st$ld+st$q*log(eta)+st$delta/eta)
    a<-log(alpha)+a; top<-pmax(a,b); a<-top+log(exp(a-top)+exp(b-top))
  }
  if(model=='Student_t') a<-lgamma((nu+st$q)/2)-lgamma(nu/2)-
    .5*(st$q*log(nu*pi)+st$ld)-.5*(nu+st$q)*log1p(st$delta/nu)
  sum(a)
}
predict_em <- function(fit,z) {
  zz<-sweep(sweep(z,2,fit$center),2,fit$scale,'/')
  groups<-split(seq_len(nrow(zz)),apply(is.na(zz),1,paste0,collapse=''))
  m<-conditional_state(zz,fit$mu,fit$S,groups)$m
  pred<-sweep(sweep(m,2,fit$scale,'*'),2,fit$center,'+')
  pred[!is.na(z)]<-z[!is.na(z)]
  pred
}
