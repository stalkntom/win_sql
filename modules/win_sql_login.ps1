#!powershell
#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        windows_login = @{ type = "str" }
        sql_login = @{ type = "str" }
        password = @{ type = "str" }
        server_roles = @{ type = "list"; elements = "str"; }
        default_database = @{ type = "str" }
        default_language = @{ type = "str" }
        state = @{ type = 'str'; required = $true; choices = 'present', 'absent', 'pure' }
    }

    mutually_exclusive = @(,@("windows_login", "sql_login"))

    required_together = @(,@("sql_login", "password"))

    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$windows_login = $module.Params.windows_login
$sql_login = $module.Params.sql_login
$password = $module.Params.password
$server_roles = $module.Params.server_roles
$default_database = $module.Params.default_database
$default_language = $module.Params.default_language
$state = $module.Params.state

$module.Diff.before = ""
$module.Diff.after = ""

$module.Result.changed = $false

Function Get-Login {
    [CmdletBinding()]
    param (
        [String]
        $WindowsLogin,
        [string]
        $SQLLogin
    )

    $server_roles = @{
        bulkadmin = 0
        dbcreator = 0
        diskadmin = 0
        processadmin = 0
        securityadmin = 0
        serveradmin = 0
        setupadmin = 0
        sysadmin = 0
    }

    $login_result = @{
        windows_login = $WindowsLogin
        sql_login = $SQLLogin
        login_exists = $false
        default_database = $null
        default_language = $null
        server_roles = $server_roles
    }

    $query_login = if($WindowsLogin) {
        "SELECT * FROM master.sys.syslogins WHERE name = `'$WindowsLogin`'"
    } elseif($SQLLogin) {
        "SELECT * FROM master.sys.syslogins WHERE name = `'$SQLLogin`'"
    }

    $query_login_result = Invoke-Sqlcmd -Query $query_login

    if($query_login_result) {
        $login_result.login_exists = $true
        $login_result.default_database = $query_login_result | Select-Object -ExpandProperty dbname
        $login_result.default_language = $query_login_result | Select-Object -ExpandProperty language
        $login_result.server_roles.bulkadmin = $query_login_result | Select-Object -ExpandProperty bulkadmin
        $login_result.server_roles.dbcreator = $query_login_result | Select-Object -ExpandProperty dbcreator
        $login_result.server_roles.diskadmin = $query_login_result | Select-Object -ExpandProperty diskadmin
        $login_result.server_roles.processadmin = $query_login_result | Select-Object -ExpandProperty processadmin
        $login_result.server_roles.securityadmin = $query_login_result | Select-Object -ExpandProperty securityadmin
        $login_result.server_roles.serveradmin = $query_login_result | Select-Object -ExpandProperty serveradmin
        $login_result.server_roles.setupadmin = $query_login_result | Select-Object -ExpandProperty setupadmin
        $login_result.server_roles.sysadmin = $query_login_result | Select-Object -ExpandProperty sysadmin
    }

    return $login_result
}

Function Get-TargetLogin {
    [CmdletBinding()]
    param (
        [String]
        $WindowsLogin,
        [string]
        $SQLLogin,
        $CurrentLogin,
        [string[]]
        $ServerRoles,
        [string]
        $DefaultDatabase,
        [string]
        $DefaultLanguage
    )

    $server_roles = @{
        bulkadmin = 0
        dbcreator = 0
        diskadmin = 0
        processadmin = 0
        securityadmin = 0
        serveradmin = 0
        setupadmin = 0
        sysadmin = 0
    }

    if($CurrentLogin -and ($state -eq 'present')) {
        if($CurrentLogin.server_roles.bulkadmin) {$server_roles.bulkadmin = 1}
        if($CurrentLogin.server_roles.dbcreator) {$server_roles.dbcreator = 1}
        if($CurrentLogin.server_roles.diskadmin) {$server_roles.diskadmin = 1}
        if($CurrentLogin.server_roles.processadmin) {$server_roles.processadmin = 1}
        if($CurrentLogin.server_roles.securityadmin) {$server_roles.securityadmin = 1}
        if($CurrentLogin.server_roles.serveradmin) {$server_roles.serveradmin = 1}
        if($CurrentLogin.server_roles.setupadmin) {$server_roles.setupadmin = 1}
        if($CurrentLogin.server_roles.sysadmin) {$server_roles.sysadmin = 1}
    }

    $login_target = @{
        windows_login = $WindowsLogin
        sql_login = $SQLLogin
        login_exists = $false
        #create_date = $null
        #update_date = $null
        #access_date = $null
        default_database = $CurrentLogin.default_database
        default_language = $CurrentLogin.default_language
        server_roles = @{}
    }

    if (($state -eq 'present') -or ($state -eq 'pure')) {
        $login_target.login_exists = $true
    
        if ($DefaultDatabase) {
            $login_target.default_database = $DefaultDatabase
        }

        if ($DefaultLanguage) {
            $login_target.default_language = $DefaultLanguage
        }

        foreach ($role in $ServerRoles) {
            $server_roles.$role = 1
        }
    }

    $login_target.server_roles = $server_roles

    return $login_target
}

