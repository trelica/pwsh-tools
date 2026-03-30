# Group Ops CLIs

This repo contains PowerShell CLIs for group administration workflows:

- `canva-group-ops.ps1`
- `cursor-group-ops.ps1`

## Environment Keys By App

Use `./.env` by default for `cursor-group-ops.ps1`, and `./creds.env` by default for `canva-group-ops.ps1` (with `./.env` also loaded as a fallback).
You can override either with `--creds-file`.

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
  - Required for Admin API operations.
- `CANVA_OAUTH_CLIENT_SECRET`
  - Used to mint Canva Admin API OAuth token.
  - Required for Admin API operations.
- `CANVA_SCIM_TOKEN`
  - Used for SCIM group membership operations.
  - Required for add/remove user group actions.

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

Script path:

- `canva-group-ops.ps1`

Run help:

```bash
pwsh ./canva-group-ops.ps1 --help
```