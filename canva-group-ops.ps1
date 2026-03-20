Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:AdminBaseUrl = "https://api.canva.com/admin/v1"
$script:ScimBaseUrl = "https://www.canva.com/_scim/v2"
$script:ResolvedTeam = $null
$script:OAuthToken = $null
$script:ScimToken = $null
$script:Command = $null

$script:GroupId = $null
$script:GroupName = $null
$script:NewName = $null
$script:Description = $null
$script:UserEmail = $null
$script:UserId = $null
$script:TeamId = $null
$script:TeamName = $null
$script:CredsFile = "./.env"
$script:IncludeMembers = $false
$script:VerboseOutput = $false

function Parse-Arguments {
    param([string[]]$InputArgs)

    $argsQueue = [System.Collections.Generic.Queue[string]]::new()
    foreach ($token in $InputArgs) {
        $argsQueue.Enqueue($token)
    }

    while ($argsQueue.Count -gt 0) {
        $token = $argsQueue.Dequeue()

        switch -Regex ($token) {
            "^(--help|-Help|-h)$" { $script:Command = "help"; continue }
            "^(--list-groups|-ListGroups|-lg)$" { $script:Command = "list-groups"; continue }
            "^(--list-members|-ListMembers|-lm)$" { $script:Command = "list-members"; continue }
            "^(--create-group|-CreateGroup|-cg)$" { $script:Command = "create-group"; continue }
            "^(--rename-group|-RenameGroup|-rg)$" { $script:Command = "rename-group"; continue }
            "^(--remove-group|-RemoveGroup|-dg)$" { $script:Command = "remove-group"; continue }
            "^(--add-user|-AddUser|-au)$" { $script:Command = "add-user"; continue }
            "^(--remove-user|-RemoveUser|-ru)$" { $script:Command = "remove-user"; continue }
            "^(--list-users|-ListUsers|-lu)$" { $script:Command = "list-users"; continue }
            "^(--list-teams|-ListTeams|-lt)$" { $script:Command = "list-teams"; continue }
            "^(--include-members|-IncludeMembers|-im)$" { $script:IncludeMembers = $true; continue }
            "^(--verbose-output|-VerboseOutput|-v)$" { $script:VerboseOutput = $true; continue }
            "^(--group-id|-GroupId|-gid)$" {
                if ($argsQueue.Count -eq 0) { throw "Missing value for $token" }
                $script:GroupId = $argsQueue.Dequeue()
                continue
            }
            "^(--group-name|-GroupName|-gn)$" {
                if ($argsQueue.Count -eq 0) { throw "Missing value for $token" }
                $script:GroupName = $argsQueue.Dequeue()
                continue
            }
            "^(--new-name|-NewName|-nn)$" {
                if ($argsQueue.Count -eq 0) { throw "Missing value for $token" }
                $script:NewName = $argsQueue.Dequeue()
                continue
            }
            "^(--description|-Description|-d)$" {
                if ($argsQueue.Count -eq 0) { throw "Missing value for $token" }
                $script:Description = $argsQueue.Dequeue()
                continue
            }
            "^(--user-email|-UserEmail|-ue)$" {
                if ($argsQueue.Count -eq 0) { throw "Missing value for $token" }
                $script:UserEmail = $argsQueue.Dequeue()
                continue
            }
            "^(--user-id|-UserId|-uid)$" {
                if ($argsQueue.Count -eq 0) { throw "Missing value for $token" }
                $script:UserId = $argsQueue.Dequeue()
                continue
            }
            "^(--team-id|-TeamId|-tid)$" {
                if ($argsQueue.Count -eq 0) { throw "Missing value for $token" }
                $script:TeamId = $argsQueue.Dequeue()
                continue
            }
            "^(--team-name|-TeamName|-tn)$" {
                if ($argsQueue.Count -eq 0) { throw "Missing value for $token" }
                $script:TeamName = $argsQueue.Dequeue()
                continue
            }
            "^(--creds-file|-CredsFile|-cf)$" {
                if ($argsQueue.Count -eq 0) { throw "Missing value for $token" }
                $script:CredsFile = $argsQueue.Dequeue()
                continue
            }
            default {
                throw "Unknown argument: $token. Run --help for usage."
            }
        }
    }
}

