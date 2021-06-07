Configuration PowerSTIG_WebServer
{

    param(
        [Parameter(Mandatory = $true)]
        [version]
        $IISVersion,

        [Parameter(Mandatory = $true)]
        [string]
        $LogPath,

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
            IISServer Baseline
            {
                IISVersion      = $IISVersion
                LogPath         = $LogPath
            }
        }
        elseif ( $null -ne $SkipRule -and $null -eq $Exception )
        {
            IISServer Baseline
            {
                IISVersion      = $IisVersion
                LogPath         = $LogPath
                Skiprule        = $SkipRule
            }
        }
        elseif ( $null -eq $SkipRule -and $null -ne $Exception )
        {
            IISServer Baseline
            {
                IISVersion      = $IisVersion
                LogPath         = $LogPath
                Exception       = $Exception
            }
        }
        elseif ( $null -ne $SkipRule -and $null -ne $Exception )
        {
            IISServer Baseline
            {
                IISVersion      = $IisVersion
                LogPath         = $LogPath
                Skiprule        = $SkipRule
                Exception       = $Exception
            }
        }
    }
    else
    {
        if ( $null -eq $SkipRule -and $null -eq $Exception )
        {
            IISServer Baseline
            {
                IISVersion      = $IisVersion
                LogPath         = $LogPath
                OrgSettings     = $OrgSettings
            }
        }
        elseif ( $null -ne $SkipRule -and $null -eq $Exception )
        {
            IISServer Baseline
            {
                IISVersion      = $IisVersion
                LogPath         = $LogPath
                OrgSettings     = $OrgSettings
                Skiprule        = $SkipRule
            }
        }
        elseif ( $null -eq $SkipRule -and $null -ne $Exception )
        {
            IISServer Baseline
            {
                IISVersion      = $IisVersion
                LogPath         = $LogPath
                OrgSettings     = $OrgSettings
                Exception       = $Exception
            }
        }
        elseif ( $null -ne $SkipRule -and $null -ne $Exception )
        {
            IISServer Baseline
            {
                IISVersion      = $IisVersion
                LogPath         = $LogPath
                OrgSettings     = $OrgSettings
                Skiprule        = $SkipRule
                Exception       = $Exception
            }
        }
    }

    foreach($rule in $SkipRule.Keys)
    {
        Registry Exception_Rule
        {
            Ensure      = "Present"
            Key         = "HKEY_LOCAL_MACHINE\SOFTWARE\STIGExceptions\"
            ValueName   = $rule
            ValueData   = $(Get-Date -format "MMddyyyy")
            ValueType   = "String"
            Force       = $true
        }
    }
}
