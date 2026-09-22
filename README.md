# Group Ops CLIs

This repo contains PowerShell CLIs for group administration workflows:

- `canva-group-ops.ps1`
- `cursor-group-ops.ps1`

## Environment Keys By App

Both scripts use `./.env` by default. You can override either with `--creds-file`.

### Cursor (`cursor-group-ops.ps1`)

- `CURSOR_API_KEY`
  - Used for Cursor Admin API operations (billing groups and team members).
  - Required for `--group-type billing`.
- `CURSOR_SCIM_TOKEN`
  - Used for SCIM operations (regular groups and SCIM users).
  - Required for `--group-type regular`.
- `CURSOR_SCIM_BASE_URL`
  - SCIM base URL for your Cursor org.
  - Required for `--group-type regular` unless passed via `--scim-base-url`.

### Canva (`canva-group-ops.ps1`)

- `CANVA_OAUTH_CLIENT_ID`
  - Used to mint Canva Admin API OAuth token.
  - Required for `--group-type admin` (the default).
- `CANVA_OAUTH_CLIENT_SECRET`
  - Used to mint Canva Admin API OAuth token.
  - Required for `--group-type admin` (the default).
- `CANVA_SCIM_TOKEN`
  - Used for Canva SCIM v2 operations.
  - Required for `--group-type scim`, and is the only credential that group type needs.

### Combined Example `.env`

```bash
# Cursor
CURSOR_API_KEY=key_xxx
CURSOR_SCIM_TOKEN=xxx
CURSOR_SCIM_BASE_URL=https://api.workos.com/scim/v2/...

# Canva
CANVA_OAUTH_CLIENT_ID=xxx
CANVA_OAUTH_CLIENT_SECRET=xxx
CANVA_SCIM_TOKEN=xxx
```

## Cursor Group Ops

Manages Cursor billing groups (Admin API) and regular/SCIM groups. Supports two group types:

- `billing` — Cursor Admin API billing groups
- `regular` — SCIM groups (WorkOS-backed, via `CURSOR_SCIM_BASE_URL`)

### Requirements

- PowerShell 5.1 or later (`powershell` or `pwsh`)
- Credentials in `./.env` (default) or pass `--creds-file`

### Step-by-step (interactive) mode

The easiest way to use the script is to run it with no arguments. It will prompt you for everything:

```powershell
pwsh ./cursor-group-ops.ps1
```

You'll be asked to choose a command, then prompted for any required inputs:

```
Commands:
  list-groups   (lg)
  list-members  (lm)
  list-users    (lu)
  create-group  (cg)
  rename-group  (rg)
  remove-group  (dg)
  add-user      (au)
  remove-user   (ru)
  create-user   (cu)
  help          (h)
  exit

? Command: add-user
? Group type (billing/regular) [billing]:
? Group name: Engineering
? User email(s) — paste from Excel or enter one per line, then blank line to finish:
user@company.com

[info] Added user@company.com to billing group 'Engineering'.
```

**Tip:** when entering emails, you can paste a column copied from Excel — each row is treated as a separate email. Finish with a blank line.

After each run, the script prints the equivalent CLI command:

```
CLI equivalent: pwsh ./cursor-group-ops.ps1 --add-user --group-type billing --group-name "Engineering" --user-email "user@company.com"
```

This makes it easy to learn the CLI flags or build automations from actions you've already done interactively.

### CLI mode

Pass flags directly to skip the prompts. Useful for scripting or when you already know what you want.

**Group type** (`--group-type` / `-gt`): `billing` (default) or `regular`

Common operations:

```powershell
# List groups
pwsh ./cursor-group-ops.ps1 -lg
pwsh ./cursor-group-ops.ps1 -lg -gt regular
pwsh ./cursor-group-ops.ps1 -lg -im          # include members

# Add / remove a user from a group
pwsh ./cursor-group-ops.ps1 -au -gn "Engineering" -ue "user@company.com"
pwsh ./cursor-group-ops.ps1 -ru -gn "Engineering" -ue "user@company.com"

# Create a SCIM user and add to a group in one step
pwsh ./cursor-group-ops.ps1 --create-user -gn "Engineering" -ue "user@company.com"

# Create / rename / delete a group
pwsh ./cursor-group-ops.ps1 -cg -gn "Platform"
pwsh ./cursor-group-ops.ps1 -rg -gn "Platform" -nn "Platform Engineering"
pwsh ./cursor-group-ops.ps1 -dg -gn "Platform Engineering"
```

