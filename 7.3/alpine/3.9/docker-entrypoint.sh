#!/usr/bin/env bash

set_env_variables () {
  NO_COLOR='\033[0m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'

  INFO_PREFIX="${BLUE}Status:${NO_COLOR}"
  WARNING_PREFIX="${YELLOW}Warning:${NO_COLOR}"
  WORDPRESS_WEBROOT_DIR="/usr/share/nginx/html"

  if [ -z "$WORDPRESS_LANG" ]; then
    echo -e "${WARNING_PREFIX} No Wordpress language specified, setting pt_BR as default"
    WORDPRESS_LANG="pt_BR"
  fi

  if [ -z "$WORDPRESS_DB_HOST" ]; then
    echo -e "${WARNING_PREFIX} No database host address specified, using mariadb as default"
    WORDPRESS_DB_HOST="mariadb"
  fi

  if [ -z "$WORDPRESS_DB_NAME" ]; then
    echo -e "${WARNING_PREFIX} No database name specified, using wordpress as default"
    WORDPRESS_DB_NAME="wordpress"
  fi

  if [ -z "$WORDPRESS_DB_USER" ]; then
    echo -e "${WARNING_PREFIX} No database username specified, using root as default"
    WORDPRESS_DB_USER="root"
  fi

  if [ -z "$WORDPRESS_DB_PASSWORD" ]; then
    echo -e "${WARNING_PREFIX} No database username password specified, using example as default"
    WORDPRESS_DB_PASSWORD="example"
  fi

  if [ -z "$WORDPRESS_DB_TABLE_PREFIX" ]; then
    echo -e "${WARNING_PREFIX} No database table prefix specified, using wp_ as default"
    WORDPRESS_DB_TABLE_PREFIX="wp_"
  fi

  if [ -z "$WORDPRESS_DB_WAIT" ]; then
    echo -e "${WARNING_PREFIX} No database wait time specified, using 10 seconds as default"
    WORDPRESS_DB_WAIT="15"
  fi

  if [ -z "$WORDPRESS_DB_DUMP_FILE" ]; then
    echo -e "${WARNING_PREFIX} No database  SQL file specified, using database/database.sql as default"
    WORDPRESS_DB_DUMP_FILE="database/database.sql"
  fi


  # These are optional.
  # WORDPRESS_OLD_DOMAIN="http://localhost"
  # WORDPRESS_NEW_DOMAIN="http://localhost"
  # WORDPRESS_EXTRA_FLAGS_FILE=".extra_flags"
}

main() {

  echo -e "${GREEN}Welcome to Wordpress microservice${NO_COLOR}"

  echo -e "${GREEN}Setting up environment variables${NO_COLOR}"

  set_env_variables

  echo -e "${GREEN}Done setting up environment variables${NO_COLOR}"

  cd $WORDPRESS_WEBROOT_DIR || exit

  echo -e "${INFO_PREFIX} Checking for something in ${WORDPRESS_WEBROOT_DIR}"

  if [ ! -e index.php ] && [ ! -e wp-includes/version.php ]; then
    echo -e "${WARNING_PREFIX} No Wordpress files found in ${WORDPRESS_WEBROOT_DIR}, assuming new installation"
    download_fresh_wordpress_installation
    setup_wp_config
    mkdir -p "${WORDPRESS_WEBROOT_DIR}/database"
  else
    echo -e "${INFO_PREFIX} Found Wordpress installation files, proceeding with importation mode"
    setup_wp_config
    check_database_import
    additional_flags
  fi
}

download_fresh_wordpress_installation() {
  echo -e "${INFO_PREFIX} Proceeding with fresh installation of Wordpress in ${WORDPRESS_WEBROOT_DIR}"
  wp core download --locale="${WORDPRESS_LANG}" --path="${WORDPRESS_WEBROOT_DIR}" --allow-root
  echo -e "${INFO_PREFIX} Finished downloading the latest version avaliable of Wordpress with ${WORDPRESS_LANG} definition"
}

