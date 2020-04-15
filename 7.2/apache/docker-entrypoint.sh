#!/bin/bash

RED='\033[0;31m'
NO_COLOR='\033[0m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
INFO_PREFIX="${BLUE}Status:${NO_COLOR}"
WARNING_PREFIX="${YELLOW}Warning:${NO_COLOR}"
STARTED_PREFIX="${GREEN}Started:${NO_COLOR}"

cd "${WEB_ROOT_DIR}" || exit

run_web_server() {
  echo -e "${STARTED_PREFIX} Apache web server"
  apache2-foreground
}

setup_config_file() {
  if [ ! -e wp-config-sample.php ]; then
    echo -e "${WARNING_PREFIX}: Wordpress sample config file not found. Please setup wp-config.php manually using the following info: "
    echo -e "${WARNING_PREFIX}: define('DB_HOST', '${WORDPRESS_DB_HOST}');"
    echo -e "${WARNING_PREFIX}: define('DB_NAME', '${WORDPRESS_DB_NAME}');"
    echo -e "${WARNING_PREFIX}: define('DB_USER', '${WORDPRESS_DB_USER}');"
    echo -e "${WARNING_PREFIX}: define('DB_PASSWORD', ${WORDPRESS_DB_PASSWORD}');"
    echo -e "${WARNING_PREFIX}: define('WP_HOME', ${WORDPRESS_HOME_URL}');"
    echo -e "${WARNING_PREFIX}: define('WP_SITEURL', ${WORDPRESS_SITEURL}');"
    run_web_server
  else
    echo -e "${STARTED_PREFIX} Creating wp-config.php, copying the sample file"
    # shellcheck disable=SC2216
    yes | cp -rf wp-config-sample.php wp-config.php

    echo -e "${INFO_PREFIX} Setting database constants"

    wp config set DB_HOST "${WORDPRESS_DB_HOST}" --add --type=constant --quiet --allow-root
    wp config set DB_NAME "${WORDPRESS_DB_NAME}" --add --type=constant --quiet --allow-root
    wp config set DB_USER "${WORDPRESS_DB_USER}" --add --type=constant --quiet --allow-root
    wp config set DB_PASSWORD "${WORDPRESS_DB_PASSWORD}" --add --type=constant --quiet --allow-root

    echo -e "${INFO_PREFIX} Done setting database constants"

    if [ -z "${WORDPRESS_TABLE_PREFIX}" ]; then
      echo -e "${INFO_PREFIX} Leaving the default table prefix to wp_"
    else
      echo -e "${INFO_PREFIX} Setting up ${WORDPRESS_TABLE_PREFIX} as table prefix for wp-config.php"
      wp config set table_prefix "${WORDPRESS_TABLE_PREFIX}" --add --type=variable --allow-root
    fi

    echo -e "${INFO_PREFIX} Setting security constants"

    wp config set AUTH_KEY "$(pwgen -1 -c -n -s -y -r \`\"\'\\ 128)" --add --type=constant --quiet --allow-root
    wp config set SECURE_AUTH_KEY "$(pwgen -1 -c -n -s -y -r \`\"\'\\ 128)" --add --type=constant --quiet --allow-root
		wp config set LOGGED_IN_KEY "$(pwgen -1 -c -n -s -y -r \`\"\'\\ 128)" --add --type=constant --quiet --allow-root
		wp config set NONCE_KEY "$(pwgen -1 -c -n -s -y -r \`\"\'\\ 128)" --add --type=constant --quiet --allow-root
		wp config set AUTH_SALT "$(pwgen -1 -c -n -s -y -r \`\"\'\\ 128)" --add --type=constant --quiet --allow-root
		wp config set SECURE_AUTH_SALT "$(pwgen -1 -c -n -s -y -r \`\"\'\\ 128)" --add --type=constant --quiet --allow-root
		wp config set LOGGED_IN_SALT "$(pwgen -1 -c -n -s -y -r \`\"\'\\ 128)" --add --type=constant --quiet --allow-root
		wp config set NONCE_SALT "$(pwgen -1 -c -n -s -y -r \`\"\'\\ 128)" --add --type=constant --quiet --allow-root
		echo -e "${INFO_PREFIX} Done setting security constants"
  fi
  echo -e "${INFO_PREFIX} Finished creating wp-config.php"
}

check_database_import() {
  echo -e "${STARTED_PREFIX} Started SQL file import verification"
  if [ ! -e "${WEB_ROOT_DIR}"/"${WORDPRESS_DB_FILE}" ]; then
    echo -e "${WARNING_PREFIX} SQL file not specified, skipping database import"
  else
    echo -e "${INFO_PREFIX} Database file specified, importing..."
    wp db import "${WEB_ROOT_DIR}"/"${WORDPRESS_DB_FILE}" --allow-root
  fi
  echo -e "${INFO_PREFIX} Done SQL file verification"
}

replace_site_urls() {
  if [ -z "${WORDPRESS_OLD_DOMAIN}" ] || [ -z "${WORDPRESS_NEW_DOMAIN}" ]; then
    echo -e "${INFO_PREFIX} URL's not defined, setting localhost in wp-config.php file"
    wp config set WP_HOME "http://localhost" --add --type=constant --quiet --allow-root
    wp config set WP_SITEURL "http://localhost" --add --type=constant --quiet --allow-root
    echo -e "${INFO_PREFIX} Done setting additional URL's in wp-config.php file"
  else
    if [ -z "${WORDPRESS_NETWORK}" ]; then
      echo -e "${INFO_PREFIX} Replacing database values ${WORDPRESS_OLD_DOMAIN} with ${WORDPRESS_NEW_DOMAIN}"
      wp search-replace "${WORDPRESS_OLD_DOMAIN}" "${WORDPRESS_NEW_DOMAIN}" --allow-root
      echo -e "${INFO_PREFIX} Done replacing URL's values"
    else
      echo -e "${INFO_PREFIX} Replacing database values ${WORDPRESS_OLD_DOMAIN} with ${WORDPRESS_NEW_DOMAIN} in network"
      wp search-replace "${WORDPRESS_OLD_DOMAIN}" "${WORDPRESS_NEW_DOMAIN}" --allow-root --all-tables
      echo -e "${INFO_PREFIX} Done replacing URL's values in network mode"
    fi
  fi
}

