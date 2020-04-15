FROM wordpress:php7.2-apache

ENV WEB_ROOT_DIR="/var/www/html"
ENV WORDPRESS_LANG="pt_BR"
ENV MUST_WAIT_DB=15
ENV WORDPRESS_ENV="dev"
ENV WORDPRESS_TABLE_PREFIX="wp_"

COPY docker-entrypoint.sh /start
COPY apache2-foreground.sh /usr/bin/apache2-foreground
COPY conf/default.conf /etc/apache2/sites-available/000-default.conf
COPY conf/.htaccess /tmp/.htaccess
COPY conf/php.ini-development /usr/local/etc/php/php.ini

RUN apt-get update -y -q && apt-get install -y mariadb-client curl nano wget git pwgen

RUN docker-php-ext-install pdo pdo_mysql

RUN curl -o /usr/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar

RUN chmod a+x /usr/bin/wp && chmod a+x /start && chmod a+x /usr/bin/apache2-foreground

EXPOSE 80 443

VOLUME /var/www/html /usr/local/etc/php

WORKDIR /var/www/html

CMD ["/bin/bash", "/start"]