function Show-Help {
    @"
Canva Group Ops CLI

Commands (choose one):
  --help | -Help | -h
  --list-teams | -ListTeams | -lt
  --list-users | -ListUsers | -lu
  --list-groups | -ListGroups | -lg [--include-members | -im]
  --list-members | -ListMembers | -lm --group-id <id> | --group-name <name>
  --create-group | -CreateGroup | -cg --group-name <name> [--description <text>]
  --rename-group | -RenameGroup | -rg (--group-id <id> | --group-name <name>) --new-name <name> [--description <text>]
  --remove-group | -RemoveGroup | -dg --group-id <id> | --group-name <name>
  --add-user | -AddUser | -au (--group-id <id> | --group-name <name>) (--user-email <email> | --user-id <id>)
  --remove-user | -RemoveUser | -ru (--group-id <id> | --group-name <name>) (--user-email <email> | --user-id <id>)

Common options:
  --group-id <id> | -GroupId <id> | -gid <id>
  --group-name <name> | -GroupName <name> | -gn <name>
  --new-name <name> | -NewName <name> | -nn <name>
  --description <text> | -Description <text> | -d <text>
  --user-email <email> | -UserEmail <email> | -ue <email>
  --user-id <id> | -UserId <id> | -uid <id>
  --team-id <id> | -TeamId <id> | -tid <id>
  --team-name <name> | -TeamName <name> | -tn <name>
  --creds-file <path> | -CredsFile <path> | -cf <path>   (default: ./.env)
  --verbose-output | -VerboseOutput | -v

Examples:
  pwsh ./canva-group-ops.ps1 --list-groups
  pwsh ./canva-group-ops.ps1 -lg -im
  pwsh ./canva-group-ops.ps1 -lm -gn "ByteDance"
  pwsh ./canva-group-ops.ps1 -cg -gn "Marketing" -d "Marketing team"
  pwsh ./canva-group-ops.ps1 -rg -gid G123 -nn "Marketing Ops"
  pwsh ./canva-group-ops.ps1 -au -gn "ByteDance" -ue user@company.com
  pwsh ./canva-group-ops.ps1 -au -gn "ByteDance" -uid U1234567890
"@ | Write-Host
}

function Read-Prompt {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Default
    )
    if (-not [string]::IsNullOrWhiteSpace($Default)) {
        Write-Host -NoNewline -ForegroundColor Cyan "? "
        Write-Host -NoNewline "$Message "
        Write-Host -NoNewline -ForegroundColor DarkGray "[$Default]"
        Write-Host -NoNewline ": "
    } else {
        Write-Host -NoNewline -ForegroundColor Cyan "? "
        Write-Host -NoNewline "$Message`: "
    }
    $value = [Console]::ReadLine()
    if ([string]::IsNullOrWhiteSpace($value)) {
        if (-not [string]::IsNullOrWhiteSpace($Default)) {
            return $Default
        }
        throw "No value provided."
    }
    return $value.Trim()
}

function Assert-RequiredArgument {
    param(
        [string]$Name,
        [string]$Value
    )
    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "Missing required option: $Name"
    }
}

function Write-Info {
    param([string]$Message)
    Write-Host "[info] $Message"
}

function Write-VerboseInfo {
    param([string]$Message)
    if ($VerboseOutput) {
        Write-Host "[debug] $Message"
    }
}

function Get-OptionalProperty {
    param(
        [object]$InputObject,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [object]$DefaultValue = $null
    )

    if ($null -eq $InputObject) {
        return $DefaultValue
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $DefaultValue
    }

    return $property.Value
}

function Load-EnvFile {
    param([string]$Path)

    $result = @{}
    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        return $result
    }

    $reader = $null
    try {
        # Use StreamReader so named pipes/FIFOs (e.g. 1Password local env file) can be read.
        $reader = [System.IO.File]::OpenText($Path)
    } catch {
        Write-VerboseInfo "Skipping env file '$Path' because it could not be read."
        return $result
    }

    try {
        while (($rawLine = $reader.ReadLine()) -ne $null) {
            $line = $rawLine.Trim()
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }
            if ($line.StartsWith("#")) {
                continue
            }

            $firstEquals = $line.IndexOf("=")
            if ($firstEquals -le 0) {
                continue
            }

            $key = $line.Substring(0, $firstEquals).Trim()
            if ($key.StartsWith("export ")) {
                $key = $key.Substring(7).Trim()
            }
            if ([string]::IsNullOrWhiteSpace($key)) {
                continue
            }

            $value = $line.Substring($firstEquals + 1).Trim()
            if ($value.StartsWith('"') -and $value.EndsWith('"') -and $value.Length -ge 2) {
                $value = $value.Substring(1, $value.Length - 2)
            } elseif ($value.StartsWith("'") -and $value.EndsWith("'") -and $value.Length -ge 2) {
                $value = $value.Substring(1, $value.Length - 2)
            }

            $result[$key] = $value
        }
    } finally {
        if ($reader) {
            $reader.Dispose()
        }
    }

    return $result
}

