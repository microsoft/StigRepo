Configuration PowerSTIG_Office2016_Powerpoint
{
    param(
        [Parameter()]
        [string]
        $OfficeApp = "PowerPoint2016",

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
            Office BaseLine
            {
                OfficeApp    = $OfficeApp
            }
        }
        elseif ($null -ne $SkipRule -and $null -eq $Exception)
        {
            Office BaseLine
            {
                OfficeApp   = $OfficeApp
                SkipRule    = $SkipRule
            }
        }
        elseif ($null -eq $skiprule -and $null -ne $Exception) {
            Office BaseLine
            {
                OfficeApp   = $OfficeApp
                Exception   = $Exception
            }
        }
        elseif ( ($null -ne $Exception ) -and ($null -ne $SkipRule) )
        {
            Office Baseline
            {
                OfficeApp   = $OfficeApp
                Exception   = $Exception
                SkipRule    = $SkipRule
            }
        }
    }
    else
    {
        if ( ($null -eq $SkipRule) -and ($null -eq $Exception) )
        {
            Office BaseLine
            {
                OfficeApp   = $OfficeApp
                OrgSettings = $OrgSettings
            }
        }
        elseif ($null -ne $SkipRule -and $null -eq $Exception)
        {
            Office BaseLine
            {
                OfficeApp   = $OfficeApp
                OrgSettings = $OrgSettings
                SkipRule    = $SkipRule
            }
        }
        elseif ( $null -eq $SkipRule -and $null -ne $Exception ) {
            Office BaseLine
            {
                OfficeApp   = $OfficeApp
                OrgSettings = $OrgSettings
                Exception   = $Exception
            }
        }
        elseif ( ($null -ne $Exception ) -and ($null -ne $SkipRule) )
        {
            Office Baseline
            {
                OfficeApp   = $OfficeApp
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
