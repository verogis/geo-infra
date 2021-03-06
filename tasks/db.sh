#!/usr/bin/env bash

###############################################################################
# geo-infra Scripts and templates to create and manage geoportals
# Copyright (c) 2015-2016, sigeom sa
# Copyright (c) 2015-2016, Ioda-Net Sàrl
#
# Contact : contact (at)  geoportal (dot) xyz
# Repository : https://github.com/ioda-net/geo-infra
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
###############################################################################

function _db-drop {
    local superuser="$1"

    psql -h "${host}" -d postgres -U "${superuser}" <<EOF
-- Kill all db connexions
SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE datname = '${database}'
  AND pid <> pg_backend_pid();

DROP DATABASE IF EXISTS ${database};
EOF
}


function _db-create {
    local superuser="$1"
    local owner="$2"

    psql -h "${host}" -d postgres -U "${superuser}" <<EOF
CREATE DATABASE ${database}
  WITH OWNER = ${owner}
       ENCODING = 'UTF8'
       TABLESPACE = pg_default
       LC_COLLATE = 'fr_CH.UTF-8'
       LC_CTYPE = 'fr_CH.UTF-8'
       TEMPLATE = template0
       CONNECTION LIMIT = -1;

ALTER DATABASE ${database}
  SET search_path = userdata, public, pg_catalog;
EOF
}


function _db-restore {
    local superuser="$1"
    local db_owner="$2"

    echo "Restoring ${database}"
    # root superuser is needed to recreate extension
    pg_restore -h "${host}" -d "${database}" -U "${superuser}"  --jobs 4 "${backup_file}"
    psql -h "${host}" -d "${database}" -U "${superuser}"  -c "REASSIGN OWNED BY ${superuser} TO ${db_owner};"

    psql -h "${host}" -d "${database}" -U ${db_owner} --no-password  -c "ALTER DATABASE ${database} SET search_path = userdata, public, postgis, topology, pg_catalog;"

    db-grant-update "${host}" "${database}"
}


HELP['db-grant-update']="manuel db-grant-update [HOST [DATABASE [DB_OWNER]]]

Fix the right for DATABASE on HOST.

**Default values**

- *host* \$DEFAULT_DB_HOST
- *database* \$DEFAULT_DB_NAME
- *db_owner* \$DEFAULT_DB_OWNER"
function db-grant-update {
    _load-prod-config

    local host=${1:-${DEFAULT_DB_HOST}}
    local database=${2:-${DEFAULT_DB_NAME}}
    local owner="${3:-${DEFAULT_DB_OWNER}}"
    echo "Adjusting rights on ${database}"
    local sql_statements=$(cat ./scripts/sql/db-grant-update.sql |
        sed "s/DEFAULT_DB_OWNER/${DEFAULT_DB_OWNER}/g" |
        sed "s/DEFAULT_DB_MAPSERVER_ROLE/${DEFAULT_DB_MAPSERVER_ROLE}/g" |
        sed "s/DEFAULT_DB_SEARCH_ROLE/${DEFAULT_DB_SEARCH_ROLE}/g" |
        sed "s/DEFAULT_DB_API_ROLE/${DEFAULT_DB_API_ROLE}/g")
    psql -h "${host}" -d "${database}" -U "${owner}" --no-password -q -f - <<< "${sql_statements}"
}


HELP['db-update']="manuel db-update [HOST [DATABASE [BACKUP_FILE [DB_SUPER_USER [DB_OWNER]]]]]

Update DATABASE on HOST from BACKUP_FILE.

**Default values**

- *host* \$DEFAULT_DB_HOST
- *database* \$DEFAULT_DB_NAME
- *backup_file* \$DEFAULT_DB_DUMP_FILE
- *db_user_user* \$DEFAULT_DB_SUPER_USER
- *db_owner* \$DEFAULT_DB_OWNER"
function db-update {
    _load-prod-config

    local host=${1:-${DEFAULT_DB_HOST}}
    local database=${2:-${DEFAULT_DB_NAME}}
    local backup_file="${3:-${DEFAULT_DB_DUMP_FILE}}"
    local superuser="${4:-${DEFAULT_DB_SUPER_USER}}"
    local owner="${5:-${DEFAULT_DB_OWNER}}"

    _db-drop "${superuser}"

    _db-create "${superuser}" "${owner}"

    _db-restore "${superuser}" "${owner}"
}


HELP['db-dump']="manuel db-dump [HOST [DATABASE [BACKUP_FILE [DB_OWNER]]]]

Dump DATABASE from HOST to BACKUP_FILE.

**Default values**

- *host* \$DEFAULT_DB_SOURCE_HOST
- *database* \$DEFAULT_DB_NAME
- *backup_file* \$DEFAULT_DB_DUMP_FILE
- *db_owner* \$DEFAULT_DB_OWNER"
function db-dump {
    _load-prod-config

    local host=${1:-${DEFAULT_DB_SOURCE_HOST}}
    local database=${2:-${DEFAULT_DB_NAME}}
    local backup_file="${3:-${DEFAULT_DB_DUMP_FILE}}"
    local owner="${4:-${DEFAULT_DB_OWNER}}"

    pg_dump -h "${host}" -U "${owner}" \
      --no-password \
      --format custom \
      --blobs \
      --compress 6 \
      --encoding UTF8 \
      --verbose \
      --file "${backup_file}" \
      "${database}"

}


HELP['db-dump-roles']="manuel db-dump-roles [HOST [SUPER_USER]]

Dump the roles know to a pg HOST to STDIN.

**Default values**