function Get-ConfigValue {
    param(
        [hashtable]$EnvMap,
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    if ($EnvMap -and $EnvMap.ContainsKey($Key)) {
        $fromFile = [string]$EnvMap[$Key]
        if (-not [string]::IsNullOrWhiteSpace($fromFile)) {
            return $fromFile
        }
    }

    $fromProcess = [System.Environment]::GetEnvironmentVariable($Key)
    if (-not [string]::IsNullOrWhiteSpace([string]$fromProcess)) {
        return [string]$fromProcess
    }

    return $null
}

function Save-EnvValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [Parameter(Mandatory = $true)]
        [string]$Value
    )
    $line = "$Key=$Value"
    if (Test-Path -Path $Path -PathType Leaf) {
        Add-Content -Path $Path -Value $line
    } else {
        Set-Content -Path $Path -Value $line
    }
}

function Require-ConfigValue {
    param(
        [hashtable]$EnvMap,
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [string]$Prompt
    )
    $value = Get-ConfigValue -EnvMap $EnvMap -Key $Key
    if (-not [string]::IsNullOrWhiteSpace($value)) {
        return $value
    }
    if ([string]::IsNullOrWhiteSpace($Prompt)) {
        $Prompt = $Key
    }
    $value = Read-Prompt -Message $Prompt
    Save-EnvValue -Path $CredsFile -Key $Key -Value $value
    $EnvMap[$Key] = $value
    return $value
}

function Invoke-CanvaRequest {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("GET", "POST", "PATCH", "DELETE")]
        [string]$Method,

        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers,

        [object]$Body
    )

    Write-VerboseInfo "$Method $Url"

    try {
        $invokeParams = @{
            Method  = $Method
            Uri     = $Url
            Headers = $Headers
        }

        if ($null -ne $Body) {
            if ($Body -is [string]) {
                $invokeParams["Body"] = $Body
            } else {
                $invokeParams["Body"] = ($Body | ConvertTo-Json -Depth 10)
            }
        }

        return Invoke-RestMethod @invokeParams
    } catch {
        $response = $_.Exception.Response
        if ($null -eq $response) {
            throw
        }

        $statusCode = [int]$response.StatusCode
        $responseText = $_.ErrorDetails.Message
        if ([string]::IsNullOrWhiteSpace($responseText)) {
            $responseText = $response.ReasonPhrase
        }
        throw "HTTP $statusCode calling $Method $Url`n$responseText"
    }
}

