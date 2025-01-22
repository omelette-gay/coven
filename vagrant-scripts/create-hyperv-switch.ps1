# make sure routing is enabled
Set-ItemProperty -Path HKLM:\system\CurrentControlSet\services\Tcpip\Parameters -Name IpEnableRouter -Value 1
Set-Service -Name RemoteAccess -StartupType Automatic

If ("VagrantSwitch" -in (Get-VMSwitch | Select-Object -ExpandProperty Name) -eq $FALSE) {
    'Creating Internal-only switch named "VagrantSwitch" on Windows Hyper-V host...'

    New-VMSwitch -SwitchName "VagrantSwitch" -SwitchType Internal
}
else {
    '"VagrantSwitch" for static IP configuration already exists; skipping'
}

If ("192.168.57.1" -in (Get-NetIPAddress | Select-Object -ExpandProperty IPAddress) -eq $FALSE) {
    'Registering new IP address 192.168.57.1 on Windows Hyper-V host...'

    New-NetIPAddress -IPAddress 192.168.57.1 -PrefixLength 24 -InterfaceAlias "vEthernet (VagrantSwitch)"
}
else {
    '"192.168.57.1" for static IP configuration already registered; skipping'
}

If ("192.168.57.0/24" -in (Get-NetNAT | Select-Object -ExpandProperty InternalIPInterfaceAddressPrefix) -eq $FALSE) {
    'Registering new NAT adapter for 192.168.57.0/24 on Windows Hyper-V host...'

    New-NetNAT -Name "VagrantNetwork" -InternalIPInterfaceAddressPrefix 192.168.57.0/24
}
else {
    '"192.168.57.0/24" for static IP configuration already registered; skipping'
}
