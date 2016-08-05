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

HELP['generate']="manuel generate OPTIONS

Wrapper around scripts/generate.py. All the options are passed to the python script. Use
--help for more details."
function generate {
    "${GENERATE_CMD}" "$@"
}


HELP['render']="manuel render OPITONS

Wrapper around scripts/render.py --front-dir \$FRONT_DIR. All the options are passed to the script.
Use --help for more details."
function render {
    "${RENDER_CMD}" --front-dir "${FRONT_DIR}" "$@"
}


HELP['generate-global-search-conf']="manuel generate-global-search-conf [TYPE]

Generate the global configuration for sphinx and restart searchd.

**Default values**

- *type* dev"
function generate-global-search-conf {
    local portal_type="${1:-dev}"
    generate --search-global --customer-infra-dir "${CUSTOMERS_INFRA_DIR}" --type "${portal_type}"
    restart-service "search"
}


HELP['restart-service']="manuel restart-service SERVICE

Restart the specified service."
function restart-service {
    local prod_cmd="sudo_$1_restart"
    if type "${prod_cmd}"  > /dev/null 2>&1; then
        "${prod_cmd}"
    else
        case "$1" in
            apache|apache2|httpd)
                _restart-apache
                ;;
            *)
                if [[ -e "/usr/lib/systemd/system/$1.service" ]]; then
                    sudo /usr/bin/systemctl restart "$1.service"
                elif [[ -e "/usr/lib/systemd/system/${1}d.service" ]]; then
                    sudo /usr/bin/systemctl restart "${1}d.service"
                elif [[ -e "/usr/lib/systemd/system/${1}" ]]; then
                    sudo /usr/bin/systemctl restart "$1.service"
                else
                    echo '$1 service not found' >&2
                fi
        esac
    fi
}


function _restart-apache {
    if [[ -e '/usr/lib/systemd/system/httpd.service' ]]; then
        sudo /usr/bin/systemctl restart httpd.service
    else
        sudo /usr/bin/systemctl restart apache2.service
    fi
}


HELP['reindex']="manuel reindex

Launch a full reindexation of sphinx."
function reindex {
    while ps aux | grep /usr/bin/indexer | grep -vq grep; do
        echo "WARNING: reindex already in progress. Waiting."
        sleep 10
    done

    if type "sudo_search_reindex" > /dev/null 2>&1; then
        sudo_search_reindex
    else
        local cmd=(sudo /usr/bin/indexer
            --verbose
            --rotate
            --config /etc/sphinx/sphinx.conf
            --all)
        if [[ "${QUIET}" == "true" ]]; then
            cmd+=("--quiet")
        fi
        "${cmd[@]}"
    fi
    restart-service search
}


HELP['test-map-files']="manuel test-map-files [TYPE] PORTAL

Test the map files of given type for the specified portal.

**Default values**

- *type* dev"
function test-map-files {
    local portal
    local portal_type
    _set-portal-type "$@"
    local infra_dir=$(_get-infra-dir "${portal}")
    local alias="${portal}"
    portal=$(_get-portal-name-from-alias "${portal}")

    extent=$(cat "${infra_dir}/config/dist/${portal}.dist.toml" |
                    grep '^extent = ' |
                    cut -f 2 -d '=' |
                    sed 's/\"//g; s/\[//g; s/\]//g; s/,//g; s/^ //g')
    # We must use eval for the extent to be 4 numbers as shp2img expects
   shp2img="shp2img -m ${infra_dir}/${portal_type}/${portal}/map/portals/${portal}.map \
            -all_debug 0 \
            -map_debug 1 \
            -s 1920 1080 \
            -e ${extent} \
            -o /tmp/${portal}.png"
    if ! eval "${shp2img}"; then
        echo " ###***### test-map-files FAILED for ${portal_type} ${alias}"
    fi
}


function _set-portal-type {
    # Don't make these variables local. We need them in the parent function (they must be local there).
    if [[ -z "${2:-}" ]]; then
        portal_type=dev
        portal="$1"
    else
        portal_type="$1"; shift
        portal="$1"
    fi
}


function _get-infra-dir {
    local portal="$1"; shift
    local infra_dir

    if [[ -f "${ALIAS_FILE}" ]]; then
        local alias_line=$(_get-alias-line "${portal}")
        if [[ -n "${alias_line}" ]]; then
            infra_dir=$(echo "${alias_line}" | cut -d ' ' -f 2)
        fi
    fi

    if [[ -z "${infra_dir:-}" ]]; then
        for infra_dir in $(ls "${CUSTOMERS_INFRA_DIR}"); do
            if [[ -f "${CUSTOMERS_INFRA_DIR}/${infra_dir}/config/dist/${portal}.dist.toml" ]]; then
                break
            fi
        done
    fi

    echo "${CUSTOMERS_INFRA_DIR}/${infra_dir}"
}


