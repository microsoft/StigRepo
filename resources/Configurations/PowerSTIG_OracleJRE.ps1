Configuration PowerSTIG_OracleJRE
{
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $ConfigPath,

        [Parameter(Mandatory = $true)]
        [string]
        $PropertiesPath,

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
        $SkipRule
    )

    Import-DscResource -ModuleName 'PowerStig'
    
    if ( $null -eq $OrgSettings -or "" -eq $OrgSettings )
    {
        if ( ($null -eq $SkipRule) -and ($null -eq $Exception) )
        {
            OracleJRE BaseLine
            {
                ConfigPath      = $ConfigPath
                PropertiesPath  = $PropertiesPath
            }
        }
        elseif ($null -ne $SkipRule -and $null -eq $Exception)
        {
            OracleJRE BaseLine
            {
                ConfigPath      = $ConfigPath
                PropertiesPath  = $PropertiesPath
                SkipRule        = $SkipRule
            }
        }
        elseif ($null -eq $skiprule -and $null -ne $Exception) {
            OracleJRE BaseLine
            {
                ConfigPath      = $ConfigPath
                PropertiesPath  = $PropertiesPath
                Exception       = $Exception
            }
        }
        elseif ( ($null -ne $Exception ) -and ($null -ne $SkipRule) )
        {
            OracleJRE Baseline
            {
                ConfigPath      = $ConfigPath
                PropertiesPath  = $PropertiesPath
                Exception       = $Exception
                SkipRule        = $SkipRule
            }
        }
    }
    else
    {
        if ( ($null -eq $SkipRule) -and ($null -eq $Exception) )
        {
            OracleJRE BaseLine
            {
                ConfigPath      = $ConfigPath
                PropertiesPath  = $PropertiesPath
                OrgSettings     = $OrgSettings
            }
        }
        elseif ($null -ne $SkipRule -and $null -eq $exception)
        {
            OracleJRE BaseLine
            {
                ConfigPath      = $ConfigPath
                PropertiesPath  = $PropertiesPath
                OrgSettings     = $OrgSettings
                SkipRule        = $SkipRule
            }
        }
        elseif ( $null -eq $skiprule -and $null -ne $Exception ) {
            OracleJRE BaseLine
            {
                ConfigPath      = $ConfigPath
                PropertiesPath  = $PropertiesPath
                OrgSettings     = $OrgSettings
                Exception       = $Exception
            }
        }
        elseif ( ($null -ne $Exception ) -and ($null -ne $SkipRule) )
        {
            OracleJRE Baseline
            {
                ConfigPath      = $ConfigPath
                PropertiesPath  = $PropertiesPath
                OrgSettings     = $OrgSettings
                Exception       = $Exception
                SkipRule        = $SkipRule
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
