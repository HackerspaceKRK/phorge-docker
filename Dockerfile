FROM debian:bookworm-slim


LABEL org.opencontainers.image.source="https://github.com/HackerspaceKRK/phorge-docker"
LABEL org.opencontainers.image.authors="alufers <alufers@wp.pl>"
LABEL org.opencontainers.image.title="Phorge"
LABEL org.opencontainers.image.description="Phorge is a Phabricator fork with a focus on performance and stability."

ARG PHORGE_SHA=8a3b70aa7d4c3376dabf5dfd5d3a0df68998711c
ARG ARCANIST_SHA=7f28d7266f81985096219a11b949561d70f052e4


ENV GIT_USER=git
ENV MYSQL_PORT=3306
ENV PROTOCOL=http


EXPOSE 80 443

# TODO: Once Phorge is updated to support PHP 8.0,
# we can use PHP from debian repo instead of sury.org

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && apt-get install -y wget lsb-release && \
    wget --progress=dot:giga -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" >> /etc/apt/sources.list.d/php.list && \
    apt-get update -y && \
    apt-get -y install \
    mercurial subversion sudo apt-transport-https ca-certificates wget git \
    php7.4 php7.4-mysql php7.4-gd php7.4-curl php7.4-apcu php7.4-cli php7.4-json php7.4-ldap \
    php7.4-mbstring php7.4-fpm php7.4-zip php-pear php7.4-xml \
    nginx supervisor procps python3-pygments imagemagick curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY ./arcanist-enable-s3-over-http.patch /tmp/arcanist-enable-s3-over-http.patch

RUN mkdir -p /var/www/phorge \
    && cd /var/www/phorge \
    && git clone https://we.phorge.it/source/phorge.git \
    && cd /var/www/phorge/phorge \
    && git checkout $PHORGE_SHA \
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
COPY ./configs/www.conf /etc/php/7.4/fpm/pool.d/www.conf
COPY ./configs/php.ini /etc/php/7.4/fpm/php.ini
COPY ./configs/php-fpm.conf /etc/php/7.4/fpm/php-fpm.conf

#copy supervisord config
COPY ./configs/supervisord.conf /etc/supervisord.conf
COPY ./scripts/startup.sh /startup.sh

RUN mkdir -p /run/php && chown www-data:www-data /run/php \
    && chmod +x /startup.sh

# #copy startup script
RUN mkdir -p /var/repo/ && rm -rf /var/cache/apt
CMD [ "/startup.sh" ]
