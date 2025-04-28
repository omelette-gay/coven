#!/usr/bin/env powershell.exe

If ($args) {
    Start-Process -FilePath "vagrant.exe" -Verb RunAs -ArgumentList $args
} else {
    Start-Process -FilePath "vagrant.exe" -Verb RunAs
}
