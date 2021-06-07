Configuration PowerSTIG_McAfee
{
    param(
        [Parameter()]
        [string]
        $TechnologyRole = "AntiVirus",

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
        if ( $null -eq $SkipRule -and $null -eq $Exception )
        {
            McAfee Baseline
            {
                TechnologyRole    = $TechnologyRole
            }
        }
        elseif ( $null -ne $SkipRule -and $null -eq $Exception )
        {
            McAfee Baseline
            {
                TechnologyRole    = $TechnologyRole
                Skiprule            = $SkipRule
            }
        }
        elseif ( $null -eq $SkipRule -and $null -ne $Exception )
        {
            McAfee Baseline
            {
                TechnologyRole    = $TechnologyRole
                Exception           = $Exception
            }
        }
        elseif ( $null -ne $SkipRule -and $null -ne $Exception )
        {
            McAfee Baseline
            {
                TechnologyRole    = $TechnologyRole
                Skiprule            = $SkipRule
                Exception           = $Exception
            }
        }
    }
    else
    {
        if ( $null -eq $SkipRule -and $null -eq $Exception )
        {
            McAfee Baseline
            {
                TechnologyRole    = $TechnologyRole
                OrgSettings         = $OrgSettings
            }
        }
        elseif ( $null -ne $SkipRule -and $null -eq $Exception )
        {
            McAfee Baseline
            {
                TechnologyRole    = $TechnologyRole
                OrgSettings         = $OrgSettings
                Skiprule            = $SkipRule
            }
        }
        elseif ( $null -eq $SkipRule -and $null -ne $Exception )
        {
            McAfee Baseline
            {
                TechnologyRole    = $TechnologyRole
                OrgSettings         = $OrgSettings
                Exception           = $Exception
            }
        }
        elseif ( $null -ne $SkipRule -and $null -ne $Exception )
        {
            McAfee Baseline
            {
                TechnologyRole    = $TechnologyRole
                OrgSettings         = $OrgSettings
                Skiprule            = $SkipRule
                Exception           = $Exception
            }
        }
    }

    foreach ( $rule in $SkipRule.Keys )
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
