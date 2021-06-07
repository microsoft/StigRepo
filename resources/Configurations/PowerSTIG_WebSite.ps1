Configuration PowerSTIG_WebSite
{

    param(
        [Parameter(Mandatory = $true)]
        [version]
        $IisVersion,

        [Parameter()]
        [string[]]
        $WebsiteName,

        [Parameter()]
        [string[]]
        $WebAppPool,

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

    Import-DscResource -Modulename 'PowerStig'

    if ( $null -eq $OrgSettings -or "" -eq $OrgSettings )
    {
        if ( $null -eq $SkipRule -and $null -eq $Exception )
        {
            IISSite Baseline
            {
                IISVersion      = $IISVersion
                WebsiteName     = $WebsiteName
                WebAppPool      = $WebAppPool
            }
        }
        elseif ( $null -ne $SkipRule -and $null -eq $Exception )
        {
            IISSite Baseline
            {
                IISVersion      = $IisVersion
                WebsiteName     = $WebsiteName
                WebAppPool      = $WebAppPool
                Skiprule        = $SkipRule
            }
        }
        elseif ( $null -eq $SkipRule -and $null -ne $Exception )
        {
            IISSite Baseline
            {
                IISVersion      = $IisVersion
                WebsiteName     = $WebsiteName
                WebAppPool      = $WebAppPool
                Exception       = $Exception
            }
        }
        elseif ( $null -ne $SkipRule -and $null -ne $Exception )
        {
            IISSite Baseline
            {
                IISVersion      = $IisVersion
                WebsiteName     = $WebsiteName
                WebAppPool      = $WebAppPool
                Skiprule        = $SkipRule
                Exception       = $Exception
            }
        }
    }
    else
    {
        if ( $null -eq $SkipRule -and $null -eq $Exception )
        {
            IISSite Baseline
            {
                IISVersion      = $IisVersion
                WebsiteName     = $WebsiteName
                WebAppPool      = $WebAppPool
                OrgSettings     = $OrgSettings
            }
        }
        elseif ( $null -ne $SkipRule -and $null -eq $Exception )
        {
            IISSite Baseline
            {
                IISVersion      = $IisVersion
                WebsiteName     = $WebsiteName
                WebAppPool      = $WebAppPool
                OrgSettings     = $OrgSettings
                Skiprule        = $SkipRule
            }
        }
        elseif ( $null -eq $SkipRule -and $null -ne $Exception )
        {
            IISSite Baseline
            {
                IISVersion      = $IisVersion
                WebsiteName     = $WebsiteName
                WebAppPool      = $WebAppPool
                OrgSettings     = $OrgSettings
                Exception       = $Exception
            }
        }
        elseif ( $null -ne $SkipRule -and $null -ne $Exception )
        {
            IISSite Baseline
            {
                IISVersion      = $IisVersion
                WebsiteName     = $WebsiteName
                WebAppPool      = $WebAppPool
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
