#!/usr/bin/env powershell.exe

$VagrantBin = "C:\Program Files\Vagrant\bin\vagrant.exe"
$VagrantArgs = $args -join ' '
$CurrentDir = $ExecutionContext.SessionState.Path.CurrentFileSystemLocation.Path.Replace("'", "''")

$EnvInject = ""
if ($env:VAGRANT_HOME) {
    $EnvInject += "`$env:VAGRANT_HOME = '$($env:VAGRANT_HOME.Replace("'", "''"))'; "
}
if ($env:VAGRANT_DOTFILE_PATH) {
    $EnvInject += "`$env:VAGRANT_DOTFILE_PATH = '$($env:VAGRANT_DOTFILE_PATH.Replace("'", "''"))'; "
}

$ElevatedCommand = "Set-Location '$CurrentDir'; $EnvInject & '$VagrantBin' $VagrantArgs"

Start-Process powershell.exe -Verb RunAs -ArgumentList "-Command", $ElevatedCommand
