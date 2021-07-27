#!powershell

$spec = @{
    options = @{
        database = @{ type = "str" }
        user = @{ type = "str" }
        login = @{ type = "str" }
        roles = @{ type = "list"; elements = "str"; }
        default_schema = @{ type = "str" }
        state = @{ type = 'str'; required = $true; choices = 'present', 'absent', 'pure' }
    }

    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$database = $module.Params.database
$user = $module.Params.user
$login = $module.Params.login
$roles = $module.Params.roles
$state = $module.Params.state

$module.Diff.before = ""
$module.Diff.after = ""

$module.Result.exists = $false

Function Get-DatabaseUser {
    [CmdletBinding()]
    param (
        [String]
        $User,
        [String]
        $Database
    )
    
    $database_roles = @{
        db_accessadmin = 0
        db_backupoperator = 0
        db_datareader = 0
        db_datawriter = 0
        db_ddladmin = 0
        db_denydatareader = 0
        db_denydatawriter = 0
        db_owner = 0
        db_securityadmin = 0
    }
    
    $user_result = @{
        user = $User
        user_exists = $false
        database = $Database
        default_schema = $null
        database_roles = $database_roles
    }

    $query_users = "SELECT name FROM `[$Database`].sys.database_principals WHERE type not in ('A', 'G', 'R', 'X')"

    $query_users_result = Invoke-Sqlcmd -Query $query_users

    if($query_users_result) {

        foreach($row in $query_users_result) {

            if(($row.Item("name")) -eq $User) {

                $user_result.user_exists = $true
                Break    
            }

        }

    }

    if($user_result.user_exists) {

        $query_user_roles = "SELECT r.name role_principal_name, m.name AS member_principal_name

        FROM `[$Database`].sys.database_role_members rm 

        JOIN `[$Database`].sys.database_principals r 

            ON rm.role_principal_id = r.principal_id

        JOIN `[$Database`].sys.database_principals m

            ON rm.member_principal_id = m.principal_id

        where m.name = `'$User`'"

        $query_user_roles_result = Invoke-Sqlcmd -Query $query_user_roles
    
        if($query_user_roles_result) {
            
            foreach($row in $query_user_roles_result) {

                $user_result.database_roles.($row.Item(0)) = "1"

            }
        }
    }

    $user_result

    return $user_result.database_roles

}

Function Get-TargetDatabaseUser {
    [CmdletBinding()]
    param (
        [String]
        $User,
        [String]
        $Database,
        $CurrentUser,
        [string[]]
        $DatabaseRoles,
        [string]
        $DefaultSchema
    )

    $database_roles = @{
        db_accessadmin = 0
        db_backupoperator = 0
        db_datareader = 0
        db_datawriter = 0
        db_ddladmin = 0
        db_denydatareader = 0
        db_denydatawriter = 0
        db_owner = 0
        db_securityadmin = 0
    }

    if($CurrentUser -and ($state -eq 'present')) {
        if($CurrentUser.database_roles.db_accessadmin) {$database_roles.db_accessadmin = 1}
        if($CurrentUser.database_roles.db_backupoperator) {$database_roles.db_backupoperator = 1}
        if($CurrentUser.database_roles.db_datareader) {$database_roles.db_datareader = 1}
        if($CurrentUser.database_roles.db_datawriter) {$database_roles.db_datawriter = 1}
        if($CurrentUser.database_roles.db_ddladmin) {$database_roles.db_ddladmin = 1}
        if($CurrentUser.database_roles.db_denydatareader) {$database_roles.db_denydatareader = 1}
        if($CurrentUser.database_roles.db_denydatawriter) {$database_roles.db_denydatawriter = 1}
        if($CurrentUser.database_roles.db_owner) {$database_roles.db_owner = 1}
        if($CurrentUser.database_roles.db_securityadmin) {$database_roles.db_securityadmin = 1}
    }

    $user_target = @{
        user = $User
        user_exists = $false
        database = $Database
        default_schema = $null
        database_roles = @{}
    }

    if (($state -eq 'present') -or ($state -eq 'pure')) {
        $user_target.user_exists = $true

        if($DefaultSchema) {
            $user_target.default_schema = $DefaultSchema
        }

        foreach ($role in $DatabaseRoles) {
            $database_roles.$role = 1
        }
    }

    $user_target.database_roles = $database_roles

    return $user_target

}

Function Set-DatabaseUser {
    [CmdletBinding()]
    param (
        [parameter(
            Mandatory         = $true,
            ValueFromPipeline = $true)]
        $UserStatus
    )

  #WIP

}

Function Set-DatabaseRoles {
    [CmdletBinding()]
    param (
        [parameter(
            Mandatory         = $true,
            ValueFromPipeline = $true)]
        $UserStatus,
        [string[]]
        $Roles
    )    

  #WIP

}

Try {

    $current_user = Get-DatabaseUser -User $user -Database $database
    
    $target_user = Get-TargetDatabaseUser -User $user -Database $database -CurrentUser $current_user -DefaultSchema $default_schema -DatabaseRoles $database_roles
    
    $Module.Diff.before = $current_user
    $Module.Diff.after = $target_user

    $current_user | Set-DatabaseUser -User $user -DefaultSchema $default_schema
    $current_user | Set-DatabaseRoles -DatabaseRoles $database_roles

    $current_user = Get-DatabaseUser -User $user -Database $database

    $Module.Result.user = $current_user

    $module.ExitJson()
}

Catch {
    $Module.FailJson("failed to execute $($PrintPath): $($_.Exception.Message)", $_)
}