- *host* \$DEFAULT_DB_SOURCE_HOST"
function db-dump-roles {
    _load-prod-config

    local host="${1:-${DEFAULT_DB_SOURCE_HOST}}"
    local superuser="${2:-${DEFAULT_DB_SUPER_USER}}"
    pg_dumpall -h "${host}" -U "${superuser}" --roles-only
}


HELP['db-dev2prod']="manuel db-dev2prod [HOST [DATABASE [BACKUP_FILE [BACKUP_API_FILE [DB_SUPER_USER [DB_OWNER]]]]]]

Deploy the dev database saved in BACKUP_FILE to DATABASE on HOST. Restore the api3 schema from
BACKUP_API_FILE.

**Default values**

- *host* \$DEFAULT_DB_PROD_HOST
- *database* \$DEFAULT_DB_PROD_NAME
- *backup_file* \$DEFAULT_DB_DUMP_FILE
- *backup_api_file* \$DEFAULT_DB_API_DUMP_FILE
- *db_super_user* \$DEFAULT_DB_SUPER_USER
- *db_owner* \$DEFAULT_DB_OWNER"
function db-dev2prod {
    _load-prod-config

    local host=${1:-${DEFAULT_DB_PROD_HOST}}
    local database=${2:-${DEFAULT_DB_PROD_NAME}}
    local backup_file="${3:-${DEFAULT_DB_DUMP_FILE}}"
    local backup_api_file="${4:-${DEFAULT_DB_API_DUMP_FILE}}"
    local superuser="${5:-${DEFAULT_DB_SUPER_USER}}"
    local owner="${6:-${DEFAULT_DB_OWNER}}"

    if [ ! -s "${backup_file}" ]; then
      echo "Dump dev file ${backup_file} empty or missing !"
      exit 1
    fi

    #First we need to backup api3 schema to save the tables there.
    pg_dump -h "${host}" -U "${owner}" --no-password -Fc --schema api3 -v -f "${backup_api_file}" ${database}

    _db-drop "${superuser}"

    _db-create "${superuser}" "${owner}"

    _db-restore "${superuser}" "${owner}"

    # Restore api3 table shortcut and files with -c clean option.
    pg_restore --host "${host}" -U "${owner}" --no-password --dbname "${database}" -c --jobs 2 "${backup_api_file}"
	# Need to recreate constraints
	psql --host "${host}" -U "${owner}" --no-password --dbname "${database}" -c '
ALTER TABLE api3.files
  ADD CONSTRAINT pk_file_id PRIMARY KEY(admin_id, file_id);
ALTER TABLE api3.files
  ADD CONSTRAINT files_file_id_key UNIQUE(file_id);
ALTER TABLE api3.files
  ADD CONSTRAINT files_admin_id_key UNIQUE(admin_id);
ALTER TABLE api3.url_shortener
  ADD CONSTRAINT url_shortener_pkey PRIMARY KEY(short_url);
'
}

HELP['db-prod-patch']="manuel db-prod-patch [PATCH_FILE [HOST [DATABASE [DB_OWNER]]]]

Update the production database with associated patch

**Default values**

- *patchfile* /var/tmp/patch.sql
- *host* \$DEFAULT_DB_PROD_HOST
- *database* \$DEFAULT_DB_PROD_NAME
- *owner* \$DEFAULT_DB_OWNER
"
function db-prod-patch {
    _load-prod-config

    local patch_file="${1:-/var/tmp/patch.sql}"
    local host=${2:-${DEFAULT_DB_PROD_HOST}}
    local database=${3:-${DEFAULT_DB_PROD_NAME}}
    local owner="${4:-${DEFAULT_DB_OWNER}}"

    if [ ! -s "${patch_file}" ]; then
      echo "Patch file ${patch_file} empty or missing !"
      exit 1
    fi

    # run patch file
    psql --host "${host}" -U "${owner}" --no-password --dbname "${database}" -f "${patch_file}"
}


HELP['db-ddl-track']="manuel db-ddl-track [DB_HOST [DB_NAME [REPO [SCHEMA_DUMP_FILE [DB_OWNER]]]]]

Work with DDL database, if any changes is detected from previous state
Download the db schema, and create a new git tag
commit and push to specific repository.

This task is normally run from cron

**Default values**

- *host* \$DEFAULT_DB_SOURCE_HOST
- *database* \$DEFAULT_DB_NAME
- *repo* \$DEFAULT_DB_REPO
- *dump file* \$DEFAULT_DB_SCHEMA_DUMP_FILE
- *db_owner* \$DEFAULT_DB_OWNER
"
function db-ddl-track {
    _load-prod-config

    local host=${1:-${DEFAULT_DB_SOURCE_HOST}}
    local database=${2:-${DEFAULT_DB_NAME}}
    local repo=${3:-${DEFAULT_DB_REPO}}
    local dump_file=${4:-${DEFAULT_DB_SCHEMA_DUMP_FILE}}
    local owner="${5:-${DEFAULT_DB_OWNER}}"

    db_version=$(psql -t --host "${host}" -U "${owner}" --no-password --dbname "${database}" -c "select * from zzversion order by version DESC limit 1")

    cd "$repo"
    _exit-current-dir-not-git-root

    /usr/bin/pg_dump -h ${host} -U "${owner}" --no-password --schema-only --no-owner -f ${repo}/${dump_file} ${database}

    git add -A .

    # If there's nothing to commit, we stop the function here.
    if ! git commit -m "release $(date +"%Y-%m-%d-%H-%M-%S") $db_version" > /dev/null; then
        cd -
        return 0
    fi
    git tag -a -m "release $db_version" $(date +"%Y-%m-%d-%H-%M-%S")
    git push
    git push --tags
    cd -
}
