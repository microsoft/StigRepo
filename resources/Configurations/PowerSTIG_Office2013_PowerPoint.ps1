Configuration PowerSTIG_Office2013_Powerpoint
{
    param(
        [Parameter()]
        [string]
        $OfficeApp = "PowerPoint2013",

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
        $SkipRule = @("V-17173","V-17174","V-17175","V-17183","V-26588","V-26584","V-17184","V-26587","V-26585","V-26586","V-42327","V-42332","V-42333","V-42334","V-42335","V-42336","V-42330","V-42329","V-42328","V-42331")
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
