FROM debian:trixie-slim


LABEL org.opencontainers.image.source="https://github.com/HackerspaceKRK/phorge-docker"
LABEL org.opencontainers.image.authors="alufers <alufers@wp.pl>"
LABEL org.opencontainers.image.title="Phorge"
LABEL org.opencontainers.image.description="Phorge is a Phabricator fork with a focus on performance and stability."

ARG PHORGE_SHA=f7a7ef8c1a345976aa3c404c0f6622676f787f76
ARG ARCANIST_SHA=fd29b156dec5ab4eb47b5df993c3786fb94140e1


ENV GIT_USER=git
ENV MYSQL_PORT=3306
ENV PROTOCOL=http


EXPOSE 80 443


ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && \
    apt-get -y install \
    mercurial subversion sudo apt-transport-https ca-certificates wget git \
    php8.4 php8.4-mysql php8.4-gd php8.4-curl php8.4-apcu php8.4-cli php8.4-ldap \
    php8.4-mbstring php8.4-fpm php8.4-zip php-pear php8.4-xml \
    nginx supervisor procps python3-pygments imagemagick curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY ./arcanist-enable-s3-over-http.patch /tmp/arcanist-enable-s3-over-http.patch
COPY ./allow-calendar-search-by-dates.patch /tmp/allow-calendar-search-by-dates.patch

RUN mkdir -p /var/www/phorge \
    && cd /var/www/phorge \
    && git clone https://we.phorge.it/source/phorge.git \
    && cd /var/www/phorge/phorge \
    && git checkout $PHORGE_SHA \
    && git apply /tmp/allow-calendar-search-by-dates.patch \
    && cd /var/www/phorge \
    && git clone https://we.phorge.it/source/arcanist.git \
    && cd /var/www/phorge/arcanist \
    && git checkout $ARCANIST_SHA \
    && git apply /tmp/arcanist-enable-s3-over-http.patch \
    && rm -rf /var/www/phorge/phorge/.git \
    && rm -rf /var/www/phorge/arcanist/.git


# #copy nginx config
COPY ./configs/nginx-ph.conf /etc/nginx/sites-available/phorge.conf
COPY ./configs/nginx.conf /etc/nginx/nginx.conf
# add phorge to nginx sites-enabled and remove default
RUN ln -s /etc/nginx/sites-available/phorge.conf /etc/nginx/sites-enabled/phorge.conf \
    && rm /etc/nginx/sites-enabled/default


#copy php config
COPY ./configs/www.conf /etc/php/8.4/fpm/pool.d/www.conf
COPY ./configs/php.ini /etc/php/8.4/fpm/php.ini
COPY ./configs/php-fpm.conf /etc/php/8.4/fpm/php-fpm.conf

#copy supervisord config
COPY ./configs/supervisord.conf /etc/supervisord.conf
COPY ./scripts/startup.sh /startup.sh

COPY ./extensions/PhabricatorPhabricatorAuthProvider.php /var/www/phorge/phorge/src/extensions/PhabricatorPhabricatorAuthProvider.php
COPY ./extensions/PhutilAuthentikAuthAdapter.php /var/www/phorge/phorge/src/extensions/PhutilAuthentikAuthAdapter.php

RUN mkdir -p /run/php && chown www-data:www-data /run/php \
    && chmod +x /startup.sh

# #copy startup script
RUN mkdir -p /var/repo/ && rm -rf /var/cache/apt
CMD [ "/startup.sh" ]
