Configuration PowerSTIG_SQLServer_Instance
{

    param(
        [Parameter(Mandatory = $true)]
        [string]
        $SqlVersion,

        [Parameter(Mandatory = $true)]
        [string]
        $SqlRole,

        [Parameter()]
        [version]
        $StigVersion,

        [Parameter(Mandatory = $true)]
        [string[]]
        $ServerInstance,

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
            SqlServer BaseLine
            {
                SqlVersion      = $SqlVersion
                SqlRole         = $SqlRole
                ServerInstance  = $ServerInstance
            }
        }
        elseif ($null -ne $SkipRule -and $null -eq $Exception)
        {
            SqlServer BaseLine
            {
                SqlVersion      = $SqlVersion
                SqlRole         = $SqlRole
                ServerInstance  = $ServerInstance
                SkipRule        = $SkipRule
            }
        }
        elseif ($null -eq $skiprule -and $null -ne $Exception) {
            SqlServer BaseLine
            {
                SqlVersion      = $SqlVersion
                SqlRole         = $SqlRole
                ServerInstance  = $ServerInstance
                Exception       = $Exception
            }
        }
        elseif ( ($null -ne $Exception ) -and ($null -ne $SkipRule) )
        {
            SqlServer Baseline
            {
                SqlVersion      = $SqlVersion
                SqlRole         = $SqlRole
                ServerInstance  = $ServerInstance
                Exception       = $Exception
                SkipRule        = $SkipRule
            }
        }
    }
    else
    {
        if ( ($null -eq $SkipRule) -and ($null -eq $Exception) )
        {
            SqlServer BaseLine
            {
                SqlVersion      = $SqlVersion
                SqlRole         = $SqlRole
                ServerInstance  = $ServerInstance
                OrgSettings     = $OrgSettings
            }
        }
        elseif ($null -ne $SkipRule -and $null -eq $exception)
        {
            SqlServer BaseLine
            {
                SqlVersion      = $SqlVersion
                SqlRole         = $SqlRole
                ServerInstance  = $ServerInstance
                OrgSettings     = $OrgSettings
                SkipRule        = $SkipRule
            }
        }
        elseif ( $null -eq $skiprule -and $null -ne $Exception ) {
            SqlServer BaseLine
            {
                SqlVersion      = $SqlVersion
                SqlRole         = $SqlRole
                ServerInstance  = $ServerInstance
                OrgSettings     = $OrgSettings
                Exception       = $Exception
            }
        }
        elseif ( ($null -ne $Exception ) -and ($null -ne $SkipRule) )
        {
            SqlServer Baseline
            {
                SqlVersion      = $SqlVersion
                SqlRole         = $SqlRole
                ServerInstance  = $ServerInstance
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