Function Set-Login {
    [CmdletBinding()]
    param (
        [parameter(
            Mandatory         = $true,
            ValueFromPipeline = $true)]
        $LoginStatus,
        [string]
        $Password,
        [string]
        $DefaultDatabase,
        [string]
        $DefaultLanguage
    )

    if (-not($LoginStatus.login_exists)) {
        if (($state -eq "present") -or ($state -eq "pure")) {
            if (-not($Module.CheckMode)) {

                $query_create_login = if ($LoginStatus.windows_login) {
                    $login = $LoginStatus.windows_login
                    "CREATE LOGIN `[$login`] FROM WINDOWS"
                } elseif ($LoginStatus.sql_login) {
                    $login = $LoginStatus.sql_login
                    "CREATE LOGIN `[$login`] WITH PASSWORD = `'$Password`'"
                }

                if (($LoginStatus.windows_login) -and ($DefaultDatabase -or $DefaultLanguage)) {
                    if ($DefaultDatabase -and $DefaultLanguage) {
                        $query_create_login += " WITH DEFAULT_DATABASE = `[$DefaultDatabase`], DEFAULT_LANGUAGE = `[$DefaultLanguage`]"
                    }
                    elseif ($DefaultDatabase){
                        $query_create_login += " WITH DEFAULT_DATABASE = `[$DefaultDatabase`]"
                    }
                    elseif ($DefaultLanguage){
                        $query_create_login += " WITH DEFAULT_LANGUAGE = `[$DefaultLanguage`]"
                    }
                }
                elseif ($LoginStatus.sql_login) {
                    if($DefaultDatabase){$query_create_login += ", DEFAULT_DATABASE = `[$DefaultDatabase`]"}
                    if($DefaultLanguage){$query_create_login += ", DEFAULT_LANGUAGE = `[$DefaultLanguage`]"}
                }

                try {
                    Invoke-Sqlcmd -Query $query_create_login
                } catch {
                    $Module.FailJson("failed to create login $($login): $($_.Exception.Message)", $_)
                }
            }

            $Module.Result.changed = $true
        }
    } 
    
    elseif ($LoginStatus.login_exists) {
        if (($state -eq "present") -or ($state -eq "pure")) {
            if ($DefaultDatabase) {
                if ($LoginStatus.default_database -eq $DefaultDatabase) {
                    $default_database_correct = $true
                } else {
                    $default_database_correct = $false
                }
            }

            if ($DefaultLanguage) {
                if ($LoginStatus.default_language -eq $DefaultLanguage) {
                    $default_language_correct = $true
                } else {
                    $default_language_correct = $false
                }
            }
            
            if ($DefaultLanguage -or $DefaultLanguage) {
                if ((-not($default_database_correct)) -or (-not($default_language_correct))) {

                    if (-not($Module.CheckMode)) {

                        $query_alter_login = if ($LoginStatus.windows_login) {
                            $login = $LoginStatus.windows_login
                            "ALTER LOGIN `[$login`] WITH"
                        } elseif ($LoginStatus.sql_login) {
                            $login = $LoginStatus.sql_login
                            "ALTER LOGIN `[$login`] WITH"
                        }

                        if ((-not($default_database_correct)) -and (-not($default_language_correct))) {
                            $query_alter_login += " DEFAULT_DATABASE = `[$DefaultDatabase`], DEFAULT_LANGUAGE = `[$DefaultLanguage`]"
                        } elseif ((-not($default_database_correct)) -and ($default_language_correct)) {
                            $query_alter_login += " DEFAULT_DATABASE = `[$DefaultDatabase`]"
                        } elseif ((-not($default_language_correct)) -and ($default_database_correct)) {
                            $query_alter_login += " DEFAULT_LANGUAGE = `[$DefaultLanguage`]"
                        }

                        try {
                            Invoke-Sqlcmd -Query $query_alter_login
                        } catch {
                            $Module.FailJson("failed to update login $($login): $($_.Exception.Message)", $_)
                        }

                    }

                    $Module.Result.changed = $true

                }
            }
        }

        if ($state -eq "absent") {
            if (-not($Module.CheckMode)) {

                $query_drop_login = if ($LoginStatus.windows_login) {
                    $login = $LoginStatus.windows_login
                    "DROP LOGIN `[$login`]"
                } elseif ($LoginStatus.sql_login) {
                    $login = $LoginStatus.sql_login
                    "DROP LOGIN `[$login`]"
                }                

                try {
                    Invoke-Sqlcmd -Query $query_drop_login
                } catch {
                    $Module.FailJson("failed to create login $($login): $($_.Exception.Message)", $_)
                }
            }

            $Module.Result.changed = $true
        }
    }
}

