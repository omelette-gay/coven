Get-VM "coven-testlab" | Get-VMNetworkAdapter | Connect-VMNetworkAdapter -SwitchName "VagrantSwitch"
