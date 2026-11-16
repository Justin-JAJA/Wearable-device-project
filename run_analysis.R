args<-commandArgs(trailingOnly=FALSE)
script<-sub('^--file=','',args[grepl('^--file=',args)])
root<-dirname(normalizePath(script)); source(file.path(root,'R','setup.R'));load_project(root)
cfg<-yaml::read_yaml(file.path(root,'config.yml'))
mode<-commandArgs(trailingOnly=TRUE)
for(p in c('data/raw','data/processed','results/descriptive','results/missingness',
 'results/predictions','results/monte_carlo','results/bootstrap','results/model_comparisons',
 'results/checkpoints','results/figures','report/assets','qa')) dir.create(file.path(root,p),recursive=TRUE,showWarnings=FALSE)
for(f in unlist(cfg$sources)) {
  target<-file.path(root,'data','raw',f)
  if(!file.exists(target)) stop(paste('Missing input:', target, '- see data/README.md'))
}
# Reject stale checkpoints if code, inputs, or scientific settings change.
analysis_files<-list.files(file.path(root,'R'),full.names=TRUE)
analysis_files<-analysis_files[basename(analysis_files)!='visualization.R']
input_files<-c(file.path(root,'config.yml'),analysis_files,
               list.files(file.path(root,'data','raw'),full.names=TRUE))
manifest<-tools::md5sum(input_files); mp<-file.path(root,'results','analysis_manifest.rds')
if(file.exists(mp) && !identical(readRDS(mp),manifest) &&
   length(list.files(file.path(root,'results','checkpoints'),pattern='\\.rds$')))
  stop('Analysis code/config/input changed: archive existing checkpoints before rerunning.')
saveRDS(manifest,mp)
days<-prepare_data(root,cfg)
if('prepare' %in% mode) quit(status=0)
tasks<-c(lapply(seq_len(cfg$monte_carlo_repetitions),function(i)list(experiment='monte_carlo',replicate=i)),
         lapply(seq_len(cfg$bootstrap_repetitions),function(i)list(experiment='bootstrap',replicate=i)))
if('pilot' %in% mode) tasks<-list(tasks[[1]],tasks[[cfg$monte_carlo_repetitions+1]])
if('collect' %in% mode) tasks<-list()
pending<-Filter(function(t)!file.exists(file.path(root,'results','checkpoints',sprintf('%s_%04d.rds',t$experiment,t$replicate))),tasks)
if(length(pending)) {
  cat('Pending paired-date replicates:',length(pending),'workers:',cfg$workers,'\n');flush.console()
  started<-proc.time()[3]
  for(task in pending) {
    run_task(task,root,days,cfg)
    cat(task$experiment,task$replicate,'completed\n');flush.console()
  }
  cat('Elapsed seconds:',proc.time()[3]-started,'\n')
}
collect_results(root,cfg)
writeLines(capture.output(sessionInfo()),file.path(root,'results','sessionInfo.txt'))
cat('Results collected.\n')
