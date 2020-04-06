FROM php:7.3-fpm-alpine3.9 AS base

ENV CFLAGS="-I/usr/src/php"

RUN apk --update --no-cache add shadow libpng-dev libxml2-dev libxslt-dev libzip-dev && rm -rf /var/cache/apk/*

RUN docker-php-ext-install gd json mbstring pdo pdo_mysql xml xmlreader xmlrpc xmlwriter xsl zip mysqli

RUN usermod -u 1000 www-data && groupmod -g 1000 www-data

RUN find / -group 82 -exec chgrp -h www-data {} \; && find / -user 82 -exec chown -h www-data {} \;

EXPOSE 9000

CMD ["php-fpm"]

FROM base as wordpress

ENV CFLAGS="-I/usr/src/php"

RUN apk add --update --no-cache bash pwgen mariadb-client && rm -rf /var/cache/apk/*

RUN curl -o /usr/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
  chmod a+x /usr/bin/wp && wp --version --allow-root

COPY docker-entrypoint.sh /start

RUN chmod a+x /start

USER www-data

WORKDIR /usr/share/nginx/html

CMD ["/bin/bash", "-c", "/start"]