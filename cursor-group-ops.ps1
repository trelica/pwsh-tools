Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:AdminBaseUrl = "https://api.cursor.com"
$script:ScimBaseUrl = $null
$script:Command = $null
$script:GroupType = $null
$script:GroupId = $null
$script:GroupName = $null
$script:NewName = $null
$script:UserEmails = @()
$script:UserIds = @()
$script:CredsFile = "./.env"
$script:IncludeMembers = $false
$script:VerboseOutput = $false
$script:BillingCycle = $null
$script:ScimBaseUrlOverride = $null

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
            "^(--create-user|-CreateUser|-cu)$" { $script:Command = "create-user"; continue }
            "^(--list-users|-ListUsers|-lu)$" { $script:Command = "list-users"; continue }
            "^(--include-members|-IncludeMembers|-im)$" { $script:IncludeMembers = $true; continue }
            "^(--verbose-output|-VerboseOutput|-v)$" { $script:VerboseOutput = $true; continue }
            "^(--group-type|-GroupType|-gt)$" {
                if ($argsQueue.Count -eq 0) { throw "Missing value for $token" }
                $script:GroupType = $argsQueue.Dequeue().ToLowerInvariant()
                continue
            }
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
            "^(--user-email|-UserEmail|-ue)$" {
                if ($argsQueue.Count -eq 0) { throw "Missing value for $token" }
                $script:UserEmails += ($argsQueue.Dequeue() -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
                continue
            }
            "^(--user-id|-UserId|-uid)$" {
                if ($argsQueue.Count -eq 0) { throw "Missing value for $token" }
                $script:UserIds += ($argsQueue.Dequeue() -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
                continue
            }
            "^(--billing-cycle|-BillingCycle|-bc)$" {
                if ($argsQueue.Count -eq 0) { throw "Missing value for $token" }
                $script:BillingCycle = $argsQueue.Dequeue()
                continue
            }
            "^(--scim-base-url|-ScimBaseUrl|-sbu)$" {
                if ($argsQueue.Count -eq 0) { throw "Missing value for $token" }
                $script:ScimBaseUrlOverride = $argsQueue.Dequeue()
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
Cursor Group Ops CLI

Commands (choose one):
  --help | -h
  --list-users | -lu
  --list-groups | -lg [--include-members | -im]
  --list-members | -lm --group-id <id> | --group-name <name>
  --create-group | -cg --group-name <name>
  --rename-group | -rg (--group-id <id> | --group-name <name>) --new-name <name>
  --remove-group | -dg --group-id <id> | --group-name <name>
  --add-user | -au (--group-id <id> | --group-name <name>) (--user-email <email> | --user-id <id>)
  --remove-user | -ru (--group-id <id> | --group-name <name>) (--user-email <email> | --user-id <id>)
  --create-user | -cu --user-email <email> [--group-id <id> | --group-name <name>]  (SCIM only)

Common options:
  --group-type <billing|regular> | -gt <billing|regular>     (default: billing)
  --group-id <id> | -gid <id>
  --group-name <name> | -gn <name>
  --new-name <name> | -nn <name>
  --user-email <email> | -ue <email>
  --user-id <id> | -uid <id>
  --billing-cycle <YYYY-MM-DD> | -bc <YYYY-MM-DD>            (billing groups only)
  --scim-base-url <url> | -sbu <url>                          (regular groups only)
  --creds-file <path> | -cf <path>                            (default: ./.env)
  --include-members | -im
  --verbose-output | -v

Environment keys (from .env and/or process env):
  CURSOR_API_KEY
  CURSOR_SCIM_TOKEN
  CURSOR_SCIM_BASE_URL

Examples:
  pwsh ./cursor-group-ops.ps1 -lg
  pwsh ./cursor-group-ops.ps1 -lg -gt billing -im
  pwsh ./cursor-group-ops.ps1 -lm -gt billing -gn "Engineering"
  pwsh ./cursor-group-ops.ps1 -cg -gt billing -gn "Platform"
  pwsh ./cursor-group-ops.ps1 -au -gt billing -gn "Platform" -ue "user@company.com"
  pwsh ./cursor-group-ops.ps1 -lg -gt regular
  pwsh ./cursor-group-ops.ps1 -au -gt regular -gn "Okta Engineering" -ue "user@company.com"
"@ | Write-Host
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

function Normalize-UrlBase {
    param([string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) {
        return $null
    }
    $trimmed = $Url.Trim()
    if ($trimmed.EndsWith("/")) {
        return $trimmed.TrimEnd("/")
    }
    return $trimmed
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

function Get-BasicHeaders {
    param(
        [hashtable]$EnvMap,
        [switch]$Json
    )

    $apiKey = Require-ConfigValue -EnvMap $EnvMap -Key "CURSOR_API_KEY" -Prompt "Cursor API Key"

    $basic = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$apiKey`:" ))
    $headers = @{
        "Authorization" = "Basic $basic"
        "Accept" = "application/json"
    }
    if ($Json) {
        $headers["Content-Type"] = "application/json"
    }
    return $headers
}

function Get-ScimHeaders {
    param([hashtable]$EnvMap)

    $token = Require-ConfigValue -EnvMap $EnvMap -Key "CURSOR_SCIM_TOKEN" -Prompt "Cursor SCIM Token"

    return @{
        "Authorization" = "Bearer $token"
        "Accept" = "application/scim+json"
        "Content-Type" = "application/scim+json"
    }
}

function Resolve-ScimBaseUrl {
    param([hashtable]$EnvMap)

    if ($script:ScimBaseUrl) {
        return $script:ScimBaseUrl
    }

    $candidate = $script:ScimBaseUrlOverride
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        $candidate = Get-ConfigValue -EnvMap $EnvMap -Key "CURSOR_SCIM_BASE_URL"
    }

    if ([string]::IsNullOrWhiteSpace($candidate)) {
        $candidate = Read-Prompt -Message "Cursor SCIM Base URL"
        Save-EnvValue -Path $CredsFile -Key "CURSOR_SCIM_BASE_URL" -Value $candidate
        $EnvMap["CURSOR_SCIM_BASE_URL"] = $candidate
    }
    $resolved = Normalize-UrlBase -Url $candidate

    $script:ScimBaseUrl = $resolved
    return $script:ScimBaseUrl
}

function Invoke-CursorRequest {
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
        $params = @{
            Method = $Method
            Uri = $Url
            Headers = $Headers
        }
        if ($null -ne $Body) {
            if ($Body -is [string]) {
                $params["Body"] = $Body
            } else {
                $params["Body"] = ($Body | ConvertTo-Json -Depth 20)
            }
        }
        return Invoke-RestMethod @params
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

function Get-AllTeamMembers {
    param([hashtable]$EnvMap)
    $headers = Get-BasicHeaders -EnvMap $EnvMap
    $url = "$($script:AdminBaseUrl)/teams/members"
    $response = Invoke-CursorRequest -Method "GET" -Url $url -Headers $headers
    return @(Get-OptionalProperty -InputObject $response -Name "teamMembers" -DefaultValue @())
}

function Get-BillingGroupsResponse {
    param([hashtable]$EnvMap)

    $headers = Get-BasicHeaders -EnvMap $EnvMap
    $url = "$($script:AdminBaseUrl)/teams/groups"
    if (-not [string]::IsNullOrWhiteSpace($BillingCycle)) {
        $url = "$url?billingCycle=$([System.Uri]::EscapeDataString($BillingCycle))"
    }

    return Invoke-CursorRequest -Method "GET" -Url $url -Headers $headers
}

function Get-AllBillingGroups {
    param([hashtable]$EnvMap)

    $response = Get-BillingGroupsResponse -EnvMap $EnvMap
    $groups = @(Get-OptionalProperty -InputObject $response -Name "groups" -DefaultValue @())
    $unassigned = Get-OptionalProperty -InputObject $response -Name "unassignedGroup"
    if ($unassigned) {
        $groups += $unassigned
    }
    return $groups
}

function Get-AllScimResources {
    param(
        [hashtable]$EnvMap,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Users", "Groups")]
        [string]$ResourceType
    )

    $headers = Get-ScimHeaders -EnvMap $EnvMap
    $base = Resolve-ScimBaseUrl -EnvMap $EnvMap
    $all = @()
    $count = 100
    $startIndex = 1

    while ($true) {
        $url = "$base/${ResourceType}?count=$count&startIndex=$startIndex"
        $response = Invoke-CursorRequest -Method "GET" -Url $url -Headers $headers
        $resourcesRaw = Get-OptionalProperty -InputObject $response -Name "Resources"
        $resources = @()
        if ($resourcesRaw) {
            $resources = @($resourcesRaw)
        }
        if ($resources.Count -eq 0) {
            break
        }

        $all += $resources

        $totalResults = Get-OptionalProperty -InputObject $response -Name "totalResults"
        if ($totalResults -and $all.Count -ge [int]$totalResults) {
            break
        }
        $startIndex += $resources.Count
    }

    return $all
}

function Get-AllScimGroups {
    param([hashtable]$EnvMap)
    return Get-AllScimResources -EnvMap $EnvMap -ResourceType "Groups"
}

function Get-AllScimUsers {
    param([hashtable]$EnvMap)
    return Get-AllScimResources -EnvMap $EnvMap -ResourceType "Users"
}

function Resolve-BillingGroup {
    param([hashtable]$EnvMap)

    $groups = Get-AllBillingGroups -EnvMap $EnvMap
    if ([string]::IsNullOrWhiteSpace($GroupId) -and [string]::IsNullOrWhiteSpace($GroupName)) {
        throw "Provide either --group-id or --group-name."
    }

    if (-not [string]::IsNullOrWhiteSpace($GroupId)) {
        $match = @($groups | Where-Object { $_.id -eq $GroupId })
        if ($match.Count -eq 0) {
            throw "Billing group ID '$GroupId' was not found."
        }
        return $match[0]
    }

    $nameMatches = @($groups | Where-Object { $_.name -eq $GroupName })
    if ($nameMatches.Count -eq 0) {
        throw "Billing group '$GroupName' was not found."
    }
    if ($nameMatches.Count -gt 1) {
        throw "Multiple billing groups matched '$GroupName'. Use --group-id."
    }
    return $nameMatches[0]
}

function Resolve-ScimGroup {
    param([hashtable]$EnvMap)

    $groups = Get-AllScimGroups -EnvMap $EnvMap
    if ([string]::IsNullOrWhiteSpace($GroupId) -and [string]::IsNullOrWhiteSpace($GroupName)) {
        throw "Provide either --group-id or --group-name."
    }

    if (-not [string]::IsNullOrWhiteSpace($GroupId)) {
        $match = @($groups | Where-Object { $_.id -eq $GroupId })
        if ($match.Count -eq 0) {
            throw "SCIM group ID '$GroupId' was not found."
        }
        return $match[0]
    }

    $nameMatches = @($groups | Where-Object { $_.displayName -eq $GroupName })
    if ($nameMatches.Count -eq 0) {
        throw "SCIM group '$GroupName' was not found."
    }
    if ($nameMatches.Count -gt 1) {
        throw "Multiple SCIM groups matched '$GroupName'. Use --group-id."
    }
    return $nameMatches[0]
}

function Resolve-BillingUserIds {
    param([hashtable]$EnvMap)

    if ($script:UserIds.Count -gt 0) {
        return $script:UserIds | ForEach-Object { [string]$_ }
    }

    if ($script:UserEmails.Count -eq 0) {
        throw "Provide --user-email or --user-id."
    }

    $members = Get-AllTeamMembers -EnvMap $EnvMap
    $resolved = @()
    foreach ($email in $script:UserEmails) {
        $needle = $email.ToLowerInvariant()
        $found = @($members | Where-Object { $_.email -and $_.email.ToLowerInvariant() -eq $needle })
        if ($found.Count -eq 0) { throw "No team member found with email '$email'." }
        if ($found.Count -gt 1) { throw "Multiple team members matched '$email'. Use --user-id." }
        $resolved += [string]$found[0].id
    }
    return $resolved
}

function Get-ScimUserEmail {
    param([object]$ScimUser)

    $emails = Get-OptionalProperty -InputObject $ScimUser -Name "emails"
    if ($emails) {
        $primary = @($emails | Where-Object { (Get-OptionalProperty -InputObject $_ -Name "primary" -DefaultValue $false) -eq $true }) | Select-Object -First 1
        if ($primary) {
            $val = Get-OptionalProperty -InputObject $primary -Name "value"
            if (-not [string]::IsNullOrWhiteSpace([string]$val)) {
                return [string]$val
            }
        }

        $first = @($emails) | Select-Object -First 1
        if ($first) {
            $val = Get-OptionalProperty -InputObject $first -Name "value"
            if (-not [string]::IsNullOrWhiteSpace([string]$val)) {
                return [string]$val
            }
        }
    }

    $userName = Get-OptionalProperty -InputObject $ScimUser -Name "userName"
    if (-not [string]::IsNullOrWhiteSpace([string]$userName)) {
        return [string]$userName
    }

    return $null
}

function Resolve-ScimUserIds {
    param([hashtable]$EnvMap)

    if ($script:UserIds.Count -gt 0) {
        return $script:UserIds | ForEach-Object { [string]$_ }
    }

    if ($script:UserEmails.Count -eq 0) {
        throw "Provide --user-email or --user-id."
    }

    $users = Get-AllScimUsers -EnvMap $EnvMap
    $resolved = @()
    foreach ($email in $script:UserEmails) {
        $needle = $email.ToLowerInvariant()
        $found = @($users | Where-Object { (Get-ScimUserEmail -ScimUser $_) -and (Get-ScimUserEmail -ScimUser $_).ToLowerInvariant() -eq $needle })
        if ($found.Count -eq 0) { throw "No SCIM user found with email '$email'." }
        if ($found.Count -gt 1) { throw "Multiple SCIM users matched '$email'. Use --user-id." }
        $resolved += [string]$found[0].id
    }
    return $resolved
}

function Create-ScimUsers {
    param([hashtable]$EnvMap)

    if ($script:UserEmails.Count -eq 0) {
        throw "Provide --user-email."
    }

    Write-Host "Processing..."

    $headers = Get-ScimHeaders -EnvMap $EnvMap
    $base = Resolve-ScimBaseUrl -EnvMap $EnvMap
    $url = "$base/Users"
    $createdIds = @()

    # Fetch billing members once to look up display names
    $members = @(Get-AllTeamMembers -EnvMap $EnvMap)

    foreach ($email in $script:UserEmails) {
        $needle = $email.ToLowerInvariant()
        $member = $members | Where-Object { $_.email -and $_.email.ToLowerInvariant() -eq $needle } | Select-Object -First 1

        $givenName = $email
        $familyName = ""
        if ($member -and -not [string]::IsNullOrWhiteSpace([string]$member.name)) {
            $parts = ([string]$member.name).Trim() -split '\s+', 2
            $givenName = $parts[0]
            $familyName = if ($parts.Count -gt 1) { $parts[1] } else { "" }
        }

        $body = @{
            schemas     = @("urn:ietf:params:scim:schemas:core:2.0:User")
            userName    = $email
            active      = $true
            name        = @{ givenName = $givenName; familyName = $familyName }
            emails      = @(@{ value = $email; primary = $true })
        }

        $result = Invoke-CursorRequest -Method "POST" -Url $url -Headers $headers -Body $body
        $createdId = Get-OptionalProperty -InputObject $result -Name "id"
        Write-Info "Created SCIM user '$email' (ID $createdId)."
        $createdIds += [string]$createdId
    }

    if (-not [string]::IsNullOrWhiteSpace($GroupId) -or -not [string]::IsNullOrWhiteSpace($GroupName)) {
        $group = Resolve-ScimGroup -EnvMap $EnvMap
        $groupUrl = "$base/Groups/$([System.Uri]::EscapeDataString($group.id))"
        $groupBody = @{
            schemas    = @("urn:ietf:params:scim:api:messages:2.0:PatchOp")
            Operations = @(
                @{
                    op    = "add"
                    path  = "members"
                    value = @($createdIds | ForEach-Object { @{ value = $_ } })
                }
            )
        }
        Invoke-CursorRequest -Method "PATCH" -Url $groupUrl -Headers $headers -Body $groupBody | Out-Null
        Write-Info "Added $($createdIds.Count) user(s) to SCIM group '$($group.displayName)' (ID $($group.id))."
    }
}

function List-Users {
    param([hashtable]$EnvMap)

    if ($GroupType -eq "regular") {
        $users = Get-AllScimUsers -EnvMap $EnvMap
        if (-not [string]::IsNullOrWhiteSpace($GroupId) -or -not [string]::IsNullOrWhiteSpace($GroupName)) {
            $group = Resolve-ScimGroup -EnvMap $EnvMap
            $memberIds = @(Get-OptionalProperty -InputObject $group -Name "members" -DefaultValue @()) |
                ForEach-Object { [string]$_.value }
            $users = @($users | Where-Object { $memberIds -contains [string](Get-OptionalProperty -InputObject $_ -Name "id") })
            Write-Info "SCIM users in '$($group.displayName)': $($users.Count)"
        } else {
            Write-Info "SCIM users: $($users.Count)"
        }
        $rows = @()
        foreach ($u in $users) {
            $rows += [PSCustomObject]@{
                id = [string](Get-OptionalProperty -InputObject $u -Name "id")
                userName = [string](Get-OptionalProperty -InputObject $u -Name "userName")
                email = Get-ScimUserEmail -ScimUser $u
                active = Get-OptionalProperty -InputObject $u -Name "active"
                displayName = [string](Get-OptionalProperty -InputObject $u -Name "displayName")
            }
        }
        $rows | Sort-Object -Property email, userName | Format-Table -AutoSize
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($GroupId) -or -not [string]::IsNullOrWhiteSpace($GroupName)) {
        $group = Resolve-BillingGroup -EnvMap $EnvMap
        $headers = Get-BasicHeaders -EnvMap $EnvMap
        $url = "$($script:AdminBaseUrl)/teams/groups/$([System.Uri]::EscapeDataString($group.id))"
        if (-not [string]::IsNullOrWhiteSpace($BillingCycle)) {
            $url = "$url?billingCycle=$([System.Uri]::EscapeDataString($BillingCycle))"
        }
        $response = Invoke-CursorRequest -Method "GET" -Url $url -Headers $headers
        $groupPayload = Get-OptionalProperty -InputObject $response -Name "group"
        if (-not $groupPayload) { throw "Group payload missing from API response." }
        $members = @(Get-OptionalProperty -InputObject $groupPayload -Name "currentMembers" -DefaultValue @())
        Write-Info "Members in '$($groupPayload.name)': $($members.Count)"
        $members |
            Select-Object userId, name, email, joinedAt, spendCents |
            Sort-Object -Property email |
            Format-Table -AutoSize
        return
    }

    $members = Get-AllTeamMembers -EnvMap $EnvMap
    Write-Info "Team members: $($members.Count)"
    $members |
        Select-Object @{Name = "id"; Expression = { [string]$_.id } }, name, email, role, isRemoved |
        Sort-Object -Property email |
        Format-Table -AutoSize
}

function List-BillingGroups {
    param([hashtable]$EnvMap)

    $response = Get-BillingGroupsResponse -EnvMap $EnvMap
    $groups = @()
    $normalGroups = @(Get-OptionalProperty -InputObject $response -Name "groups" -DefaultValue @())
    if ($normalGroups.Count -gt 0) {
        $groups += $normalGroups
    }

    $unassigned = Get-OptionalProperty -InputObject $response -Name "unassignedGroup"
    if ($unassigned) {
        $groups += $unassigned
    }

    Write-Info "Billing groups: $($groups.Count)"

    if (-not $IncludeMembers) {
        $groups |
            Select-Object id, name, type, directoryGroupId, memberCount, spendCents, createdAt, updatedAt |
            Sort-Object -Property name |
            Format-Table -AutoSize
        return
    }

    foreach ($group in ($groups | Sort-Object -Property name)) {
        Write-Host ""
        Write-Host "[$($group.id)] $($group.name) type=$($group.type) members=$($group.memberCount) spendCents=$($group.spendCents)"

        $currentMembers = @(Get-OptionalProperty -InputObject $group -Name "currentMembers" -DefaultValue @())
        if ($currentMembers.Count -eq 0) {
            Write-Host "  Current members: (none)"
        } else {
            Write-Host "  Current members: $($currentMembers.Count)"
            foreach ($m in $currentMembers) {
                Write-Host "   - $($m.userId) | $($m.email) | $($m.name) | joined=$($m.joinedAt)"
            }
        }

        $formerMembers = @(Get-OptionalProperty -InputObject $group -Name "formerMembers" -DefaultValue @())
        if ($formerMembers.Count -gt 0) {
            Write-Host "  Former members: $($formerMembers.Count)"
            foreach ($m in $formerMembers) {
                Write-Host "   - $($m.userId) | $($m.email) | $($m.name) | left=$($m.leftAt)"
            }
        }
    }
}

function List-ScimGroups {
    param([hashtable]$EnvMap)

    $groups = Get-AllScimGroups -EnvMap $EnvMap
    Write-Info "Regular groups (SCIM): $($groups.Count)"

    if (-not $IncludeMembers) {
        $groups |
            Select-Object id, displayName, externalId |
            Sort-Object -Property displayName |
            Format-Table -AutoSize
        return
    }

    foreach ($group in ($groups | Sort-Object -Property displayName)) {
        Write-Host ""
        Write-Host "[$($group.id)] $($group.displayName)"
        $members = @(Get-OptionalProperty -InputObject $group -Name "members" -DefaultValue @())
        if ($members.Count -eq 0) {
            Write-Host "  Members: (none)"
            continue
        }

        Write-Host "  Members: $($members.Count)"
        foreach ($member in $members) {
            Write-Host "   - $($member.value) | $($member.display)"
        }
    }
}

function List-Groups {
    param([hashtable]$EnvMap)
    if ($GroupType -eq "regular") {
        List-ScimGroups -EnvMap $EnvMap
        return
    }
    List-BillingGroups -EnvMap $EnvMap
}

function List-GroupMembers {
    param([hashtable]$EnvMap)

    if ($GroupType -eq "regular") {
        $group = Resolve-ScimGroup -EnvMap $EnvMap
        $members = @(Get-OptionalProperty -InputObject $group -Name "members" -DefaultValue @())
        Write-Info "SCIM group: $($group.displayName) ($($group.id))"
        Write-Info "Members: $($members.Count)"
        $members |
            Select-Object @{Name = "userId"; Expression = { $_.value } }, display, type |
            Sort-Object -Property display, userId |
            Format-Table -AutoSize
        return
    }

    $group = Resolve-BillingGroup -EnvMap $EnvMap
    $headers = Get-BasicHeaders -EnvMap $EnvMap
    $url = "$($script:AdminBaseUrl)/teams/groups/$([System.Uri]::EscapeDataString($group.id))"
    if (-not [string]::IsNullOrWhiteSpace($BillingCycle)) {
        $url = "$url?billingCycle=$([System.Uri]::EscapeDataString($BillingCycle))"
    }

    $response = Invoke-CursorRequest -Method "GET" -Url $url -Headers $headers
    $groupPayload = Get-OptionalProperty -InputObject $response -Name "group"
    if (-not $groupPayload) {
        throw "Group payload missing from API response."
    }

    $currentMembers = @(Get-OptionalProperty -InputObject $groupPayload -Name "currentMembers" -DefaultValue @())
    $formerMembers = @(Get-OptionalProperty -InputObject $groupPayload -Name "formerMembers" -DefaultValue @())

    Write-Info "Billing group: $($groupPayload.name) ($($groupPayload.id))"
    Write-Info "Current members: $($currentMembers.Count)"
    if ($currentMembers.Count -gt 0) {
        $currentMembers |
            Select-Object userId, name, email, joinedAt, leftAt, spendCents |
            Sort-Object -Property email, userId |
            Format-Table -AutoSize
    }

    if ($formerMembers.Count -gt 0) {
        Write-Host ""
        Write-Info "Former members: $($formerMembers.Count)"
        $formerMembers |
            Select-Object userId, name, email, joinedAt, leftAt, spendCents |
            Sort-Object -Property email, userId |
            Format-Table -AutoSize
    }
}

function Create-Group {
    param([hashtable]$EnvMap)
    Assert-RequiredArgument -Name "--group-name" -Value $GroupName

    if ($GroupType -eq "regular") {
        $headers = Get-ScimHeaders -EnvMap $EnvMap
        $base = Resolve-ScimBaseUrl -EnvMap $EnvMap
        $url = "$base/Groups"
        $body = @{
            schemas = @("urn:ietf:params:scim:schemas:core:2.0:Group")
            displayName = $GroupName
        }
        $response = Invoke-CursorRequest -Method "POST" -Url $url -Headers $headers -Body $body
        Write-Info "Created SCIM group '$($response.displayName)' with ID $($response.id)."
        return
    }

    $headers = Get-BasicHeaders -EnvMap $EnvMap -Json
    $url = "$($script:AdminBaseUrl)/teams/groups"
    $body = @{
        name = $GroupName
        type = "BILLING"
    }
    $response = Invoke-CursorRequest -Method "POST" -Url $url -Headers $headers -Body $body
    $group = Get-OptionalProperty -InputObject $response -Name "group"
    if (-not $group) {
        throw "Group payload missing from create response."
    }
    Write-Info "Created billing group '$($group.name)' with ID $($group.id)."
}

function Rename-Group {
    param([hashtable]$EnvMap)
    Assert-RequiredArgument -Name "--new-name" -Value $NewName

    if ($GroupType -eq "regular") {
        $group = Resolve-ScimGroup -EnvMap $EnvMap
        $headers = Get-ScimHeaders -EnvMap $EnvMap
        $base = Resolve-ScimBaseUrl -EnvMap $EnvMap
        $url = "$base/Groups/$([System.Uri]::EscapeDataString($group.id))"
        $body = @{
            schemas = @("urn:ietf:params:scim:api:messages:2.0:PatchOp")
            Operations = @(
                @{
                    op = "replace"
                    path = "displayName"
                    value = $NewName
                }
            )
        }

        Invoke-CursorRequest -Method "PATCH" -Url $url -Headers $headers -Body $body | Out-Null
        Write-Info "Renamed SCIM group '$($group.displayName)' -> '$NewName' (ID $($group.id))."
        return
    }

    $group = Resolve-BillingGroup -EnvMap $EnvMap
    $headers = Get-BasicHeaders -EnvMap $EnvMap -Json
    $url = "$($script:AdminBaseUrl)/teams/groups/$([System.Uri]::EscapeDataString($group.id))"
    $body = @{ name = $NewName }
    $response = Invoke-CursorRequest -Method "PATCH" -Url $url -Headers $headers -Body $body
    $updated = Get-OptionalProperty -InputObject $response -Name "group"
    if (-not $updated) {
        throw "Group payload missing from rename response."
    }
    Write-Info "Renamed billing group '$($group.name)' -> '$($updated.name)' (ID $($updated.id))."
}

function Remove-Group {
    param([hashtable]$EnvMap)

    if ($GroupType -eq "regular") {
        $group = Resolve-ScimGroup -EnvMap $EnvMap
        $headers = Get-ScimHeaders -EnvMap $EnvMap
        $base = Resolve-ScimBaseUrl -EnvMap $EnvMap
        $url = "$base/Groups/$([System.Uri]::EscapeDataString($group.id))"
        Invoke-CursorRequest -Method "DELETE" -Url $url -Headers $headers | Out-Null
        Write-Info "Deleted SCIM group '$($group.displayName)' (ID $($group.id))."
        return
    }

    $group = Resolve-BillingGroup -EnvMap $EnvMap
    $headers = Get-BasicHeaders -EnvMap $EnvMap
    $url = "$($script:AdminBaseUrl)/teams/groups/$([System.Uri]::EscapeDataString($group.id))"
    Invoke-CursorRequest -Method "DELETE" -Url $url -Headers $headers | Out-Null
    Write-Info "Deleted billing group '$($group.name)' (ID $($group.id))."
}

function Update-GroupMembership {
    param(
        [hashtable]$EnvMap,
        [ValidateSet("add", "remove")]
        [string]$Operation
    )

    if ($GroupType -eq "regular") {
        $group = Resolve-ScimGroup -EnvMap $EnvMap
        $targetUserIds = @(Resolve-ScimUserIds -EnvMap $EnvMap)
        $headers = Get-ScimHeaders -EnvMap $EnvMap
        $base = Resolve-ScimBaseUrl -EnvMap $EnvMap
        $url = "$base/Groups/$([System.Uri]::EscapeDataString($group.id))"
        $body = @{
            schemas = @("urn:ietf:params:scim:api:messages:2.0:PatchOp")
            Operations = @(
                @{
                    op = $Operation
                    path = "members"
                    value = @($targetUserIds | ForEach-Object { @{ value = $_ } })
                }
            )
        }

        Invoke-CursorRequest -Method "PATCH" -Url $url -Headers $headers -Body $body | Out-Null
        Write-Info "$Operation $($targetUserIds.Count) user(s) in SCIM group '$($group.displayName)' (ID $($group.id))."
        return
    }

    $group = Resolve-BillingGroup -EnvMap $EnvMap
    $targetUserIds = @(Resolve-BillingUserIds -EnvMap $EnvMap)
    $headers = Get-BasicHeaders -EnvMap $EnvMap -Json
    $url = "$($script:AdminBaseUrl)/teams/groups/$([System.Uri]::EscapeDataString($group.id))/members"
    $body = @{ userIds = @($targetUserIds | ForEach-Object { [string]$_ }) }

    if ($Operation -eq "add") {
        Invoke-CursorRequest -Method "POST" -Url $url -Headers $headers -Body $body | Out-Null
    } else {
        Invoke-CursorRequest -Method "DELETE" -Url $url -Headers $headers -Body $body | Out-Null
    }

    Write-Info "$Operation $($targetUserIds.Count) user(s) in billing group '$($group.name)' (ID $($group.id))."
}

try {
    Parse-Arguments -InputArgs $args

    if (-not $script:Command) {
        Show-Help
        Write-Host "──────────────────────────────────────────────────────────────"
        $script:Command = Read-Prompt -Message "Command"
        $script:Command = $script:Command -replace '^--', ''
        $script:Command = switch -Regex ($script:Command) {
            '^(h|help)$'                          { 'help' }
            '^(lg|list-groups)$'                  { 'list-groups' }
            '^(lm|list-members)$'                 { 'list-members' }
            '^(lu|list-users)$'                   { 'list-users' }
            '^(cg|create-group)$'                 { 'create-group' }
            '^(rg|rename-group)$'                 { 'rename-group' }
            '^(dg|remove-group)$'                 { 'remove-group' }
            '^(au|add-user)$'                     { 'add-user' }
            '^(ru|remove-user)$'                  { 'remove-user' }
            '^(cu|create-user)$'                  { 'create-user' }
            default                               { $script:Command }
        }
    }

    if ($script:Command -eq "help") {
        Show-Help
        exit 0
    }

    if ($script:Command -ne "create-user") {
        if ([string]::IsNullOrWhiteSpace($GroupType)) {
            $script:GroupType = Read-Prompt -Message "Group type (billing/regular)" -Default "billing"
        }
        if ($GroupType -notin @("billing", "regular")) {
            throw "Unsupported --group-type '$GroupType'. Allowed: billing, regular."
        }
    }

    if ($script:Command -in @("list-members", "rename-group", "remove-group", "add-user", "remove-user", "create-group", "create-user")) {
        if ([string]::IsNullOrWhiteSpace($GroupId) -and [string]::IsNullOrWhiteSpace($GroupName)) {
            $script:GroupName = Read-Prompt -Message "Group name"
        }
    }
    if ($script:Command -eq "rename-group") {
        if ([string]::IsNullOrWhiteSpace($NewName)) {
            $script:NewName = Read-Prompt -Message "New name"
        }
    }
    if ($script:Command -in @("add-user", "remove-user", "create-user")) {
        if ($script:UserIds.Count -eq 0 -and $script:UserEmails.Count -eq 0) {
            $raw = Read-Prompt -Message "User email(s) (comma-separated)"
            $script:UserEmails = @($raw -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
        }
    }

    $envMap = Load-EnvFile -Path $CredsFile
    if ($envMap.Count -eq 0) {
        Write-VerboseInfo "No env file loaded from '$CredsFile'; using process environment only."
    } else {
        Write-VerboseInfo "Loaded env keys from '$CredsFile'."
    }

    switch ($script:Command) {
        "list-users" { List-Users -EnvMap $envMap }
        "list-groups" { List-Groups -EnvMap $envMap }
        "list-members" { List-GroupMembers -EnvMap $envMap }
        "create-group" { Create-Group -EnvMap $envMap }
        "rename-group" { Rename-Group -EnvMap $envMap }
        "remove-group" { Remove-Group -EnvMap $envMap }
        "add-user" { Update-GroupMembership -EnvMap $envMap -Operation "add" }
        "remove-user" { Update-GroupMembership -EnvMap $envMap -Operation "remove" }
        "create-user" { Create-ScimUsers -EnvMap $envMap }
        default { throw "Unsupported command: $($script:Command)" }
    }
} catch {
    $errorMessage = $_.ErrorDetails?.Message
    if ([string]::IsNullOrWhiteSpace($errorMessage)) {
        $errorMessage = [string]$_
    }
    if ([string]::IsNullOrWhiteSpace($errorMessage)) {
        $errorMessage = "Unexpected error. Run with --verbose-output for details."
    }
    Write-Host "[error] $errorMessage"
    exit 1
}