function Get-OAuthToken {
    param([hashtable]$EnvMap)

    if ($script:OAuthToken) {
        return $script:OAuthToken
    }

    $clientId = Require-ConfigValue -EnvMap $EnvMap -Key "CANVA_OAUTH_CLIENT_ID" -Prompt "Canva OAuth Client ID"
    $clientSecret = Require-ConfigValue -EnvMap $EnvMap -Key "CANVA_OAUTH_CLIENT_SECRET" -Prompt "Canva OAuth Client Secret"

    $basicToken = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$clientId`:$clientSecret"))
    $headers = @{
        "Authorization" = "Basic $basicToken"
        "Content-Type"  = "application/x-www-form-urlencoded"
        "Accept"        = "application/json"
    }

    $body = "grant_type=client_credentials"
    $response = Invoke-CanvaRequest -Method "POST" -Url "https://api.canva.com/auth/v1/oauth/token" -Headers $headers -Body $body

    if ([string]::IsNullOrWhiteSpace($response.access_token)) {
        throw "OAuth token response did not include access_token."
    }

    $script:OAuthToken = $response.access_token
    return $script:OAuthToken
}

function Get-ScimToken {
    param([hashtable]$EnvMap)

    if ($script:ScimToken) {
        return $script:ScimToken
    }

    $token = Require-ConfigValue -EnvMap $EnvMap -Key "CANVA_SCIM_TOKEN" -Prompt "Canva SCIM Token"

    $script:ScimToken = $token
    return $script:ScimToken
}

function Get-AdminHeaders {
    param([hashtable]$EnvMap)

    $token = Get-OAuthToken -EnvMap $EnvMap
    return @{
        "Authorization" = "Bearer $token"
        "Accept"        = "application/json"
    }
}

function Get-AdminJsonHeaders {
    param([hashtable]$EnvMap)

    $headers = Get-AdminHeaders -EnvMap $EnvMap
    $headers["Content-Type"] = "application/json"
    return $headers
}

function Get-ScimHeaders {
    param([hashtable]$EnvMap)

    $token = Get-ScimToken -EnvMap $EnvMap
    return @{
        "Authorization" = "Bearer $token"
        "Accept"        = "application/scim+json"
        "Content-Type"  = "application/scim+json"
    }
}

function Get-AllTeams {
    param([hashtable]$EnvMap)

    $headers = Get-AdminHeaders -EnvMap $EnvMap
    $allTeams = @()
    $continuation = $null

    do {
        $url = "$($script:AdminBaseUrl)/teams?limit=100"
        if ($continuation) {
            $url = "$url&continuation=$([System.Uri]::EscapeDataString($continuation))"
        }

        $response = Invoke-CanvaRequest -Method "GET" -Url $url -Headers $headers
        $items = @(Get-OptionalProperty -InputObject $response -Name "items" -DefaultValue @())
        if ($items.Count -gt 0) {
            $allTeams += $items
        }

        $continuation = Get-OptionalProperty -InputObject $response -Name "continuation"
    } while ($continuation)

    return $allTeams
}

function Resolve-Team {
    param([hashtable]$EnvMap)

    if ($script:ResolvedTeam) {
        return $script:ResolvedTeam
    }

    $teams = Get-AllTeams -EnvMap $EnvMap
    if ($teams.Count -eq 0) {
        throw "No teams returned by Canva Admin API."
    }

    if ($TeamId) {
        $match = @($teams | Where-Object { $_.id -eq $TeamId })
        if ($match.Count -eq 0) {
            throw "TeamId '$TeamId' was not found."
        }
        $script:ResolvedTeam = $match[0]
        return $script:ResolvedTeam
    }

    if ($TeamName) {
        $match = @($teams | Where-Object { $_.name -eq $TeamName })
        if ($match.Count -eq 0) {
            throw "TeamName '$TeamName' was not found."
        }
        if ($match.Count -gt 1) {
            throw "Multiple teams matched TeamName '$TeamName'. Use -TeamId."
        }
        $script:ResolvedTeam = $match[0]
        return $script:ResolvedTeam
    }

    if ($teams.Count -gt 1) {
        Write-Info "Multiple teams found. Defaulting to first team '$($teams[0].name)' ($($teams[0].id))."
        Write-Info "Use -TeamId or -TeamName to target a specific team."
    }

    $script:ResolvedTeam = $teams[0]
    return $script:ResolvedTeam
}

function Get-AllAdminGroups {
    param([hashtable]$EnvMap)

    $team = Resolve-Team -EnvMap $EnvMap
    $headers = Get-AdminHeaders -EnvMap $EnvMap
    $allGroups = @()
    $continuation = $null

    do {
        $url = "$($script:AdminBaseUrl)/teams/$([System.Uri]::EscapeDataString($team.id))/groups?limit=100"
        if ($continuation) {
            $url = "$url&continuation=$([System.Uri]::EscapeDataString($continuation))"
        }

        $response = Invoke-CanvaRequest -Method "GET" -Url $url -Headers $headers
        $items = @(Get-OptionalProperty -InputObject $response -Name "items" -DefaultValue @())
        if ($items.Count -gt 0) {
            $allGroups += $items
        }
        $continuation = Get-OptionalProperty -InputObject $response -Name "continuation"
    } while ($continuation)

    return $allGroups
}

function Get-AllScimGroups {
    param([hashtable]$EnvMap)

    $headers = Get-ScimHeaders -EnvMap $EnvMap
    $allGroups = @()
    $count = 100
    $startIndex = 1

    while ($true) {
        $url = "$($script:ScimBaseUrl)/Groups?count=$count&startIndex=$startIndex"
        $response = Invoke-CanvaRequest -Method "GET" -Url $url -Headers $headers
        $resources = @()
        $resourcesProperty = Get-OptionalProperty -InputObject $response -Name "Resources"
        if ($resourcesProperty) {
            $resources = @($resourcesProperty)
        }
        if ($resources.Count -eq 0) {
            break
        }

        $allGroups += $resources

        $totalResults = Get-OptionalProperty -InputObject $response -Name "totalResults"
        if ($totalResults -and $allGroups.Count -ge [int]$totalResults) {
            break
        }
        $startIndex += $resources.Count
    }

    return $allGroups
}

function Resolve-GroupIds {
    param(
        [hashtable]$EnvMap,
        [switch]$RequireScim,
        [switch]$RequireAdmin
    )

    $adminGroups = Get-AllAdminGroups -EnvMap $EnvMap
    $scimGroups = Get-AllScimGroups -EnvMap $EnvMap

    $resolvedAdmin = $null
    $resolvedScim = $null
    $resolvedName = $null

    if ($GroupName) {
        $adminMatches = @($adminGroups | Where-Object { $_.name -eq $GroupName })
        $scimMatches = @($scimGroups | Where-Object { $_.displayName -eq $GroupName })

        if ($adminMatches.Count -eq 0 -and $scimMatches.Count -eq 0) {
            throw "GroupName '$GroupName' was not found in Admin or SCIM groups."
        }
        if ($adminMatches.Count -gt 1 -or $scimMatches.Count -gt 1) {
            throw "GroupName '$GroupName' matched multiple groups. Use -GroupId."
        }

        if ($adminMatches.Count -eq 1) {
            $resolvedAdmin = $adminMatches[0]
            $resolvedName = $adminMatches[0].name
        }
        if ($scimMatches.Count -eq 1) {
            $resolvedScim = $scimMatches[0]
            if (-not $resolvedName) {
                $resolvedName = $scimMatches[0].displayName
            }
        }
    } elseif ($GroupId) {
        $resolvedAdmin = @($adminGroups | Where-Object { $_.id -eq $GroupId }) | Select-Object -First 1
        $resolvedScim = @($scimGroups | Where-Object { $_.id -eq $GroupId }) | Select-Object -First 1

        if (-not $resolvedAdmin -and -not $resolvedScim) {
            throw "GroupId '$GroupId' was not found in Admin or SCIM groups."
        }

        if ($resolvedAdmin) {
            $resolvedName = $resolvedAdmin.name
            if (-not $resolvedScim) {
                $resolvedScim = @($scimGroups | Where-Object { $_.displayName -eq $resolvedName }) | Select-Object -First 1
            }
        } elseif ($resolvedScim) {
            $resolvedName = $resolvedScim.displayName
            if (-not $resolvedAdmin) {
                $resolvedAdmin = @($adminGroups | Where-Object { $_.name -eq $resolvedName }) | Select-Object -First 1
            }
        }
    } else {
        throw "Either -GroupId or -GroupName is required for action '$Action'."
    }

    if ($RequireAdmin -and -not $resolvedAdmin) {
        throw "Could not resolve Admin group ID for '$resolvedName'."
    }
    if ($RequireScim -and -not $resolvedScim) {
        throw "Could not resolve SCIM group ID for '$resolvedName'."
    }

    return [PSCustomObject]@{
        Name      = $resolvedName
        AdminId   = if ($resolvedAdmin) { $resolvedAdmin.id } else { $null }
        ScimId    = if ($resolvedScim) { $resolvedScim.id } else { $null }
        AdminData = $resolvedAdmin
        ScimData  = $resolvedScim
    }
}

function Get-UserByEmail {
    param(
        [hashtable]$EnvMap,
        [Parameter(Mandatory = $true)]
        [string]$Email
    )

    $headers = Get-AdminHeaders -EnvMap $EnvMap
    $url = "$($script:AdminBaseUrl)/users?limit=100&email=$([System.Uri]::EscapeDataString($Email))"
    $response = Invoke-CanvaRequest -Method "GET" -Url $url -Headers $headers
    $items = @()
    $responseItems = Get-OptionalProperty -InputObject $response -Name "items" -DefaultValue @()
    if ($responseItems) {
        $items = @($responseItems)
    }

    if ($items.Count -eq 0) {
        throw "No Canva user found with email '$Email'."
    }
    if ($items.Count -gt 1) {
        throw "Multiple Canva users found with email '$Email'."
    }
    return $items[0]
}

function Get-AdminUsersMap {
    param([hashtable]$EnvMap)

    $headers = Get-AdminHeaders -EnvMap $EnvMap
    $continuation = $null
    $usersById = @{}

    do {
        $url = "$($script:AdminBaseUrl)/users?limit=100"
        if ($continuation) {
            $url = "$url&continuation=$([System.Uri]::EscapeDataString($continuation))"
        }

        $response = Invoke-CanvaRequest -Method "GET" -Url $url -Headers $headers
        foreach ($user in @(Get-OptionalProperty -InputObject $response -Name "items" -DefaultValue @())) {
            $usersById[$user.id] = $user
        }
        $continuation = Get-OptionalProperty -InputObject $response -Name "continuation"
    } while ($continuation)

    return $usersById
}

function List-Groups {
    param([hashtable]$EnvMap)

    $team = Resolve-Team -EnvMap $EnvMap
    $groups = Get-AllAdminGroups -EnvMap $EnvMap

    Write-Info "Team: $($team.name) ($($team.id))"
    Write-Info "Groups: $($groups.Count)"

    if (-not $IncludeMembers) {
        $groups |
            Sort-Object -Property name |
            Select-Object id, name, description, created_at, updated_at |
            Format-Table -AutoSize
        return
    }

    $usersById = Get-AdminUsersMap -EnvMap $EnvMap
    foreach ($group in ($groups | Sort-Object -Property name)) {
        $groupDescription = Get-OptionalProperty -InputObject $group -Name "description"
        Write-Host ""
        Write-Host "[$($group.id)] $($group.name)"
        if (-not [string]::IsNullOrWhiteSpace([string]$groupDescription)) {
            Write-Host "  Description: $groupDescription"
        }

        $members = Get-GroupMembersInternal -EnvMap $EnvMap -AdminGroupId $group.id
        if ($members.Count -eq 0) {
            Write-Host "  Members: (none)"
            continue
        }

        Write-Host "  Members: $($members.Count)"
        foreach ($member in $members) {
            $user = $usersById[$member.user_id]
            $emailValue = Get-OptionalProperty -InputObject $user -Name "email"
            $displayValue = Get-OptionalProperty -InputObject $user -Name "display_name"
            $email = if (-not [string]::IsNullOrWhiteSpace([string]$emailValue)) { $emailValue } else { "(email unavailable)" }
            $display = if (-not [string]::IsNullOrWhiteSpace([string]$displayValue)) { $displayValue } else { "(name unavailable)" }
            Write-Host "   - $($member.user_id) | $email | $display | role=$($member.role)"
        }
    }
}

function Get-GroupMembersInternal {
    param(
        [hashtable]$EnvMap,
        [Parameter(Mandatory = $true)]
        [string]$AdminGroupId
    )

    $team = Resolve-Team -EnvMap $EnvMap
    $headers = Get-AdminHeaders -EnvMap $EnvMap
    $allMembers = @()
    $continuation = $null

    do {
        $url = "$($script:AdminBaseUrl)/teams/$([System.Uri]::EscapeDataString($team.id))/groups/$([System.Uri]::EscapeDataString($AdminGroupId))/members?limit=100"
        if ($continuation) {
            $url = "$url&continuation=$([System.Uri]::EscapeDataString($continuation))"
        }

        $response = Invoke-CanvaRequest -Method "GET" -Url $url -Headers $headers
        $items = @(Get-OptionalProperty -InputObject $response -Name "items" -DefaultValue @())
        if ($items.Count -gt 0) {
            $allMembers += $items
        }
        $continuation = Get-OptionalProperty -InputObject $response -Name "continuation"
    } while ($continuation)

    return $allMembers
}

function List-GroupMembers {
    param([hashtable]$EnvMap)

    $group = Resolve-GroupIds -EnvMap $EnvMap -RequireAdmin
    $members = Get-GroupMembersInternal -EnvMap $EnvMap -AdminGroupId $group.AdminId
    $usersById = Get-AdminUsersMap -EnvMap $EnvMap

    Write-Info "Group: $($group.Name)"
    Write-Info "Admin ID: $($group.AdminId)"
    Write-Info "Members: $($members.Count)"

    $rows = @()
    foreach ($member in $members) {
        $user = $usersById[$member.user_id]
        $emailValue = Get-OptionalProperty -InputObject $user -Name "email"
        $displayValue = Get-OptionalProperty -InputObject $user -Name "display_name"
        $rows += [PSCustomObject]@{
            user_id      = $member.user_id
            email        = if (-not [string]::IsNullOrWhiteSpace([string]$emailValue)) { $emailValue } else { $null }
            display_name = if (-not [string]::IsNullOrWhiteSpace([string]$displayValue)) { $displayValue } else { $null }
            role         = $member.role
        }
    }

    $rows | Sort-Object -Property email, user_id | Format-Table -AutoSize
}

function Create-Group {
    param([hashtable]$EnvMap)

    if ([string]::IsNullOrWhiteSpace($GroupName)) {
        throw "-GroupName is required for create-group."
    }

    $team = Resolve-Team -EnvMap $EnvMap
    $headers = Get-AdminJsonHeaders -EnvMap $EnvMap
    $url = "$($script:AdminBaseUrl)/teams/$([System.Uri]::EscapeDataString($team.id))/groups"
    $body = @{
        name = $GroupName
    }
    if (-not [string]::IsNullOrWhiteSpace($Description)) {
        $body["description"] = $Description
    }

    $response = Invoke-CanvaRequest -Method "POST" -Url $url -Headers $headers -Body $body
    Write-Info "Created group '$($response.group.name)' with Admin ID $($response.group.id)."
}

function Rename-Group {
    param([hashtable]$EnvMap)

    if ([string]::IsNullOrWhiteSpace($NewName)) {
        throw "-NewName is required for rename-group."
    }

    $team = Resolve-Team -EnvMap $EnvMap
    $group = Resolve-GroupIds -EnvMap $EnvMap -RequireAdmin

    $headers = Get-AdminJsonHeaders -EnvMap $EnvMap
    $url = "$($script:AdminBaseUrl)/teams/$([System.Uri]::EscapeDataString($team.id))/groups/$([System.Uri]::EscapeDataString($group.AdminId))"
    $body = @{
        name = $NewName
    }
    if ($PSBoundParameters.ContainsKey("Description")) {
        $body["description"] = $Description
    } else {
        $existingDescription = Get-OptionalProperty -InputObject $group.AdminData -Name "description"
        if (-not [string]::IsNullOrWhiteSpace([string]$existingDescription)) {
            $body["description"] = $existingDescription
        }
    }

    $response = Invoke-CanvaRequest -Method "PATCH" -Url $url -Headers $headers -Body $body
    Write-Info "Renamed group '$($group.Name)' -> '$($response.group.name)' (Admin ID $($response.group.id))."
}

function Remove-Group {
    param([hashtable]$EnvMap)

    $team = Resolve-Team -EnvMap $EnvMap
    $group = Resolve-GroupIds -EnvMap $EnvMap -RequireAdmin
    $headers = Get-AdminHeaders -EnvMap $EnvMap
    $url = "$($script:AdminBaseUrl)/teams/$([System.Uri]::EscapeDataString($team.id))/groups/$([System.Uri]::EscapeDataString($group.AdminId))"
    Invoke-CanvaRequest -Method "DELETE" -Url $url -Headers $headers | Out-Null
    Write-Info "Deleted group '$($group.Name)' (Admin ID $($group.AdminId))."
}

function Update-GroupMembership {
    param(
        [hashtable]$EnvMap,
        [ValidateSet("add", "remove")]
        [string]$Operation
    )

    $group = Resolve-GroupIds -EnvMap $EnvMap -RequireScim
    $targetUserId = $null
    $targetUserLabel = $null
    if (-not [string]::IsNullOrWhiteSpace($UserId)) {
        $targetUserId = $UserId
        $targetUserLabel = $UserId
    } else {
        Assert-RequiredArgument -Name "--user-email" -Value $UserEmail
        $user = Get-UserByEmail -EnvMap $EnvMap -Email $UserEmail
        $targetUserId = $user.id
        $targetUserLabel = Get-OptionalProperty -InputObject $user -Name "email" -DefaultValue $UserEmail
    }

    $headers = Get-ScimHeaders -EnvMap $EnvMap
    $url = "$($script:ScimBaseUrl)/Groups/$([System.Uri]::EscapeDataString($group.ScimId))"
    $body = @{
        schemas    = @("urn:ietf:params:scim:api:messages:2.0:PatchOp")
        Operations = @(
            @{
                op    = $Operation
                path  = "members"
                value = @(@{ value = $targetUserId })
            }
        )
    }

    Invoke-CanvaRequest -Method "PATCH" -Url $url -Headers $headers -Body $body | Out-Null
    Write-Info "$Operation user '$targetUserLabel' (id=$targetUserId) in group '$($group.Name)' (scimId=$($group.ScimId))."
}

function List-Users {
    param([hashtable]$EnvMap)

    $headers = Get-AdminHeaders -EnvMap $EnvMap
    $continuation = $null
    $users = @()

    do {
        $url = "$($script:AdminBaseUrl)/users?limit=100"
        if ($continuation) {
            $url = "$url&continuation=$([System.Uri]::EscapeDataString($continuation))"
        }

        $response = Invoke-CanvaRequest -Method "GET" -Url $url -Headers $headers
        $users += @(Get-OptionalProperty -InputObject $response -Name "items" -DefaultValue @())
        $continuation = Get-OptionalProperty -InputObject $response -Name "continuation"
    } while ($continuation)

    Write-Info "Users: $($users.Count)"
    $users | Select-Object id, email, display_name, role, first_name, last_name | Sort-Object -Property email | Format-Table -AutoSize
}

function List-Teams {
    param([hashtable]$EnvMap)
    $teams = Get-AllTeams -EnvMap $EnvMap
    Write-Info "Teams: $($teams.Count)"
    $teams | Select-Object id, name, created_at, updated_at | Sort-Object -Property name | Format-Table -AutoSize
}

try {
    Parse-Arguments -InputArgs $args

    if (-not $script:Command) {
        Show-Help
        Write-Host "──────────────────────────────────────────────────────────────"
        $script:Command = Read-Prompt -Message "Command"
    }

    if ($script:Command -eq "help") {
        Show-Help
        exit 0
    }

    if ($script:Command -in @("list-members", "rename-group", "remove-group", "add-user", "remove-user", "create-group")) {
        if ([string]::IsNullOrWhiteSpace($GroupId) -and [string]::IsNullOrWhiteSpace($GroupName)) {
            $script:GroupName = Read-Prompt -Message "Group name"
        }
    }
    if ($script:Command -eq "rename-group") {
        if ([string]::IsNullOrWhiteSpace($NewName)) {
            $script:NewName = Read-Prompt -Message "New name"
        }
    }
    if ($script:Command -in @("add-user", "remove-user")) {
        if ([string]::IsNullOrWhiteSpace($UserEmail) -and [string]::IsNullOrWhiteSpace($UserId)) {
            $script:UserEmail = Read-Prompt -Message "User email"
        }
    }

    $envMap = Load-EnvFile -Path $CredsFile
    if ($envMap.Count -eq 0) {
        Write-VerboseInfo "No env file loaded from '$CredsFile'; using process environment only."
    } else {
        Write-VerboseInfo "Loaded env keys from '$CredsFile'."
    }
    if ($script:Command -ne "list-teams") {
        $resolvedTeam = Resolve-Team -EnvMap $envMap
        Write-Info "Using team: $($resolvedTeam.name) ($($resolvedTeam.id))"
    }

    switch ($script:Command) {
        "list-groups" { List-Groups -EnvMap $envMap }
        "list-members" { List-GroupMembers -EnvMap $envMap }
        "create-group" { Create-Group -EnvMap $envMap }
        "rename-group" { Rename-Group -EnvMap $envMap }
        "remove-group" { Remove-Group -EnvMap $envMap }
        "add-user" { Update-GroupMembership -EnvMap $envMap -Operation "add" }
        "remove-user" { Update-GroupMembership -EnvMap $envMap -Operation "remove" }
        "list-users" { List-Users -EnvMap $envMap }
        "list-teams" { List-Teams -EnvMap $envMap }
        default { throw "Unsupported command: $($script:Command)" }
    }
} catch {
    $errorMessage = $_.ErrorDetails.Message
    if ([string]::IsNullOrWhiteSpace($errorMessage)) {
        $errorMessage = [string]$_
    }
    if ([string]::IsNullOrWhiteSpace($errorMessage)) {
        $errorMessage = "Unexpected error. Run with --verbose-output for details."
    }
    Write-Host "[error] $errorMessage"
    exit 1
}
