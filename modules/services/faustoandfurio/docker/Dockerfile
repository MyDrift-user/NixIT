FROM wordpress:php8.3-apache
RUN a2enmod headers
COPY security.conf /etc/apache2/conf-enabled/zz-security.conf
COPY php.ini /usr/local/etc/php/conf.d/zz-site.ini
