Configuration JoinDomain {
    param (
        [Parameter(Mandatory = $true)]
        [String] $DomainName,

        [Parameter(Mandatory = $true)]
        [String] $OUPath,

        [Parameter(Mandatory = $true)]
        [String] $UserName,

        [Parameter(Mandatory = $true)]
        [String] $Password
    )

    #Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node localhost {
        Script JoinDomain {
            GetScript = { @{ Result = 'NA' } }
            SetScript = {
                $secpasswd = ConvertTo-SecureString $using:Password -AsPlainText -Force
                $creds = New-Object System.Management.Automation.PSCredential ($using:UserName, $secpasswd)
                Add-Computer -DomainName $using:DomainName -OUPath $using:OUPath -Credential $creds -Restart
            }
            TestScript = {
                $env:COMPUTERNAME -notlike "*$using:DomainName"
            }
        }
    }
}
