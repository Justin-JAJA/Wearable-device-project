# Socket-free parallel execution on Windows; assign disjoint replicate shards.
a<-commandArgs(trailingOnly=FALSE);script<-sub('^--file=','',a[grepl('^--file=',a)])
root<-dirname(normalizePath(script));source(file.path(root,'R','setup.R'));load_project(root)
cfg<-yaml::read_yaml(file.path(root,'config.yml'));days<-readRDS(file.path(root,'data','processed','study_data.rds'))
args<-as.integer(commandArgs(trailingOnly=TRUE));shard<-args[1];workers<-args[2]
tasks<-c(lapply(seq_len(cfg$monte_carlo_repetitions),function(i)list(experiment='monte_carlo',replicate=i)),
 lapply(seq_len(cfg$bootstrap_repetitions),function(i)list(experiment='bootstrap',replicate=i)))
tasks<-tasks[seq.int(shard,length(tasks),by=workers)]
for(i in seq_along(tasks)) {
 run_task(tasks[[i]],root,days,cfg)
 if(i%%10==0 || i==length(tasks)) {cat('Shard',shard,':',i,'/',length(tasks),'complete\n');flush.console()}
}
