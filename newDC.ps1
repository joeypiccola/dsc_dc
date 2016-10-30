Configuration BuildTest01 {
    param (
        [Parameter(Mandatory)] 
        [pscredential]$safemodeCred, 
        
        [Parameter(Mandatory)] 
        [pscredential]$domainCred
    )
 
    Import-DscResource -Module xActiveDirectory, xComputerManagement, xNetworking, xPendingReboot
 
    Node $AllNodes.NodeName {

        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }

        xPendingReboot checkReboot
        {
            name = "do we need to reboot, if so do it!"
        }

        xComputer SetName
        { 
            Name = $Node.MachineName 
        }

        xIPAddress SetIP
        {
            IPAddress      = $Node.IPAddress
            InterfaceAlias = $Node.InterfaceAlias
            SubnetMask     = $Node.SubnetMask
            AddressFamily  = $Node.AddressFamily
        }

        xDefaultGatewayAddress setGateway
        {
            AddressFamily = $Node.AddressFamily
            InterfaceAlias = $Node.InterfaceAlias
            Address = '10.0.2.2'
            DependsOn = '[xIPAddress]SetIP'
        }

        xDNSServerAddress SetDNS
        {
            Address        = $Node.DNSAddress
            InterfaceAlias = $Node.InterfaceAlias
            AddressFamily  = $Node.AddressFamily
        }

        WindowsFeature ADDSInstall
        {
            Ensure = 'Present'
            Name   = 'AD-Domain-Services'
        }

        xADDomain FirstDC
        {
            DomainName                    = $Node.DomainName
            DomainAdministratorCredential = $domainCred
            SafemodeAdministratorPassword = $safemodeCred
            DependsOn                     = '[xComputer]SetName', '[xIPAddress]SetIP', '[WindowsFeature]ADDSInstall'
        }
    }
}


$ConfigData = @{
    AllNodes = @(
        @{
            NodeName                    = 'localhost'
            MachineName                 = 'dc01'
            DomainName                  = 'testDomain.com'
            IPAddress                   = '10.0.2.5'
            InterfaceAlias              = 'Ethernet'
            SubnetMask                  = '24'
            AddressFamily               = 'IPv4'
            DNSAddress                  = '127.0.0.1', '10.0.2.2'
            PSDscAllowPlainTextPassword = $true
        }
    )
}


$secpasswd = ConvertTo-SecureString 'V@grant!2016' -AsPlainText -Force
$safeMCred = New-Object System.Management.Automation.PSCredential ('notused', $secpasswd)
 
$secpasswd = ConvertTo-SecureString 'vagrant' -AsPlainText -Force
$startCred = New-Object System.Management.Automation.PSCredential ('vagrant', $secpasswd)

$secpasswd = ConvertTo-SecureString 'V@grant!2016' -AsPlainText -Force
$domAdCred = New-Object System.Management.Automation.PSCredential ('notused', $secpasswd)


BuildTest01 -ConfigurationData $ConfigData -safemodeCred $safeMCred -domaincred $domAdCred

Set-DscLocalConfigurationManager -path .\BuildTest01 -Credential $startCred -ComputerName localhost -Verbose

Start-DscConfiguration -Wait -Path .\BuildTest01 -Credential $startCred -Verbose -Force -ComputerName localhost