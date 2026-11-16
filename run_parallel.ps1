$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$rCommand = Get-Command Rscript -ErrorAction SilentlyContinue
$rExecutable = if ($rCommand) { $rCommand.Source } else { Join-Path $env:USERPROFILE 'AppData\Local\Programs\R\R-4.5.1\bin\Rscript.exe' }
if (-not (Test-Path -LiteralPath $rExecutable)) { throw 'Set Rscript on PATH before running.' }
& $rExecutable (Join-Path $projectRoot 'run_analysis.R') prepare
if ($LASTEXITCODE -ne 0) { throw 'Preparation failed.' }
$workerCount = [int]((Get-Content -LiteralPath (Join-Path $projectRoot 'config.yml') | Select-String '^workers:').Line.Split(':')[1].Trim())
$workerScript = Join-Path $projectRoot 'run_worker.R'
$processes = @()
for ($shard = 1; $shard -le $workerCount; $shard++) {
  $processes += Start-Process -FilePath $rExecutable -ArgumentList @('"' + $workerScript + '"', "$shard", "$workerCount") -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru
}
foreach ($process in $processes) {
  $process.WaitForExit()
  if ($process.ExitCode -ne 0) { throw 'A worker failed; completed checkpoints remain available.' }
}
& $rExecutable (Join-Path $projectRoot 'run_analysis.R') collect
if ($LASTEXITCODE -ne 0) { throw 'Collection failed.' }
