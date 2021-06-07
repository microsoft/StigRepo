Configuration PowerSTIG_Edge
{
    param(

        [Parameter()]
        [version]
        $StigVersion,

        [Parameter()]
        [hashtable]
        $Exception,

        [Parameter()]
        [string]
        $OrgSettings = "C:\Users\jadean-sa\Desktop\SCAR\Resources\Stig Data\Organizational Settings\Microsoft-Edge-1.1.org.default.xml",

        [Parameter()]
        [string[]]
        $SkipRule
    )

    Import-DscResource -ModuleName 'PowerStig'

    if ( $null -eq $OrgSettings -or "" -eq $OrgSettings )
    {
        if ( $null -eq $SkipRule -and $null -eq $Exception )
        {
            Edge Baseline
            {

            }
        }
        elseif ( $null -ne $SkipRule -and $null -eq $Exception )
        {
            Edge Baseline
            {

                Skiprule            = $SkipRule
            }
        }
        elseif ( $null -eq $SkipRule -and $null -ne $Exception )
        {
            Edge Baseline
            {

                Exception           = $Exception
            }
        }
        elseif ( $null -ne $SkipRule -and $null -ne $Exception )
        {
            Edge Baseline
            {

                Skiprule            = $SkipRule
                Exception           = $Exception
            }
        }
    }
    else
    {
        if ( $null -eq $SkipRule -and $null -eq $Exception )
        {
            Edge Baseline
            {

                OrgSettings         = $OrgSettings
            }
        }
        elseif ( $null -ne $SkipRule -and $null -eq $Exception )
        {
            Edge Baseline
            {

                OrgSettings         = $OrgSettings
                Skiprule            = $SkipRule
            }
        }
        elseif ( $null -eq $SkipRule -and $null -ne $Exception )
        {
            Edge Baseline
            {

                OrgSettings         = $OrgSettings
                Exception           = $Exception
            }
        }
        elseif ( $null -ne $SkipRule -and $null -ne $Exception )
        {
            Edge Baseline
            {

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
