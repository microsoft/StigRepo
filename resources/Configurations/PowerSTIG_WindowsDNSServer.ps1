Configuration PowerSTIG_WindowsDnsServer
{
    param(
        [Parameter()]
        [string]
        $OsVersion,

        [Parameter()]
        [version]
        $StigVersion,

        [Parameter()]
        [hashtable]
        $Exception,

        [Parameter()]
        [string]
        $OrgSettings,

        [Parameter()]
        [string[]]
        $SkipRule = @("V-215652","V-215632")
    )

    Import-DSCResource -Module PowerSTIG
    $osVersion = "2012R2"
    if ( $null -eq $OrgSettings -or "" -eq $OrgSettings )
    {
        if ( ($null -eq $SkipRule) -and ($null -eq $Exception) )
        {
            WindowsDnsServer BaseLine
            {
                OsVersion   = $OSVersion
            }
        }
        elseif ($null -ne $SkipRule -and $null -eq $Exception)
        {
            WindowsDnsServer BaseLine
            {
                OsVersion   = $OSVersion
                SkipRule    = $SkipRule
            }
        }
        elseif ($null -eq $skiprule -and $null -ne $Exception)
        {
            WindowsDnsServer BaseLine
            {
                OsVersion   = $OSVersion
                Exception   = $Exception
            }
        }
        elseif ( ($null -ne $Exception ) -and ($null -ne $SkipRule) )
        {
            WindowsDnsServer Baseline
            {
                OsVersion   = $OSVersion
                Exception   = $Exception
                SkipRule    = $SkipRule
            }
        }
    }
    elseif ($null-ne $orgsettings)
    {
        if ( ($null -eq $SkipRule) -and ($null -eq $Exception) )
        {
            WindowsDnsServer BaseLine
            {
                OsVersion   = $OSVersion
                OrgSettings = $OrgSettings
            }
        }
        elseif ($null -ne $SkipRule -and $null -eq $exception)
        {
            WindowsDnsServer BaseLine
            {
                OsVersion   = $OSVersion
                OrgSettings = $OrgSettings
                SkipRule    = $SkipRule
            }
        }
        elseif ( $null -eq $skiprule -and $null -ne $Exception ) {
            WindowsDnsServer BaseLine
            {
                OsVersion   = $OSVersion
                OrgSettings = $OrgSettings
                Exception   = $Exception
            }
        }
        elseif ( ($null -ne $Exception ) -and ($null -ne $SkipRule) )
        {
            WindowsDnsServer Baseline
            {
                OsVersion   = $OSVersion
                OrgSettings = $OrgSettings
                Exception   = $Exception
                SkipRule    = $SkipRule
            }
        }
    }

    foreach($rule in $SkipRule.Keys)
    {
        Registry Exception_Rule
        {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\STIGExceptions\"
            ValueName = $rule
            ValueData = $(Get-Date -format "MMddyyyy")
            ValueType = "String"
            Force = $true
        }
    }
}