Function Set-ServerRoles {
    [CmdletBinding()]
    param (
        [parameter(
            Mandatory         = $true,
            ValueFromPipeline = $true)]
        $LoginStatus,
        $ServerRoles
    )

    if ($LoginStatus.windows_login) {$login = $LoginStatus.windows_login}
    elseif ($LoginStatus.sql_login) {$login = $LoginStatus.sql_login}  

    $login_result_roles = $LoginStatus.server_roles

    $roles_present = @()
    $roles_absent = @()
    $roles_to_remove = @()

    foreach ($role in $ServerRoles) {
        if (($login_result_roles.$role) -eq 1) {$roles_present += $role}
        else {$roles_absent += $role}
    }

    if (($state -eq "present") -or ($state -eq "pure")) {
        if($roles_absent) {
            if (-not($Module.CheckMode)) {
                foreach ($role_absent in $roles_absent) {
                    
                    $query_alter_role = "ALTER SERVER ROLE `[$role_absent`] ADD MEMBER `[$login`]"

                    try {
                        Invoke-Sqlcmd -Query $query_alter_role
                    } catch {
                        $Module.FailJson("failed to add $(login) to role $($role_absent): $($_.Exception.Message)", $_)
                    }
                }
            }            

            $Module.Result.changed = $true
        }
    }

    if ($state -eq "pure") {

        $login_result_roles.GetEnumerator() | ForEach-Object {
            $role_name = $_.key
            $role_value = $_.value
            
            if($role_value -eq 1) {
                if ($ServerRoles -notcontains $role_name) {
                    $roles_to_remove += $role_name
                }
            }
        }

        if($roles_to_remove) {
            if (-not($Module.CheckMode)) {
                foreach ($role_to_remove in $roles_to_remove) {
                    
                    $query_alter_role = "ALTER SERVER ROLE `[$role_to_remove`] DROP MEMBER `[$login`]"

                    try {
                        Invoke-Sqlcmd -Query $query_alter_role
                    } catch {
                        $Module.FailJson("failed to drop $($login) from role $($role_to_remove): $($_.Exception.Message)", $_)
                    }
                }
            }    

            $Module.Result.changed = $true
        }
    }
}

Try {

    $current_login  = if($windows_login) {
        Get-Login -WindowsLogin $windows_login
    } elseif($sql_login) {
        Get-Login -SQLLogin $sql_login
    }

    $target_login = if($windows_login) {
        Get-TargetLogin -WindowsLogin $windows_login -CurrentLogin $current_login -DefaultDatabase $default_database -DefaultLanguage $default_language -ServerRoles $server_roles
    } elseif($sql_login) {
        Get-TargetLogin -SQLLogin $sql_login -CurrentLogin $current_login -DefaultDatabase $default_database -DefaultLanguage $default_language -ServerRoles $server_roles
    }

    $module.Diff.before = $current_login
    $module.Diff.after = $target_login

    $current_login | Set-Login -DefaultDatabase $default_database -DefaultLanguage $default_language
    $current_login | Set-ServerRoles -ServerRoles $server_roles

    $current_login  = if($windows_login) {
        Get-Login -WindowsLogin $windows_login
    } elseif($sql_login) {
        Get-Login -SQLLogin $sql_login
    }

    $module.Result.login = $current_login

    $module.ExitJson()
}

Catch {
    $Module.FailJson("failed to execute $($PrintPath): $($_.Exception.Message)", $_)
}
