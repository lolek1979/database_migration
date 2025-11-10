# PostgreSQL Migration — Step 1: Export and Clean Roles (pgAdmin)

This guide describes **how to export all roles (users)** from your old Azure PostgreSQL Flexible Server using **pgAdmin 4**, and clean the file so it can be safely restored on a new Azure PostgreSQL Flexible Server.

---

## 🧩 Prerequisites

- pgAdmin 4 installed and connected to your **old PostgreSQL Flexible Server** (e.g. `psql-vzp-dev1-we-001`)
- Admin login: `vzp_dev1_psql_admin`
- Folder to save backups (for example `C:\Users\<you>\Documents\database\`)

---

## 🧭 Step 1 — Export Roles (users)

1. In pgAdmin, **right-click the server name** (not a database).  
2. Choose **Backup Globals…**  
3. Fill the dialog as follows:

   | Field | Value |
   |--------|--------|
   | **Filename** | `C:\Users\<you>\Documents\database\roles.sql` |
   | **Format** | Plain |
   | **Role name** | *(leave blank)* |
   | ✅ **Only objects global to the entire database will be backed up** | Checked |
   | **Click Backup** | (bottom right of dialog) |

4. Wait until the process completes.  
   The file `roles.sql` is created in your chosen folder.

---

## 🧾 Step 2 — Open and Inspect the File

1. Open `roles.sql` in **VS Code** or **Notepad**.  
2. You’ll see many `CREATE ROLE`, `ALTER ROLE`, and `GRANT` commands.

Example beginning of the file:

```sql
CREATE ROLE administrative_proceeding;
ALTER ROLE administrative_proceeding WITH LOGIN PASSWORD 'md5...';
CREATE ROLE azure_pg_admin;
ALTER ROLE azure_pg_admin WITH SUPERUSER;
...
CREATE ROLE vzp_dev1_psql_admin WITH CREATEDB CREATEROLE LOGIN PASSWORD 'md5...';
```

---

## ✂️ Step 3 — Remove System Roles

Delete every block that contains any of the following roles:

```
azure_pg_admin
azuresu
postgres
pg_monitor
pg_read_all_settings
pg_read_all_stats
pg_signal_backend
pg_stat_scan_tables
```

Also delete **any `CREATE TABLESPACE`** section at the bottom of the file.  
Azure Flexible Server does not allow custom tablespaces.

---

## ✅ Step 4 — Keep These Roles

Keep only:
- Your **application roles**, for example:
  ```
  requestform
  shared_templates
  authorization
  airflow
  codelists
  usk
  vrp
  ```
- Your **admin roles**, such as:
  ```
  vzp_dev1_psql_admin
  vzp_dev1_psql_dev
  vzp_dev1_psql_rel
  ```

---

## 🧹 Step 5 — Save the Cleaned File

- Save the modified file as `roles_clean.sql` in the same folder.
- This file will be used later to **restore users and passwords** on the new server.

Example of the cleaned file:

```sql
-- Roles
CREATE ROLE requestform WITH LOGIN PASSWORD 'md5...';
CREATE ROLE shared_templates WITH LOGIN PASSWORD 'md5...';
CREATE ROLE authorization WITH LOGIN PASSWORD 'md5...';
CREATE ROLE vzp_dev1_psql_admin WITH CREATEDB CREATEROLE LOGIN PASSWORD 'md5...';

-- Role memberships
GRANT requestform TO vzp_dev1_psql_admin;
GRANT shared_templates TO vzp_dev1_psql_admin;
```

---

## 🎯 Result

You now have a cleaned file:

```
C:\Users\<you>\Documents\database\roles_clean.sql
```

This file is safe to restore on your new PostgreSQL Flexible Server (it will recreate only your users and passwords).

Next steps (in later parts of the migration guide):
- Restore `roles_clean.sql` on the new server
- Backup and restore individual databases

---

## 🗂️ Step 6 — Inventory Existing Databases

1. In pgAdmin (or `psql`), run the following on the old server to capture the full list of databases, owners, sizes, and encodings:
   ```sql
   SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size, pg_encoding_to_char(encoding) AS encoding, datcollate, datctype, datowner
   FROM pg_database
   WHERE datistemplate = false
   ORDER BY datname;
   ```
2. Export the result to CSV (pgAdmin ➜ *Query Tool* ➜ *Download as CSV*) and store it alongside your role exports, e.g. `C:\Users\<you>\Documents\database\inventory_<date>.csv`.
3. Note any special databases (reporting, analytics, etc.) that require longer maintenance windows or special handling.

---

## 💾 Step 7 — Create Logical Backups Per Database

1. For every application database listed in Step 6, run both a **plain SQL** dump and a **custom format** dump (custom makes restores faster and allows parallelism):
   ```bash
   pg_dump --host <old-server> --username vzp_dev1_psql_admin --format=plain --file=C:\backups\<db>.sql <db>
   pg_dump --host <old-server> --username vzp_dev1_psql_admin --format=custom --file=C:\backups\<db>.dump <db>
   ```
2. Store dumps in a structured folder per environment (e.g. `C:\backups\we-old\plain\` and `C:\backups\we-old\custom\`).
3. Document the exact pg_dump version used; restoring with the same major version on the new server avoids surprises.

---

## 🧪 Step 8 — Smoke-Test the Backups

1. Run `pg_restore --list C:\backups\<db>.dump > C:\backups\<db>_contents.txt` to verify the dump includes schemas, tables, and data as expected.
2. Restore one representative database to a disposable PostgreSQL instance (local Docker or Azure dev server) using:
   ```bash
   pg_restore --host <temp-server> --username vzp_dev1_psql_admin --clean --create --jobs=4 C:\backups\<db>.dump
   ```
3. Compare row counts between the temporary restore and the source (`SELECT COUNT(*) FROM <table>;`) to validate integrity.

---

## 🏗️ Step 9 — Prepare the New PostgreSQL Server

1. **Create empty databases** on the new server using the inventory CSV: matching names, owners, encoding, collation, and LC settings.
2. **Install required extensions** (e.g. `CREATE EXTENSION IF NOT EXISTS "uuid-ossp";`) before restoring data to avoid errors mid-restore.
3. Align key server parameters (timezone, `shared_buffers`, `work_mem`, etc.) with the old environment or update them per new sizing guidance.
4. Enable required firewall rules/private endpoints so AKS nodes and management jumpboxes can reach the new server before you cut over.

---

## 🔁 Step 10 — Plan the Restore Order

1. Restore `roles_clean.sql` first on the new server so that database owners already exist.
2. Restore databases in dependency order (shared schemas first, downstream apps next). Keep a checklist such as:
   ```
   [ ] shared_templates
   [ ] codelists
   [ ] requestform
   [ ] authorization
   ```
3. After each restore, run post-load maintenance (`ANALYZE`, `VACUUM (ANALYZE)`) to refresh statistics before traffic switches over.

---

## 🔐 Step 11 — Update Application Secrets

1. Collect the new connection strings (hostname, port, admin login, SSL root cert).
2. Update Azure Key Vault / AKS secrets / CI variables that store database credentials and rotate passwords if required.
3. Record a rollback plan (old connection strings + backup file paths) so you can revert quickly if validation fails post-migration.

---
