Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:AdminBaseUrl = "https://api.canva.com/admin/v1"
$script:ScimBaseUrl = "https://www.canva.com/_scim/v2"
$script:ResolvedTeam = $null
$script:OAuthToken = $null
$script:ScimToken = $null
$script:Command = $null
$script:GroupType = $null
$script:ScimUsersCache = $null

$script:GroupId = $null
$script:GroupName = $null
$script:NewName = $null
$script:Description = $null
$script:UserEmails = @()
$script:UserIds = @()
$script:Interactive = $false
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
            "^(--description|-Description|-d)$" {
                if ($argsQueue.Count -eq 0) { throw "Missing value for $token" }
                $script:Description = $argsQueue.Dequeue()
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
  --list-teams | -ListTeams | -lt                                              (Admin API only)
  --list-users | -ListUsers | -lu
  --list-groups | -ListGroups | -lg [--include-members | -im] [--team-id <id> | --team-name <name>]
  --list-members | -ListMembers | -lm --group-id <id> | --group-name <name>
  --create-group | -CreateGroup | -cg --group-name <name> [--description <text>]
  --rename-group | -RenameGroup | -rg (--group-id <id> | --group-name <name>) --new-name <name> [--description <text>]
  --remove-group | -RemoveGroup | -dg --group-id <id> | --group-name <name>
  --add-user | -AddUser | -au (--group-id <id> | --group-name <name>) (--user-email <email> | --user-id <id>)
  --remove-user | -RemoveUser | -ru (--group-id <id> | --group-name <name>) (--user-email <email> | --user-id <id>)

Common options:
  --group-type <admin|scim> | -GroupType <admin|scim> | -gt <admin|scim>   (default: admin)
  --group-id <id> | -GroupId <id> | -gid <id>
  --group-name <name> | -GroupName <name> | -gn <name>
  --new-name <name> | -NewName <name> | -nn <name>
  --description <text> | -Description <text> | -d <text>   (admin group type only)
  --user-email <email> | -UserEmail <email> | -ue <email>
  --user-id <id> | -UserId <id> | -uid <id>
  --team-id <id> | -TeamId <id> | -tid <id>                (admin group type only)
                                                           --list-groups lists every team when omitted
  --team-name <name> | -TeamName <name> | -tn <name>       (admin group type only)
  --creds-file <path> | -CredsFile <path> | -cf <path>     (default: ./.env)
  --include-members | -IncludeMembers | -im
  --verbose-output | -VerboseOutput | -v

Group types:
  admin  Canva Admin API groups (https://api.canva.com/admin/v1). Needs CANVA_OAUTH_CLIENT_ID/SECRET.
  scim   Canva SCIM v2 groups (https://www.canva.com/_scim/v2). Needs CANVA_SCIM_TOKEN only.
         Canva's SCIM API always returns an empty members array, so member listings are
         only available with --group-type admin.

Environment keys (from .env and/or process env):
  CANVA_OAUTH_CLIENT_ID
  CANVA_OAUTH_CLIENT_SECRET
  CANVA_SCIM_TOKEN

Examples:
  pwsh ./canva-group-ops.ps1 --list-groups
  pwsh ./canva-group-ops.ps1 -lg -im
  pwsh ./canva-group-ops.ps1 -lg -tn "ByteDance / TikTok"
  pwsh ./canva-group-ops.ps1 -lg -gt scim
  pwsh ./canva-group-ops.ps1 -lm -gn "ByteDance"
  pwsh ./canva-group-ops.ps1 -cg -gn "Marketing" -d "Marketing team"
  pwsh ./canva-group-ops.ps1 -cg -gt scim -gn "Marketing"
  pwsh ./canva-group-ops.ps1 -rg -gid G123 -nn "Marketing Ops"
  pwsh ./canva-group-ops.ps1 -au -gn "ByteDance" -ue user@company.com
  pwsh ./canva-group-ops.ps1 -au -gt scim -gn "ByteDance" -ue user@company.com
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
    $value = Read-Host
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
    param(
        [hashtable]$EnvMap,
        [string]$AdminTeamId
    )

    $resolvedTeamId = $AdminTeamId
    if ([string]::IsNullOrWhiteSpace($resolvedTeamId)) {
        $team = Resolve-Team -EnvMap $EnvMap
        $resolvedTeamId = $team.id
    }

    $headers = Get-AdminHeaders -EnvMap $EnvMap
    $allGroups = @()
    $continuation = $null

    do {
        $url = "$($script:AdminBaseUrl)/teams/$([System.Uri]::EscapeDataString($resolvedTeamId))/groups?limit=100"
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
    # Canva's SCIM API caps "count" at 10.
    $count = 10
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

function Get-AllScimUsers {
    param([hashtable]$EnvMap)

    if ($null -ne $script:ScimUsersCache) {
        return $script:ScimUsersCache
    }

    $headers = Get-ScimHeaders -EnvMap $EnvMap
    $allUsers = @()
    # Canva's SCIM API caps "count" at 10.
    $count = 10
    $startIndex = 1

    while ($true) {
        $url = "$($script:ScimBaseUrl)/Users?count=$count&startIndex=$startIndex"
        $response = Invoke-CanvaRequest -Method "GET" -Url $url -Headers $headers
        $resources = @()
        $resourcesProperty = Get-OptionalProperty -InputObject $response -Name "Resources"
        if ($resourcesProperty) {
            $resources = @($resourcesProperty)
        }
        if ($resources.Count -eq 0) {
            break
        }

        $allUsers += $resources

        $totalResults = Get-OptionalProperty -InputObject $response -Name "totalResults"
        if ($totalResults -and $allUsers.Count -ge [int]$totalResults) {
            break
        }
        $startIndex += $resources.Count
    }

    $script:ScimUsersCache = $allUsers
    return $script:ScimUsersCache
}

function Get-ScimUserEmail {
    param([object]$ScimUser)

    $emails = Get-OptionalProperty -InputObject $ScimUser -Name "emails"
    if ($emails) {
        $primary = @($emails | Where-Object { (Get-OptionalProperty -InputObject $_ -Name "primary" -DefaultValue $false) -eq $true }) | Select-Object -First 1
        if ($primary) {
            $primaryValue = Get-OptionalProperty -InputObject $primary -Name "value"
            if (-not [string]::IsNullOrWhiteSpace([string]$primaryValue)) {
                return [string]$primaryValue
            }
        }

        $first = @($emails) | Select-Object -First 1
        if ($first) {
            $firstValue = Get-OptionalProperty -InputObject $first -Name "value"
            if (-not [string]::IsNullOrWhiteSpace([string]$firstValue)) {
                return [string]$firstValue
            }
        }
    }

    $userName = Get-OptionalProperty -InputObject $ScimUser -Name "userName"
    if (-not [string]::IsNullOrWhiteSpace([string]$userName)) {
        return [string]$userName
    }

    return $null
}

function Get-ScimUserByEmail {
    param(
        [hashtable]$EnvMap,
        [Parameter(Mandatory = $true)]
        [string]$Email
    )

    $users = Get-AllScimUsers -EnvMap $EnvMap
    $needle = $Email.ToLowerInvariant()
    $found = @($users | Where-Object {
        $candidate = Get-ScimUserEmail -ScimUser $_
        $candidate -and $candidate.ToLowerInvariant() -eq $needle
    })

    if ($found.Count -eq 0) {
        throw "No Canva SCIM user found with email '$Email'."
    }
    if ($found.Count -gt 1) {
        throw "Multiple Canva SCIM users found with email '$Email'. Use --user-id."
    }
    return $found[0]
}

function Resolve-AdminGroup {
    param([hashtable]$EnvMap)

    if ([string]::IsNullOrWhiteSpace($GroupId) -and [string]::IsNullOrWhiteSpace($GroupName)) {
        throw "Provide either --group-id or --group-name."
    }

    $groups = Get-AllAdminGroups -EnvMap $EnvMap

    if (-not [string]::IsNullOrWhiteSpace($GroupId)) {
        $idMatches = @($groups | Where-Object { $_.id -eq $GroupId })
        if ($idMatches.Count -eq 0) {
            throw "Admin group ID '$GroupId' was not found."
        }
        return $idMatches[0]
    }

    $nameMatches = @($groups | Where-Object { $_.name -eq $GroupName })
    if ($nameMatches.Count -eq 0) {
        throw "Admin group '$GroupName' was not found."
    }
    if ($nameMatches.Count -gt 1) {
        throw "Multiple Admin groups matched '$GroupName'. Use --group-id."
    }
    return $nameMatches[0]
}

function Resolve-ScimGroup {
    param([hashtable]$EnvMap)

    if ([string]::IsNullOrWhiteSpace($GroupId) -and [string]::IsNullOrWhiteSpace($GroupName)) {
        throw "Provide either --group-id or --group-name."
    }

    $headers = Get-ScimHeaders -EnvMap $EnvMap

    if (-not [string]::IsNullOrWhiteSpace($GroupId)) {
        $url = "$($script:ScimBaseUrl)/Groups/$([System.Uri]::EscapeDataString($GroupId))"
        return Invoke-CanvaRequest -Method "GET" -Url $url -Headers $headers
    }

    $filter = "displayName eq `"$GroupName`""
    $url = "$($script:ScimBaseUrl)/Groups?filter=$([System.Uri]::EscapeDataString($filter))"
    $response = Invoke-CanvaRequest -Method "GET" -Url $url -Headers $headers

    $resources = @()
    $resourcesProperty = Get-OptionalProperty -InputObject $response -Name "Resources"
    if ($resourcesProperty) {
        $resources = @($resourcesProperty)
    }

    $nameMatches = @($resources | Where-Object { $_.displayName -eq $GroupName })
    if ($nameMatches.Count -eq 0) {
        throw "SCIM group '$GroupName' was not found."
    }
    if ($nameMatches.Count -gt 1) {
        throw "Multiple SCIM groups matched '$GroupName'. Use --group-id."
    }
    return $nameMatches[0]
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

function List-ScimGroups {
    param([hashtable]$EnvMap)

    $groups = Get-AllScimGroups -EnvMap $EnvMap
    Write-Info "SCIM groups: $($groups.Count)"
    if ($IncludeMembers) {
        Write-Info "Canva's SCIM API always returns an empty members array. Use --group-type admin to list members."
    }

    $groups |
        Sort-Object -Property displayName |
        Select-Object id, displayName, externalId |
        Format-Table -AutoSize
}

function List-Groups {
    param([hashtable]$EnvMap)

    if ($GroupType -eq "scim") {
        List-ScimGroups -EnvMap $EnvMap
        return
    }

    # The Admin API requires a teamId to list groups, so with no --team-id/--team-name
    # we fan out over every team in the organization.
    $allTeamsMode = $false
    $teams = @()
    if ([string]::IsNullOrWhiteSpace($TeamId) -and [string]::IsNullOrWhiteSpace($TeamName)) {
        $teams = @(Get-AllTeams -EnvMap $EnvMap)
        if ($teams.Count -gt 1) {
            $allTeamsMode = $true
            Write-Info "Listing groups across all $($teams.Count) teams. Use --team-id or --team-name to target one."
        }
    } else {
        $teams = @(Resolve-Team -EnvMap $EnvMap)
    }

    $usersById = $null
    if ($IncludeMembers) {
        $usersById = Get-AdminUsersMap -EnvMap $EnvMap
    }

    $rows = @()
    $totalGroups = 0

    foreach ($team in $teams) {
        $groups = @(Get-AllAdminGroups -EnvMap $EnvMap -AdminTeamId $team.id)
        $totalGroups += $groups.Count

        if (-not $IncludeMembers) {
            foreach ($group in $groups) {
                $rows += [PSCustomObject]@{
                    team        = $team.name
                    team_id     = $team.id
                    id          = $group.id
                    name        = $group.name
                    description = Get-OptionalProperty -InputObject $group -Name "description"
                    created_at  = Get-OptionalProperty -InputObject $group -Name "created_at"
                    updated_at  = Get-OptionalProperty -InputObject $group -Name "updated_at"
                }
            }
            continue
        }

        Write-Host ""
        Write-Host "=== Team: $($team.name) ($($team.id)) - groups: $($groups.Count)"
        foreach ($group in ($groups | Sort-Object -Property name)) {
            $groupDescription = Get-OptionalProperty -InputObject $group -Name "description"
            Write-Host ""
            Write-Host "[$($group.id)] $($group.name)"
            if (-not [string]::IsNullOrWhiteSpace([string]$groupDescription)) {
                Write-Host "  Description: $groupDescription"
            }

            $members = Get-GroupMembersInternal -EnvMap $EnvMap -AdminGroupId $group.id -AdminTeamId $team.id
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

    if ($IncludeMembers) {
        Write-Host ""
        Write-Info "Groups: $totalGroups"
        return
    }

    if (-not $allTeamsMode) {
        Write-Info "Team: $($teams[0].name) ($($teams[0].id))"
    }
    Write-Info "Groups: $totalGroups"

    if ($allTeamsMode) {
        $rows |
            Sort-Object -Property team, name |
            Select-Object team, id, name, description, created_at, updated_at |
            Format-Table -AutoSize
        return
    }

    $rows |
        Sort-Object -Property name |
        Select-Object id, name, description, created_at, updated_at |
        Format-Table -AutoSize
}

function Get-GroupMembersInternal {
    param(
        [hashtable]$EnvMap,
        [Parameter(Mandatory = $true)]
        [string]$AdminGroupId,
        [string]$AdminTeamId
    )

    $resolvedTeamId = $AdminTeamId
    if ([string]::IsNullOrWhiteSpace($resolvedTeamId)) {
        $team = Resolve-Team -EnvMap $EnvMap
        $resolvedTeamId = $team.id
    }

    $headers = Get-AdminHeaders -EnvMap $EnvMap
    $allMembers = @()
    $continuation = $null

    do {
        $url = "$($script:AdminBaseUrl)/teams/$([System.Uri]::EscapeDataString($resolvedTeamId))/groups/$([System.Uri]::EscapeDataString($AdminGroupId))/members?limit=100"
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

    if ($GroupType -eq "scim") {
        $scimGroup = Resolve-ScimGroup -EnvMap $EnvMap
        $scimMembers = @(Get-OptionalProperty -InputObject $scimGroup -Name "members" -DefaultValue @())
        Write-Info "SCIM group: $($scimGroup.displayName) ($($scimGroup.id))"
        Write-Info "Canva's SCIM API always returns an empty members array, even when the group has members."
        Write-Info "Use --group-type admin to list members."
        Write-Info "Members returned: $($scimMembers.Count)"
        if ($scimMembers.Count -gt 0) {
            $scimMembers |
                Select-Object @{Name = "user_id"; Expression = { $_.value } }, display, type |
                Sort-Object -Property display, user_id |
                Format-Table -AutoSize
        }
        return
    }

    $group = Resolve-AdminGroup -EnvMap $EnvMap
    $members = Get-GroupMembersInternal -EnvMap $EnvMap -AdminGroupId $group.id
    $usersById = Get-AdminUsersMap -EnvMap $EnvMap

    Write-Info "Group: $($group.name)"
    Write-Info "Admin ID: $($group.id)"
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

    if ($GroupType -eq "scim") {
        $scimHeaders = Get-ScimHeaders -EnvMap $EnvMap
        $scimUrl = "$($script:ScimBaseUrl)/Groups"
        $scimBody = @{
            schemas     = @("urn:ietf:params:scim:schemas:core:2.0:Group")
            displayName = $GroupName
        }
        $scimResponse = Invoke-CanvaRequest -Method "POST" -Url $scimUrl -Headers $scimHeaders -Body $scimBody
        Write-Info "Created SCIM group '$($scimResponse.displayName)' with ID $($scimResponse.id)."
        return
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
    Write-Info "Created Admin group '$($response.group.name)' with ID $($response.group.id)."
}

function Rename-Group {
    param([hashtable]$EnvMap)

    if ([string]::IsNullOrWhiteSpace($NewName)) {
        throw "-NewName is required for rename-group."
    }

    if ($GroupType -eq "scim") {
        $scimGroup = Resolve-ScimGroup -EnvMap $EnvMap
        $scimHeaders = Get-ScimHeaders -EnvMap $EnvMap
        $scimUrl = "$($script:ScimBaseUrl)/Groups/$([System.Uri]::EscapeDataString($scimGroup.id))"
        $scimBody = @{
            schemas    = @("urn:ietf:params:scim:api:messages:2.0:PatchOp")
            Operations = @(
                @{
                    op    = "replace"
                    path  = "displayName"
                    value = $NewName
                }
            )
        }
        Invoke-CanvaRequest -Method "PATCH" -Url $scimUrl -Headers $scimHeaders -Body $scimBody | Out-Null
        Write-Info "Renamed SCIM group '$($scimGroup.displayName)' -> '$NewName' (ID $($scimGroup.id))."
        return
    }

    $team = Resolve-Team -EnvMap $EnvMap
    $group = Resolve-AdminGroup -EnvMap $EnvMap

    $headers = Get-AdminJsonHeaders -EnvMap $EnvMap
    $url = "$($script:AdminBaseUrl)/teams/$([System.Uri]::EscapeDataString($team.id))/groups/$([System.Uri]::EscapeDataString($group.id))"
    $body = @{
        name = $NewName
    }
    if (-not [string]::IsNullOrWhiteSpace($Description)) {
        $body["description"] = $Description
    } else {
        $existingDescription = Get-OptionalProperty -InputObject $group -Name "description"
        if (-not [string]::IsNullOrWhiteSpace([string]$existingDescription)) {
            $body["description"] = $existingDescription
        }
    }

    $response = Invoke-CanvaRequest -Method "PATCH" -Url $url -Headers $headers -Body $body
    Write-Info "Renamed Admin group '$($group.name)' -> '$($response.group.name)' (ID $($response.group.id))."
}

function Remove-Group {
    param([hashtable]$EnvMap)

    if ($GroupType -eq "scim") {
        $scimGroup = Resolve-ScimGroup -EnvMap $EnvMap
        $scimHeaders = Get-ScimHeaders -EnvMap $EnvMap
        $scimUrl = "$($script:ScimBaseUrl)/Groups/$([System.Uri]::EscapeDataString($scimGroup.id))"
        Invoke-CanvaRequest -Method "DELETE" -Url $scimUrl -Headers $scimHeaders | Out-Null
        Write-Info "Deleted SCIM group '$($scimGroup.displayName)' (ID $($scimGroup.id))."
        return
    }

    $team = Resolve-Team -EnvMap $EnvMap
    $group = Resolve-AdminGroup -EnvMap $EnvMap
    $headers = Get-AdminHeaders -EnvMap $EnvMap
    $url = "$($script:AdminBaseUrl)/teams/$([System.Uri]::EscapeDataString($team.id))/groups/$([System.Uri]::EscapeDataString($group.id))"
    Invoke-CanvaRequest -Method "DELETE" -Url $url -Headers $headers | Out-Null
    Write-Info "Deleted Admin group '$($group.name)' (ID $($group.id))."
}

function Update-GroupMembership {
    param(
        [hashtable]$EnvMap,
        [ValidateSet("add", "remove")]
        [string]$Operation
    )

    if ($script:UserIds.Count -eq 0 -and $script:UserEmails.Count -eq 0) {
        throw "Provide --user-email or --user-id."
    }

    if ($GroupType -eq "scim") {
        $scimGroup = Resolve-ScimGroup -EnvMap $EnvMap

        $scimTargets = @()
        foreach ($uid in $script:UserIds) {
            $scimTargets += [PSCustomObject]@{ Id = $uid; Label = $uid }
        }
        foreach ($email in $script:UserEmails) {
            try {
                $scimUser = Get-ScimUserByEmail -EnvMap $EnvMap -Email $email
                $scimTargets += [PSCustomObject]@{ Id = $scimUser.id; Label = $email }
            } catch {
                Write-Host "[error] $($email): $_"
            }
        }

        if ($scimTargets.Count -eq 0) { return }

        $scimHeaders = Get-ScimHeaders -EnvMap $EnvMap
        $scimUrl = "$($script:ScimBaseUrl)/Groups/$([System.Uri]::EscapeDataString($scimGroup.id))"

        foreach ($target in $scimTargets) {
            $scimBody = @{
                schemas    = @("urn:ietf:params:scim:api:messages:2.0:PatchOp")
                Operations = @(
                    @{
                        op    = $Operation
                        path  = "members"
                        value = @(@{ value = $target.Id })
                    }
                )
            }
            try {
                Invoke-CanvaRequest -Method "PATCH" -Url $scimUrl -Headers $scimHeaders -Body $scimBody | Out-Null
                Write-Info "$Operation user '$($target.Label)' (id=$($target.Id)) in SCIM group '$($scimGroup.displayName)' (ID $($scimGroup.id))."
            } catch {
                Write-Host "[error] $($target.Label): $_"
            }
        }
        return
    }

    $team = Resolve-Team -EnvMap $EnvMap
    $group = Resolve-AdminGroup -EnvMap $EnvMap

    $targets = @()
    foreach ($uid in $script:UserIds) {
        $targets += [PSCustomObject]@{ Id = $uid; Label = $uid }
    }
    foreach ($email in $script:UserEmails) {
        try {
            $user = Get-UserByEmail -EnvMap $EnvMap -Email $email
            $targets += [PSCustomObject]@{ Id = $user.id; Label = (Get-OptionalProperty -InputObject $user -Name "email" -DefaultValue $email) }
        } catch {
            Write-Host "[error] $($email): $_"
        }
    }

    if ($targets.Count -eq 0) { return }

    $headers = Get-AdminJsonHeaders -EnvMap $EnvMap
    $membersUrl = "$($script:AdminBaseUrl)/teams/$([System.Uri]::EscapeDataString($team.id))/groups/$([System.Uri]::EscapeDataString($group.id))/members"

    foreach ($target in $targets) {
        try {
            if ($Operation -eq "add") {
                $body = @{
                    user_id = $target.Id
                    role    = "member"
                }
                Invoke-CanvaRequest -Method "POST" -Url $membersUrl -Headers $headers -Body $body | Out-Null
            } else {
                $deleteUrl = "$membersUrl/$([System.Uri]::EscapeDataString($target.Id))"
                Invoke-CanvaRequest -Method "DELETE" -Url $deleteUrl -Headers $headers | Out-Null
            }
            Write-Info "$Operation user '$($target.Label)' (id=$($target.Id)) in Admin group '$($group.name)' (ID $($group.id))."
        } catch {
            Write-Host "[error] $($target.Label): $_"
        }
    }
}

function List-Users {
    param([hashtable]$EnvMap)

    if ($GroupType -eq "scim") {
        $scimUsers = Get-AllScimUsers -EnvMap $EnvMap
        Write-Info "SCIM users: $($scimUsers.Count)"
        $rows = @()
        foreach ($scimUser in $scimUsers) {
            $rows += [PSCustomObject]@{
                id          = [string](Get-OptionalProperty -InputObject $scimUser -Name "id")
                userName    = [string](Get-OptionalProperty -InputObject $scimUser -Name "userName")
                email       = Get-ScimUserEmail -ScimUser $scimUser
                active      = Get-OptionalProperty -InputObject $scimUser -Name "active"
                displayName = [string](Get-OptionalProperty -InputObject $scimUser -Name "displayName")
            }
        }
        $rows | Sort-Object -Property email, userName | Format-Table -AutoSize
        return
    }

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
        $script:Interactive = $true
        Write-Host "Commands:"
        Write-Host "  list-groups   (lg)"
        Write-Host "  list-members  (lm)"
        Write-Host "  list-users    (lu)"
        Write-Host "  list-teams    (lt)"
        Write-Host "  create-group  (cg)"
        Write-Host "  rename-group  (rg)"
        Write-Host "  remove-group  (dg)"
        Write-Host "  add-user      (au)"
        Write-Host "  remove-user   (ru)"
        Write-Host "  help          (h)"
        Write-Host "  exit"
        $script:Command = Read-Prompt -Message "Command"
        $script:Command = switch -Regex ($script:Command.ToLowerInvariant()) {
            '^(lg|list-groups)$'   { 'list-groups' }
            '^(lm|list-members)$'  { 'list-members' }
            '^(lu|list-users)$'    { 'list-users' }
            '^(lt|list-teams)$'    { 'list-teams' }
            '^(cg|create-group)$'  { 'create-group' }
            '^(rg|rename-group)$'  { 'rename-group' }
            '^(dg|remove-group)$'  { 'remove-group' }
            '^(au|add-user)$'      { 'add-user' }
            '^(ru|remove-user)$'   { 'remove-user' }
            '^(h|help)$'           { 'help' }
            '^(q|quit|exit)$'      { 'exit' }
            default                { $script:Command }
        }
    }

    if ($script:Command -eq "exit") { exit 0 }

    if ($script:Command -eq "help") {
        Show-Help
        exit 0
    }

    if ($script:Command -eq "list-teams") {
        if (-not [string]::IsNullOrWhiteSpace($script:GroupType) -and $script:GroupType -ne "admin") {
            throw "--list-teams is only available with --group-type admin."
        }
    } else {
        if ([string]::IsNullOrWhiteSpace($script:GroupType)) {
            if ($script:Interactive) {
                $script:GroupType = Read-Prompt -Message "Group type (admin/scim)" -Default "admin"
            } else {
                $script:GroupType = "admin"
            }
        }
        $script:GroupType = $script:GroupType.ToLowerInvariant()
        if ($script:GroupType -notin @("admin", "scim")) {
            throw "Unsupported --group-type '$($script:GroupType)'. Allowed: admin, scim."
        }
        if ($script:GroupType -eq "scim" -and -not [string]::IsNullOrWhiteSpace($script:Description)) {
            throw "--description is only supported with --group-type admin. SCIM groups have no description attribute."
        }
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
        if ($script:UserIds.Count -eq 0 -and $script:UserEmails.Count -eq 0) {
            Write-Host -NoNewline -ForegroundColor Cyan "? "
            Write-Host "User email(s) — paste from Excel or enter one per line, then blank line to finish:"
            $lines = @()
            while ($true) {
                $line = Read-Host
                if ([string]::IsNullOrWhiteSpace($line)) { break }
                $lines += $line
            }
            $script:UserEmails = @($lines | ForEach-Object { $_ -split '[,\t]+' } | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
        }
    }

    $envMap = Load-EnvFile -Path $CredsFile
    if ($envMap.Count -eq 0) {
        Write-VerboseInfo "No env file loaded from '$CredsFile'; using process environment only."
    } else {
        Write-VerboseInfo "Loaded env keys from '$CredsFile'."
    }
    $skipTeamBanner = ($script:Command -eq "list-groups" -and [string]::IsNullOrWhiteSpace($script:TeamId) -and [string]::IsNullOrWhiteSpace($script:TeamName))
    if ($script:Command -ne "list-teams" -and $script:GroupType -eq "admin" -and -not $skipTeamBanner) {
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

    if ($script:Interactive) {
        $parts = @("pwsh ./canva-group-ops.ps1")
        $parts += "--$($script:Command)"
        if ($script:Command -ne "list-teams" -and -not [string]::IsNullOrWhiteSpace($script:GroupType)) {
            $parts += "--group-type $($script:GroupType)"
        }
        if (-not [string]::IsNullOrWhiteSpace($script:GroupId))      { $parts += "--group-id $($script:GroupId)" }
        if (-not [string]::IsNullOrWhiteSpace($script:GroupName))    { $parts += "--group-name `"$($script:GroupName)`"" }
        if (-not [string]::IsNullOrWhiteSpace($script:NewName))      { $parts += "--new-name `"$($script:NewName)`"" }
        if (-not [string]::IsNullOrWhiteSpace($script:Description))  { $parts += "--description `"$($script:Description)`"" }
        if ($script:UserEmails.Count -gt 0) { $parts += "--user-email `"$($script:UserEmails -join ',')`"" }
        if ($script:UserIds.Count -gt 0)    { $parts += "--user-id `"$($script:UserIds -join ',')`"" }
        if (-not [string]::IsNullOrWhiteSpace($script:TeamId))       { $parts += "--team-id $($script:TeamId)" }
        if (-not [string]::IsNullOrWhiteSpace($script:TeamName))     { $parts += "--team-name `"$($script:TeamName)`"" }
        if ($script:IncludeMembers) { $parts += "--include-members" }
        Write-Host ""
        Write-Host "CLI equivalent: $($parts -join ' ')"
    }
} catch {
    $errorMessage = if ($_.ErrorDetails) { $_.ErrorDetails.Message } else { $null }
    if ([string]::IsNullOrWhiteSpace($errorMessage)) {
        $errorMessage = [string]$_
    }
    if ([string]::IsNullOrWhiteSpace($errorMessage)) {
        $errorMessage = "Unexpected error. Run with --verbose-output for details."
    }
    Write-Host "[error] $errorMessage"
    exit 1
}