function _get-alias-line {
    echo $(cat .aliases 2> /dev/null | grep "^$1 ")
}


function _get-portal-name-from-alias {
    local alias="$1"; shift
    local portal="${alias}"
    local alias_line=$(_get-alias-line "${portal}")
    if [[ -n "${alias_line}" ]]; then
        portal=$(echo "${alias_line}" | cut -d ' ' -f 3)
    fi

    echo "${portal}"
}


HELP['execute-on-prod']="manuel execute-on-prod CMD

Execute the given command on the production server.

It's possible to run the following commands:

* sudo_apache2_restart
* sudo_search_reindex
* sudo_search_restart
* sudo_tomcat_copyconf
* sudo_tomcat_restart
"
function execute-on-prod {
    ssh "${PROD_USER}@${PROD_HOST}" "$1"
}


HELP['revert']="manuel revert PORTAL

Revert the given portal to the previous release on production."
function revert {
    if [[ -z "$1" ]]; then
        echo "Revert requires a portal name" >&2
        exit 1
    fi

    execute-on-prod "cd \"${PROD_GIT_REPOS_LOCATION}/$1\" && \
        git fetch && \
        git checkout \$(git tag | sort -nr | head -n 2 | tail -n 1)"
}


HELP['reload-features']="manuel reload-features

Ask the API to reload the features."
function reload-features {
    local body
    if ! body=$(curl --netrc -f "${RELOAD_FEATURES_URL}" 2> /dev/null); then
        echo "Reload features failed:" >&2
        echo -e "${body}" >&2
        exit 1
    fi
}


HELP['init-prod-repo']="manuel init-prod-repo PORTAL

Clone the prod repo from the git server (the repo must exists there) and commit a dummy file. The
repo is then clone on the production server."
function init-prod-repo {
    local bare_repo="${PROD_BARE_GIT_REPOS_LOCATION}/$1.git"
    infra_dir=$(_get-infra-dir "$1")
    pushd "${infra_dir}/prod/"
        git clone "${bare_repo}"
        cd "$1"
        touch init
        git add -A .
        git commit -m "Init repository"
        git push -u origin master
        execute-on-prod "cd ${PROD_GIT_REPOS_LOCATION} && git clone ${bare_repo}"
    popd
}


HELP['help-update']="manuel help-update

Update help texts and images from the help website from Swisstopo."
function help-update {
    generate --help-update
}


HELP['help-site']="manuel help-site [TYPE] PORTAL

Generate the help website for PORTAL and TYPE.

**Default values**

- *type* dev"
function help-site {
    local portal_type
    local portal
    _set-portal-type "$@"
    local infra_dir=$(_get-infra-dir "${portal}")

    generate --type "${portal_type}" \
        --portal "${portal}" \
        --infra-dir "${infra_dir}" \
        --help-site
}


HELP['verify-sphinx-conf']="manuel verify-sphinx-conf

Check the configuration of sphinx."
function verify-sphinx-conf {
    if ! indextool --checkconfig -c "/etc/sphinx/sphinx.conf" > /dev/null 2>&1; then
        local number_missed_index=$(indextool --checkconfig -c "/etc/sphinx/sphinx.conf" | grep "^missed index(es)" | wc -l)
        if (( ${number_missed_index} == 0 )); then
            indextool --checkconfig -c "/etc/sphinx/sphinx.conf"
            exit 1
        fi
    fi
}


HELP['clean']="manuel clean [TYPE] PORTAL

Clean the generated files for the given type and portal.

**Default Values**

- *type* dev"
function clean {
    local portal_type
    local portal
    _set-portal-type "$@"

    # Leave path unquoted for glob expansion
    rm -rf ${portal_type}/${portal}/*

    pushd "${FRONT_DIR}"
        # Leave path unquoted for glob expansion
        rm -rf ${portal_type}/${portal}/*
        rm -f src/TemplateCacheModule.js
        rm -f src/js/Gf3Plugins.js
        rm -f test/deps
    popd
}


HELP['pushd']="Silent version of builtin pushd"
function pushd {
    command -p pushd "$@" > /dev/null
}


HELP['popd']="Silent version of builtin popd"
function popd {
    command -p popd > /dev/null
}


HELP['vhost']="manuel vhost [TYPE] PORTAL...

Create the vhost files for the given portals.
"
function vhost {
    local portal_type='dev'
    local portal
    local infra_dir
    if [[ "${1:-}" == 'prod' ]]; then
        portal_type=prod
        shift
    elif [[ "${1:-}" == 'dev' ]]; then
        shift
    fi

    for portal in "$@"; do
        infra_dir=$(_get-infra-dir "${portal}")
        generate --type "${portal_type}" \
            --portal "${portal}" \
            --infra-dir "${infra_dir}" \
            --verbose \
            --vhost
    done

    if sudo /usr/sbin/apachectl -t; then
        echo 'restarting apache';
        restart-service apache
    fi
}