#### All flags

| Flag | Short | Description |
|------|-------|-------------|
| `--help` | `-h` | Show help |
| `--list-groups` | `-lg` | List groups |
| `--list-members` | `-lm` | List members of a group |
| `--list-users` | `-lu` | List SCIM users |
| `--create-group` | `-cg` | Create a group |
| `--rename-group` | `-rg` | Rename a group |
| `--remove-group` | `-dg` | Delete a group |
| `--add-user` | `-au` | Add user to group |
| `--remove-user` | `-ru` | Remove user from group |
| `--create-user` | `-cu` | Create SCIM user (optionally add to group) |
| `--group-type` | `-gt` | `billing` or `regular` (default: `billing`) |
| `--group-id` | `-gid` | Group ID |
| `--group-name` | `-gn` | Group name |
| `--new-name` | `-nn` | New name (for rename) |
| `--user-email` | `-ue` | User email(s), comma-separated |
| `--user-id` | `-uid` | User ID(s), comma-separated |
| `--billing-cycle` | `-bc` | Billing cycle date `YYYY-MM-DD` |
| `--scim-base-url` | `-sbu` | Override SCIM base URL |
| `--creds-file` | `-cf` | Credentials file (default: `./.env`) |
| `--include-members` | `-im` | Include members in group listings |
| `--verbose-output` | `-v` | Verbose HTTP output |

### Notes

- Billing groups attached to directory sync (`directoryGroupId`) cannot have members managed via the Admin API.
- Regular groups are SCIM-managed and typically IdP-synced.
- `--create-user` is SCIM only (`-gt regular`).

### References

