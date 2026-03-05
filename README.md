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

Script path:

- `cursor-group-ops.ps1`

Supports two group types:

- `billing` (Cursor Admin API `/teams/groups`)
- `regular` (SCIM groups via `CURSOR_SCIM_BASE_URL`, WorkOS-backed)

### Requirements

- PowerShell 7+ (`pwsh`)
- Credentials in `./.env` (default) or pass `--creds-file`

Expected keys:

- `CURSOR_API_KEY` (required for billing groups + team member endpoints)
- `CURSOR_SCIM_TOKEN` (required for regular/SCIM groups)
- `CURSOR_SCIM_BASE_URL` (required for regular/SCIM groups)

### Commands

Long flags:

- `--help`
- `--list-users`
- `--list-groups`
- `--list-members`
- `--create-group`
- `--rename-group`
- `--remove-group`
- `--add-user`
- `--remove-user`

Short aliases:

- `-h` help
- `-lu` list users
- `-lg` list groups
- `-lm` list members
- `-cg` create group
- `-rg` rename group
- `-dg` delete group
- `-au` add user
- `-ru` remove user

Common options:

- `--group-type` / `-gt` (`billing` or `regular`; default `billing`)
- `--group-id` / `-gid`
- `--group-name` / `-gn`
- `--new-name` / `-nn`
- `--user-email` / `-ue`
- `--user-id` / `-uid`
- `--billing-cycle` / `-bc` (`YYYY-MM-DD`, billing only)
- `--scim-base-url` / `-sbu` (override SCIM base URL)
- `--creds-file` / `-cf` (default: `./.env`)
- `--include-members` / `-im`
- `--verbose-output` / `-v`

### Examples

Help:

```bash
pwsh ./cursor-group-ops.ps1 --help
```

List billing groups:

```bash
pwsh ./cursor-group-ops.ps1 -lg -gt billing
```

List billing groups with members:

```bash
pwsh ./cursor-group-ops.ps1 -lg -gt billing -im
```

Create/rename/delete billing group:

```bash
pwsh ./cursor-group-ops.ps1 -cg -gt billing -gn "Platform"
pwsh ./cursor-group-ops.ps1 -rg -gt billing -gn "Platform" -nn "Platform Engineering"
pwsh ./cursor-group-ops.ps1 -dg -gt billing -gn "Platform Engineering"
```

Add/remove billing member by email:

```bash
pwsh ./cursor-group-ops.ps1 -au -gt billing -gn "Engineering" -ue "user@company.com"
pwsh ./cursor-group-ops.ps1 -ru -gt billing -gn "Engineering" -ue "user@company.com"
```

List SCIM regular groups:

```bash
pwsh ./cursor-group-ops.ps1 -lg -gt regular
```

Create/rename/delete SCIM regular group:

```bash
pwsh ./cursor-group-ops.ps1 -cg -gt regular -gn "Okta Engineering"
pwsh ./cursor-group-ops.ps1 -rg -gt regular -gn "Okta Engineering" -nn "Okta Platform"
pwsh ./cursor-group-ops.ps1 -dg -gt regular -gn "Okta Platform"
```

Add/remove SCIM member by email:

```bash
pwsh ./cursor-group-ops.ps1 -au -gt regular -gn "Okta Engineering" -ue "user@company.com"
pwsh ./cursor-group-ops.ps1 -ru -gt regular -gn "Okta Engineering" -ue "user@company.com"
```

### Notes

- Cursor Admin API group endpoints are for **billing groups**.
- Regular groups are handled through SCIM and are typically IdP-managed.
- Billing groups attached to directory sync (`directoryGroupId`) cannot be modified through billing group member APIs.

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