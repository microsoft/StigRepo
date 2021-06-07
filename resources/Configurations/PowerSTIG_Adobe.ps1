Configuration PowerSTIG_Adobe
{
    param(

        [Parameter()]
        [string]
        $AdobeApp = "AcrobatReader",

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
            Adobe Baseline
            {
                AdobeApp = $AdobeApp
            }
        }
        elseif ( $null -ne $SkipRule -and $null -eq $Exception )
        {
            Adobe Baseline
            {
                AdobeApp    = $AdobeApp
                Skiprule    = $SkipRule
            }
        }
        elseif ( $null -eq $SkipRule -and $null -ne $Exception )
        {
            Adobe Baseline
            {
                AdobeApp    = $AdobeApp
                Exception   = $Exception
            }
        }
        elseif ( $null -ne $SkipRule -and $null -ne $Exception )
        {
            Adobe Baseline
            {
                AdobeApp    = $AdobeApp
                Skiprule    = $SkipRule
                Exception   = $Exception
            }
        }
    }
    else
    {
        if ( $null -eq $SkipRule -and $null -eq $Exception )
        {
            Adobe Baseline
            {
                AdobeApp    = $AdobeApp
                OrgSettings = $OrgSettings
            }
        }
        elseif ( $null -ne $SkipRule -and $null -eq $Exception )
        {
            Adobe Baseline
            {
                AdobeApp    = $AdobeApp
                OrgSettings = $OrgSettings
                Skiprule    = $SkipRule
            }
        }
        elseif ( $null -eq $SkipRule -and $null -ne $Exception )
        {
            Adobe Baseline
            {
                AdobeApp    = $AdobeApp
                OrgSettings = $OrgSettings
                Exception   = $Exception
            }
        }
        elseif ( $null -ne $SkipRule -and $null -ne $Exception )
        {
            Adobe Baseline
            {
                AdobeApp    = $AdobeApp
                OrgSettings = $OrgSettings
                Skiprule    = $SkipRule
                Exception   = $Exception
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
