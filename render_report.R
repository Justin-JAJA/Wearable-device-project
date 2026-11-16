a<-commandArgs(trailingOnly=FALSE);script<-sub('^--file=','',a[grepl('^--file=',a)])
root<-dirname(normalizePath(script));source(file.path(root,'R','setup.R'));load_project(root)
source(file.path(root,'R','visualization.R'))
if(!nzchar(Sys.getenv('RSTUDIO_PANDOC'))) {
  candidates<-c(file.path(Sys.getenv('ProgramFiles'),'RStudio/resources/app/bin/quarto/bin/tools'),
                file.path(Sys.getenv('USERPROFILE'),'AppData/Local/Programs/RStudio/resources/app/bin/quarto/bin/tools'))
  found<-candidates[file.exists(file.path(candidates,'pandoc.exe'))]
  if(length(found)) Sys.setenv(RSTUDIO_PANDOC=found[1])
}
if('--refresh-figures' %in% commandArgs(trailingOnly=TRUE)) make_figures(root)
Sys.setenv(EM_ACTIVITY_ROOT=root)
rmarkdown::render(file.path(root,'report','EM_Activity_Research_Report.Rmd'),
                  envir=new.env(),knit_root_dir=root,quiet=TRUE)
# Record exact versions used without installing or moving the user's libraries.
packages<-c('readxl','yaml','rmarkdown','knitr','ggplot2','plotly','DT','crosstalk','patchwork','scales','jsonlite','renv')
deps<-character();queue<-packages
while(length(queue)) {
  p<-queue[1];queue<-queue[-1]
  if(p=='R' || p %in% deps) next
  desc<-as.list(read.dcf(file.path(find.package(p),'DESCRIPTION'))[1,])
  if(identical(desc$Priority,'base')) next
  deps<-c(deps,p)
  fields<-unlist(desc[c('Depends','Imports','LinkingTo')]);fields<-fields[!is.na(fields)]
  child<-trimws(gsub('\\s*\\([^)]*\\)','',unlist(strsplit(paste(fields,collapse=','),','))))
  queue<-unique(c(queue,child[nzchar(child) & !child %in% c('R',deps)]))
}
records<-setNames(lapply(sort(deps),function(p) {
  desc<-as.list(read.dcf(file.path(find.package(p),'DESCRIPTION'))[1,])
  list(Package=p,Version=desc$Version,Source='Repository',
       Repository=if(is.null(desc$Repository)||is.na(desc$Repository))'CRAN'else desc$Repository)
}),sort(deps))
lock<-list(R=list(Version=as.character(getRversion()),Repositories=list(
  list(Name='CRAN',URL='https://cloud.r-project.org'))),Packages=records)
jsonlite::write_json(lock,file.path(root,'renv.lock'),pretty=TRUE,auto_unbox=TRUE)
cat('Report and figures rendered.\n')