- [Cursor Admin API](https://cursor.com/docs/account/teams/admin-api.md)
- [Billing groups](https://cursor.com/docs/account/teams/admin-api.md#billing-groups)
- [SCIM overview](https://cursor.com/docs/account/teams/scim)

## Canva Group Ops

Manages Canva groups via two APIs. Supports two group types:

- `admin` — Canva Admin API groups (`https://api.canva.com/admin/v1`), the default
- `scim` — Canva SCIM v2 groups (`https://www.canva.com/_scim/v2`)

### Requirements

- PowerShell 5.1 or later (`powershell` or `pwsh`)
- Credentials in `./.env` (default) or pass `--creds-file`
- `admin` needs `CANVA_OAUTH_CLIENT_ID` + `CANVA_OAUTH_CLIENT_SECRET`; `scim` needs only `CANVA_SCIM_TOKEN`

### Step-by-step (interactive) mode

Run with no arguments and it prompts for everything:

```powershell
pwsh ./canva-group-ops.ps1
```

```
Commands:
  list-groups   (lg)
  list-members  (lm)
  list-users    (lu)
  list-teams    (lt)
  create-group  (cg)
  rename-group  (rg)
  remove-group  (dg)
  add-user      (au)
  remove-user   (ru)
  help          (h)
  exit

? Command: add-user
? Group type (admin/scim) [admin]:
? Group name: Marketing
? User email(s) — paste from Excel or enter one per line, then blank line to finish:
user@company.com

[info] add user 'user@company.com' (id=UAAAAAAAAA1) in Admin group 'Marketing' (ID G123).
```

**Tip:** when entering emails, you can paste a column copied from Excel — each row is treated as a separate email. Finish with a blank line.

After each run, the script prints the equivalent CLI command:

```
CLI equivalent: pwsh ./canva-group-ops.ps1 --add-user --group-type admin --group-name "Marketing" --user-email "user@company.com"
```

### CLI mode

Pass flags directly to skip the prompts.

**Group type** (`--group-type` / `-gt`): `admin` (default) or `scim`

Common operations:

```powershell
# List groups
pwsh ./canva-group-ops.ps1 -lg                          # all teams, with a team column
pwsh ./canva-group-ops.ps1 -lg -tn "ByteDance / TikTok" # one team only
pwsh ./canva-group-ops.ps1 -lg -gt scim
pwsh ./canva-group-ops.ps1 -lg -im          # include members (admin only)

# Add / remove a user from a group
pwsh ./canva-group-ops.ps1 -au -gn "Marketing" -ue "user@company.com"
pwsh ./canva-group-ops.ps1 -ru -gt scim -gn "Marketing" -ue "user@company.com"

# Create / rename / delete a group
pwsh ./canva-group-ops.ps1 -cg -gn "Marketing" -d "Marketing team"
pwsh ./canva-group-ops.ps1 -cg -gt scim -gn "Marketing"
pwsh ./canva-group-ops.ps1 -rg -gn "Marketing" -nn "Marketing Ops"
pwsh ./canva-group-ops.ps1 -dg -gn "Marketing Ops"

# Teams and users
pwsh ./canva-group-ops.ps1 -lt
pwsh ./canva-group-ops.ps1 -lu
pwsh ./canva-group-ops.ps1 -lu -gt scim
```

#### All flags

| Flag | Short | Description |
|------|-------|-------------|
| `--help` | `-h` | Show help |
| `--list-teams` | `-lt` | List teams (Admin API only) |
| `--list-users` | `-lu` | List users |
| `--list-groups` | `-lg` | List groups |
| `--list-members` | `-lm` | List members of a group |
| `--create-group` | `-cg` | Create a group |
| `--rename-group` | `-rg` | Rename a group |
| `--remove-group` | `-dg` | Delete a group |
| `--add-user` | `-au` | Add user to group |
| `--remove-user` | `-ru` | Remove user from group |
| `--group-type` | `-gt` | `admin` or `scim` (default: `admin`) |
| `--group-id` | `-gid` | Group ID (Admin group ID, or SCIM ID with `-gt scim`) |
| `--group-name` | `-gn` | Group name |
| `--new-name` | `-nn` | New name (for rename) |
| `--description` | `-d` | Group description (admin group type only) |
| `--user-email` | `-ue` | User email(s), comma-separated |
| `--user-id` | `-uid` | User ID(s), comma-separated |
| `--team-id` | `-tid` | Team ID (admin group type only; `--list-groups` covers all teams when omitted) |
| `--team-name` | `-tn` | Team name (admin group type only) |
| `--creds-file` | `-cf` | Credentials file (default: `./.env`) |
| `--include-members` | `-im` | Include members in group listings |
| `--verbose-output` | `-v` | Verbose HTTP output |

### Notes

- `admin` is the default, so existing commands behave as before.
- The Admin API has no org-wide group listing — `GET /teams/{teamId}/groups` requires a team. With `-gt admin` and no `--team-id`/`--team-name`, `--list-groups` fans out over every team and adds a `team` column; all other commands still resolve a single team (defaulting to the first one returned).
- Group names are only unique within a team, so the same name can exist in several teams. Use `--group-id` for destructive operations.
- Admin and SCIM groups are separate ID spaces; a group ID from one type won't resolve under the other.
- Canva's SCIM API always returns an **empty** `members` array, so `--list-members` and `-im` only return real members with `-gt admin`.
- `--description` is Admin API only — SCIM's core Group schema has no description attribute.
- `--group-type scim` never resolves a team and never mints an Admin OAuth token; `CANVA_SCIM_TOKEN` alone is enough.
- Admin API members are added with role `member`.
- `--list-teams` is Admin API only.

### References

- [Canva Admin API](https://www.canva.dev/docs/admin/)
- [Admin API: create group member](https://www.canva.dev/docs/admin/api-reference/groups/create-group-member/)
- [Admin API: delete group member](https://www.canva.dev/docs/admin/api-reference/groups/delete-group-member/)
- [Canva SCIM API](https://www.canva.dev/docs/scim/)
- [SCIM: create a group](https://www.canva.dev/docs/scim/create-group/)
- [SCIM: update individual attributes for a group](https://www.canva.dev/docs/scim/update-individual-attributes-group/)
- [SCIM: delete a group](https://www.canva.dev/docs/scim/delete-group/)
