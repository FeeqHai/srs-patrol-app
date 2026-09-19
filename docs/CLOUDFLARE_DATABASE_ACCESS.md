# Private Pi database access through Cloudflare

Updated: 2026-09-03.

## Current status

- The user selected Cloudflare for remote Workbench access from other networks.
- The existing Pi tunnel serves the public API at `api.ironda.app`.
- The Windows connector and desktop shortcut are prepared.
- The user is configuring Cloudflare manually. Screenshots show an Access
  application for `db.ironda.app` with the `iRonda Database Owner` Allow policy
  attached (one rule); the rule's email value has not been independently checked.
- The tunnel route form shows `db.ironda.app` pointing to
  `tcp://127.0.0.1:3306`, with no path filter.
- An unauthenticated HTTPS request to `db.ironda.app` returned HTTP 302 to the
  account's Cloudflare Access login with a Cloudflare-Access authentication
  header. The hostname is protected at the edge; this does not yet verify the
  authenticated TCP connection or the origin service.
- After creating the viewer account, the user successfully tested its local TCP
  login on the Pi. `CURRENT_USER()` returned `ironda_viewer@127.0.0.1` and
  `SHOW TABLES` listed all 16 application tables in `srs_db`.
- The Windows connector executable, desktop shortcut target/arguments and
  Workbench installation were rechecked. The first Workbench attempt showed
  correct connection fields, but Cloudflare rejected the login with "That
  account does not have access". The login page offered only the Cloudflare
  identity provider; the policy's email rule still needs inspection.
- At diagnosis, the PC connector was no longer running. It was restarted hidden
  as PID 37652 and verified listening on `127.0.0.1:13306`. Its error log is
  `C:\Users\rafee\AppData\Local\iRonda\logs\db-access-20260902-184014.err.log`.
  A listener alone does not prove successful Access or database authentication.
- The latest Workbench attempt detects server version `10.11.18`, matching the
  Pi's MariaDB version, and displays its incompatible/nonstandard server warning.
  This shows that the database server is reachable. The next step is to choose
  Continue Anyway, complete the connection test, and verify the server/account
  and table list from Workbench. Query results through Cloudflare are still pending.
- Database connectivity through Cloudflare, the allowed/denied Access identities
  and restart recovery remain untested.

## Prepared Windows connector

The official `cloudflare/cloudflared` GitHub release `2026.8.3` was downloaded for
Windows AMD64 and its SHA-256 matched the digest published with the release:

```text
83e726ed18ea78c5ad5213c4c3a3a27051393950d2bc8ed4de69bec12d14eaae
```

Installed file:
`C:\Users\rafee\AppData\Local\iRonda\tools\cloudflared.exe`

Desktop shortcut:
`C:\Users\rafee\Desktop\iRonda Pi Database.lnk`

The shortcut starts this command in a minimized window:

```powershell
cloudflared access tcp --hostname db.ironda.app --url 127.0.0.1:13306
```

It binds only to the PC's loopback address and uses port 13306 to keep the
connection separate from local XAMPP on port 3306. The shortcut has no passwords
or tunnel service token. Version output and CLI options were checked, the saved
shortcut target and arguments were verified, and port 13306 was available.
The connector was subsequently restarted in the background during troubleshooting
(see Current status). The shortcut remains available for later sessions.

## Cloudflare setup sequence

1. Finish the Zero Trust Free enrollment only after reviewing its billing terms.
2. Create a self-hosted Access application for exactly `db.ironda.app`, with an
   Allow policy for the owner's email. Use a supported identity provider or email
   one-time PIN. Keep the policy limited to the database hostname so that mobile
   API requests continue using the app's own authentication.
3. Verify the allowed identity and policy before publishing the database route.
4. In the existing Pi tunnel, add a published application with subdomain `db`,
   domain `ironda.app`, no path filter, and service `tcp://127.0.0.1:3306`.
5. Confirm an unauthenticated request to the database hostname is challenged by
   Access before making an authenticated database connection.

The existing tunnel connector is installed as a service. Confirm `cloudflared`
and `mariadb` are enabled on the Pi before claiming access recovers after a boot.

### Current Access login rejection

New Zero Trust organizations now default to the Cloudflare identity provider,
with authentication restricted to Cloudflare account members. Email one-time
PIN is a separate identity provider and is not added automatically. The current
login screen only offers Cloudflare sign-in.

Inspect the attached `iRonda Database Owner` policy's exact Include email and
compare it with the Cloudflare account used during login. If it matches, inspect
the Access authentication event and account membership before changing any
policy. The exact reason for the rejected identity has not yet been established.
The subsequent attempt reached MariaDB's version warning; it did not show the
earlier Access rejection. No change to the email rule was independently verified.

## Check the Pi viewing account

Run in the Pi terminal:

```bash
sudo mariadb -e "SELECT User, Host FROM mysql.user WHERE User = 'ironda_viewer';"
```

If it lists `ironda_viewer` at `127.0.0.1`, inspect its schema permissions in an
administrative MariaDB session:

```sql
SELECT GRANTEE, TABLE_SCHEMA, PRIVILEGE_TYPE, IS_GRANTABLE
FROM information_schema.SCHEMA_PRIVILEGES
WHERE GRANTEE = CONCAT(QUOTE('ironda_viewer'), '@', QUOTE('127.0.0.1'));
```

The intended account has SELECT and SHOW VIEW on `srs_db.*` and no write grants.
If no account exists, open `sudo mariadb` on the Pi. Replace the password
placeholder with a unique password before executing:

```sql
CREATE USER 'ironda_viewer'@'127.0.0.1'
IDENTIFIED BY 'REPLACE_WITH_YOUR_OWN_STRONG_PASSWORD';
GRANT SELECT, SHOW VIEW ON srs_db.*
TO 'ironda_viewer'@'127.0.0.1';
EXIT;
```

Keep the database password private. Test the account from the Pi shell; `-p`
prompts for the password without putting it in the command arguments:

```bash
mariadb -h 127.0.0.1 -u ironda_viewer -p srs_db -e "SELECT CURRENT_USER(); SHOW TABLES;"
```

The expected identity is `ironda_viewer@127.0.0.1`, followed by the application
tables. This checks the local TCP login before testing the Cloudflare connector.

## Workbench settings after setup

Start the desktop shortcut, then use these settings in MySQL Workbench:

| Setting | Value |
| --- | --- |
| Connection name | iRonda Pi via Cloudflare |
| Connection method | Standard TCP/IP |
| Hostname | 127.0.0.1 |
| Port | 13306 |
| Username | ironda_viewer |
| Password | The viewing account's database password |
| Default schema | srs_db |

This connection uses the local Cloudflare connector, so it uses Standard TCP/IP.
The earlier direct home-network instructions used Standard TCP/IP over SSH.
When Workbench first connects, Cloudflare may open the browser for an Access
login. Keep the connector running while browsing; closing its window ends that
local connection. The Pi and PC both need Internet connectivity. The local
listener starting alone does not prove that login or database access works.

After connecting, verify the destination and identity without changing records:

```sql
SELECT @@hostname AS server, DATABASE() AS database_name, CURRENT_USER() AS account;
SHOW TABLES;
```

## References

- [Cloudflare TCP access and client connector](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/non-http/cloudflared-authentication/arbitrary-tcp/)
- [Self-hosted Access applications](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/self-hosted-public-app/)
- [Cloudflare identity provider and account membership](https://developers.cloudflare.com/cloudflare-one/integrations/identity-providers/cloudflare/)
- [Official cloudflared release](https://github.com/cloudflare/cloudflared/releases/tag/2026.8.3)