check_htaccess() {
  echo -e "${STARTED_PREFIX} Checking if .htaccess need to be modified"
  if [ ! -e .htaccess ]; then
    echo -e "${INFO_PREFIX} Copying .htaccess"
    cp /tmp/.htaccess "${WEB_ROOT_DIR}"
  else
    echo -e "${INFO_PREFIX} Current .htaccess will be not modified"
  fi
}

wait_for_database() {
  # shellcheck disable=SC2236
  if [ ! -z "${MUST_WAIT_DB}" ]; then
    echo -e "${WARNING_PREFIX} Ok, waiting for database for ${MUST_WAIT_DB} seconds."
    sleep "${MUST_WAIT_DB}"
    echo -e "${WARNING_PREFIX} Finished waiting for database."
  fi
}

additional_flags() {
  echo -e "${STARTED_PREFIX} Checking for the wp-config extra flags file"
  if [ ! -e "${WORDPRESS_EXTRA_FLAGS_FILE}" ]; then
    echo -e "${INFO_PREFIX} No additional flags file specified, skipping"
  else
    echo -e "${INFO_PREFIX} Additional flags file specified, adding extras"
    echo -e "${INFO_PREFIX} Reading flag(s) in file"
      while IFS= read -r line; do
        declare "${line}";
      done < "${WORDPRESS_EXTRA_FLAGS_FILE}"
    echo -e "${INFO_PREFIX} Done reading flags file"

    echo -e "${INFO_PREFIX} Setting up additional flags on wp-config.php"
    for var in "${!WPF_@}"; do
      FLAG_NAME="$var"
      FLAG_NAME=${FLAG_NAME#"WPF_"}
      echo -e "${WARNING_PREFIX} Setting up flag ${FLAG_NAME} with value ${!var}"
      wp config set "${FLAG_NAME}" "${!var}" --add --type=constant --raw --quiet --allow-root --anchor="/* " --placement='before'
      echo -e "${INFO_PREFIX} Done setting up flag, moving to next flag"
    done

    echo -e "${INFO_PREFIX} Done setting up additional flags on wp-config.php"

  fi
}

fix_permissions() {
  echo -e "${STARTED_PREFIX} Setting permissions for files and folders"
  chown www-data:www-data  -R .

  if [ "${WORDPRESS_ENV}" = "dev" ]; then
    echo -e "${INFO_PREFIX} Dev mode started, the user www-data (33) and group www-data(33) will have all permissions and ownerships."
    chgrp -R www-data "${WEB_ROOT_DIR}"
    echo -e "${INFO_PREFIX} Modifying permissions to Group can Read/Write/Execute on all directories"
    find "${WEB_ROOT_DIR}" -type d -exec chmod g+rwx {} +
    echo -e "${INFO_PREFIX} Modifying permissions to Group can Read/Write/Execute on all files"
    find "${WEB_ROOT_DIR}" -type f -exec chmod g+rwx {} +
  fi
  echo -e "${INFO_PREFIX} Done setting permissions for files and folders"
}

import_wordpress() {
    setup_config_file
    wait_for_database
    check_database_import
    replace_site_urls
    check_htaccess
    additional_flags
    fix_permissions
    run_web_server
}

install_wordpress() {
  echo -e "${INFO_PREFIX} Wordpress installation not found in ${WEB_ROOT_DIR} - installing..."
  wp core download --locale="${WORDPRESS_LANG}" --allow-root
  cp /tmp/.htaccess "${WEB_ROOT_DIR}"
  echo -e "${INFO_PREFIX} Latest Wordpress was downloaded for language ${WORDPRESS_LANG}"

  # shellcheck disable=SC2086
  if [ -z ${WORDPRESS_DB_HOST} ] || [ -z ${WORDPRESS_DB_USER} ] || [ -z ${WORDPRESS_DB_NAME} ] || [ -z ${WORDPRESS_DB_PASSWORD} ] || [ -z ${WORDPRESS_TABLE_PREFIX} ]; then
    echo -e "${WARNING_PREFIX} File wp-config.php will be ${RED}not${NC} generated. You must proceed with Wordpress database setup."
  else
    echo -e "${WARNING_PREFIX} File wp-config.php will be generated for this fresh install. You must proceed with site setup."
    setup_config_file
  fi

  fix_permissions
  run_web_server
}

echo -e "${STARTED_PREFIX} Setting up application"

if ! [ -e index.php -a -e wp-includes/version.php ]; then
  echo -e "${WARNING_PREFIX} Proceeding to Wordpress fresh install"
  install_wordpress
else
  echo -e "${INFO_PREFIX} Trying to make a Wordpress install import"
  # shellcheck disable=SC2086
  if [ -z ${WORDPRESS_DB_HOST} ] || [ -z ${WORDPRESS_DB_USER} ] || [ -z ${WORDPRESS_DB_NAME} ] || [ -z ${WORDPRESS_DB_PASSWORD} ]; then
    echo -e "${INFO_PREFIX} One or more variables are not set, cannot proceed with import";
  else
    echo -e "${INFO_PREFIX} Proceeding to Wordpress installation import"
    import_wordpress
  fi
fi