setup_wp_config() {
  echo -e "${INFO_PREFIX} Creating wp-config.php from sample file"

  if [ -e wp-config-sample.php ]; then
    cp -rf wp-config-sample.php wp-config.php
  fi

  echo -e "${INFO_PREFIX} Setting database constants"

   wp config set DB_HOST "${WORDPRESS_DB_HOST}" --add --type=constant --quiet --allow-root
   wp config set DB_NAME "${WORDPRESS_DB_NAME}" --add --type=constant --quiet --allow-root
   wp config set DB_USER "${WORDPRESS_DB_USER}" --add --type=constant --quiet --allow-root
   wp config set DB_PASSWORD "${WORDPRESS_DB_PASSWORD}" --add --type=constant --quiet --allow-root

   if [ -z ${WORDPRESS_DB_TABLE_PREFIX} ]; then
     echo -e "${WARNING_PREFIX} The default ${WORDPRESS_DB_TABLE_PREFIX} prefix will be used"
     wp config set table_prefix "wp_" --add --type=variable --allow-root
   else
     echo -e "${INFO_PREFIX} Setting ${WORDPRESS_DB_TABLE_PREFIX} as the table prefix for wp-config.php"
     wp config set table_prefix "${WORDPRESS_DB_TABLE_PREFIX}" --add --type=variable --allow-root
   fi

   echo -e "${INFO_PREFIX} Done setting database constants in wp-config.php"

   echo -e "${INFO_PREFIX} Setting security constants"
   wp config set AUTH_KEY "$(pwgen -1 -c -n -s -y -r \<\>\`\"\'\\ 128)" --add --type=constant --quiet --allow-root
   wp config set SECURE_AUTH_KEY "$(pwgen -1 -c -n -s -y -r \<\>\`\"\'\\ 128)" --add --type=constant --quiet --allow-root
	 wp config set LOGGED_IN_KEY "$(pwgen -1 -c -n -s -y -r \<\>\`\"\'\\ 128)" --add --type=constant --quiet --allow-root
	 wp config set NONCE_KEY "$(pwgen -1 -c -n -s -y -r \<\>\`\"\'\\ 128)" --add --type=constant --quiet --allow-root
	 wp config set AUTH_SALT "$(pwgen -1 -c -n -s -y -r \<\>\`\"\'\\ 128)" --add --type=constant --quiet --allow-root
	 wp config set SECURE_AUTH_SALT "$(pwgen -1 -c -n -s -y -r \<\>\`\"\'\\ 128)" --add --type=constant --quiet --allow-root
	 wp config set LOGGED_IN_SALT "$(pwgen -1 -c -n -s -y -r \<\>\`\"\'\\ 128)" --add --type=constant --quiet --allow-root
	 wp config set NONCE_SALT "$(pwgen -1 -c -n -s -y -r \<\>\`\"\'\\ 128)" --add --type=constant --quiet --allow-root
	 echo -e "${INFO_PREFIX} Done setting security constants"

   echo -e "${INFO_PREFIX} Finished creating wp-config.php"
}

check_database_import() {
  echo -e "${INFO_PREFIX} Started SQL file verification"
  if [ ! -e "${WORDPRESS_WEBROOT_DIR}/${WORDPRESS_DB_DUMP_FILE}" ]; then
    echo -e "${WARNING_PREFIX} Skipping database dump file import (from path ${WORDPRESS_WEBROOT_DIR}/${WORDPRESS_DB_DUMP_FILE})"
  else
    echo -e "${INFO_PREFIX} Database file specified and found, importing..."
    wait_for_database
    wp db import "${WORDPRESS_WEBROOT_DIR}/${WORDPRESS_DB_DUMP_FILE}" --allow-root
    replace_site_urls
  fi
  echo -e "${INFO_PREFIX} Done SQL file verification"
}

wait_for_database() {
  if [ -n "${WORDPRESS_DB_WAIT}" ]; then
    echo -e "${WARNING_PREFIX} WORDPRESS_DB_WAIT is defined, waiting for database for ${WORDPRESS_DB_WAIT} seconds"
    sleep ${WORDPRESS_DB_WAIT}
    echo -e "${INFO_PREFIX} Finished waiting for database"
  fi
}

replace_site_urls() {
  if [ -z "${WORDPRESS_OLD_DOMAIN}" ] || [ -z "${WORDPRESS_NEW_DOMAIN}" ]; then
    echo -e "${WARNING_PREFIX} WORDPRESS_OLD_DOMAIN or WORDPRESS_NEW_DOMAIN not defined, no search/replace in database will be perfomed"
    echo -e "${WARNING} Instead, WP_HOME and WP_SITEURL will be defined in wp-config.php"
    no_replace_site_urls
  else
    if [ -z "${WORDPRESS_NETWORK}" ]; then
      echo -e "${INFO_PREFIX} Replacing database values ${WORDPRESS_OLD_DOMAIN} with ${WORDPRESS_NEW_DOMAIN}"
      wp search-replace "${WORDPRESS_OLD_DOMAIN}" "${WORDPRESS_NEW_DOMAIN}" --allow-root
      echo -e "${INFO_PREFIX} Done replacing URL's values"
    else
      echo -e "${INFO_PREFIX} Replacing database values ${WORDPRESS_OLD_DOMAIN} with ${WORDPRESS_NEW_DOMAIN} in network mode"
      wp search-replace "${WORDPRESS_OLD_DOMAIN}" "${WORDPRESS_NEW_DOMAIN}" --allow-root --all-tables
      echo -e "${INFO_PREFIX} Done replacing URL's values in network mode"
    fi
  fi
}

no_replace_site_urls(){
   echo -e "${INFO_PREFIX} Setting WP_HOME and WP_SITEURL to default (http://localhost)"

   wp config set WP_HOME "http://localhost" --add --type=constant --quiet --allow-root --anchor="/* " --placement='before'
   wp config set WP_SITEURL "http://localhost" --add --type=constant --quiet --allow-root --anchor="/* " --placement='before'

   echo -e "${INFO_PREFIX} Done setting WP_HOME and WP_SITEURL in wp-config.php"
}

additional_flags() {
  echo -e "${INFO_PREFIX} Checking for the wp-config extra flags file"
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

set -m
sleep 8760h &
main
echo -e "${GREEN}OK, Wordpress container is ready and will wait for new commands${NO_COLOR}"
fg %1 > /dev/null