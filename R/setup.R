# Use installed user packages when Rscript has not included the user library.
user_library <- file.path(Sys.getenv('LOCALAPPDATA'), 'R', 'win-library',
                          paste(R.version$major, strsplit(R.version$minor, '.', fixed=TRUE)[[1]][1], sep='.'))
if (dir.exists(user_library)) .libPaths(c(user_library, .libPaths()))
profile_library <- file.path(Sys.getenv('USERPROFILE'),'AppData','Local','R','win-library',
                            paste(R.version$major,strsplit(R.version$minor,'.',fixed=TRUE)[[1]][1],sep='.'))
if (dir.exists(profile_library)) .libPaths(c(profile_library,.libPaths()))
options(stringsAsFactors=FALSE)
load_project <- function(root) {
  for (f in c('data_preparation','missingness_mcar','prediction','gaussian_em',
              'contaminated_normal_em','student_t_em','evaluation','monte_carlo','bootstrap'))
    source(file.path(root,'R',paste0(f,'.R')), local=.GlobalEnv)
}
write_table <- function(d, path) {
  dir.create(dirname(path), recursive=TRUE, showWarnings=FALSE)
  write.csv(d, path, row.names=FALSE, na='NA')
}
