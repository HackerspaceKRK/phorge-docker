#!/bin/bash

set -e


if id "$GIT_USER" >/dev/null 2>&1; then
        echo "user $GIT_USER already exists"
else
        useradd "$GIT_USER"
        usermod -p NP "$GIT_USER"
        echo "$GIT_USER ALL=(daemon) SETENV: NOPASSWD: /bin/ls, /usr/bin/git, /usr/bin/git-upload-pack, /usr/bin/git-receive-pack, /usr/bin/ssh" >> /etc/sudoers
        chown -R "$GIT_USER" /var/repo
        /var/www/phorge/phorge/bin/config set phd.user "$GIT_USER"
        /var/www/phorge/phorge/bin/config set diffusion.ssh-user "$GIT_USER"
fi


/var/www/phorge/phorge/bin/config set files.enable-imagemagick true
#DB configuration
/var/www/phorge/phorge/bin/config set mysql.host "$MYSQL_HOST"
/var/www/phorge/phorge/bin/config set mysql.port "$MYSQL_PORT"
/var/www/phorge/phorge/bin/config set mysql.user "$MYSQL_USER"

# if MYSQL_PASSWORD is empty, use check MYSQL_PASSWORD_FILE
if [ -z "$MYSQL_PASSWORD" ]
then
    if [ -z "$MYSQL_PASSWORD_FILE" ]
    then
        echo "MYSQL_PASSWORD or MYSQL_PASSWORD_FILE must be set"
        exit 1
    else
        MYSQL_PASSWORD=$(cat "$MYSQL_PASSWORD_FILE")
    fi
fi

/var/www/phorge/phorge/bin/config set mysql.pass "$MYSQL_PASSWORD"
/var/www/phorge/phorge/bin/config set diffusion.allow-http-auth true

if [ "$PROTOCOL" == "https" ]
then

        # We want to output PHP
        # shellcheck disable=SC2016
    echo '<?php

$_SERVER['"'"'HTTPS'"'"'] = true;' > /var/www/phorge/phorge/support/preamble.php
fi

#Large file storage configuration
if [ -n "$MINIO_SERVER" ]
then
    /var/www/phorge/phorge/bin/config set storage.s3.bucket "$MINIO_BUCKET"
    if [ -n "$MINIO_SERVER_SECRET_KEY_FILE" ]
    then
        MINIO_SERVER_SECRET_KEY=$(cat "$MINIO_SERVER_SECRET_KEY_FILE")
    fi
    if [ -n "$MINIO_SERVER_ACCESS_KEY_FILE" ]
    then
        MINIO_SERVER_ACCESS_KEY=$(cat "$MINIO_SERVER_ACCESS_KEY_FILE")
    fi
    /var/www/phorge/phorge/bin/config set amazon-s3.secret-key "$MINIO_SERVER_SECRET_KEY"
    /var/www/phorge/phorge/bin/config set amazon-s3.access-key "$MINIO_SERVER_ACCESS_KEY"
    /var/www/phorge/phorge/bin/config set amazon-s3.endpoint "$MINIO_SERVER:$MINIO_PORT"
    if [ -n "$MINIO_REGION" ]
    then
        /var/www/phorge/phorge/bin/config set amazon-s3.region "$MINIO_REGION"
    else
        # phorge needs a region to think that s3 is configured at all
        /var/www/phorge/phorge/bin/config set amazon-s3.region us-west-1
    fi

fi

if [ -n "$LOCAL_DISK_STORAGE_PATH" ]
then
    /var/www/phorge/phorge/bin/config set storage.local-disk.path "$LOCAL_DISK_STORAGE_PATH"
    chown -R www-data:www-data "$LOCAL_DISK_STORAGE_PATH"
fi

if [ -n "$MAILERS_CONFIG_FILE" ]
then
    /var/www/phorge/phorge/bin/config set cluster.mailers --stdin < "$MAILERS_CONFIG_FILE"
else
    if [ -n "$SMTP_SERVER" ] && [ -n "$SMTP_PORT" ] && [ -n "$SMTP_USER" ] && [ -n "$SMTP_PASSWORD" ] &&  [ -n "$SMTP_PROTOCOL" ]
    then
        echo "[
    {
        \"key\": \"smtp-mailer\",
        \"type\": \"smtp\",
        \"options\": {
        \"host\": \"$SMTP_SERVER\",
        \"port\": $SMTP_PORT,
        \"user\": \"$SMTP_USER\",
        \"password\": \"$SMTP_PASSWORD\",
        \"protocol\": \"$SMTP_PROTOCOL\"
        }
    }
    ]" > /tmp/mailers.json
        /var/www/phorge/phorge/bin/config set cluster.mailers --stdin < /tmp/mailers.json
        rm /tmp/mailers.json
    fi
fi





echo setting "$PROTOCOL://$BASE_URI/"

# Update base uri
/var/www/phorge/phorge/bin/config set phabricator.base-uri "$PROTOCOL://$BASE_URI/"
sed -i "s/  server_name phorge.local;/  server_name $BASE_URI;/g" /etc/nginx/sites-available/phorge.conf
#sed "s/    return 301 \$scheme:\/\/phorge.local$request_uri;"
#general parameters configuration
/var/www/phorge/phorge/bin/config set pygments.enabled true
/var/www/phorge/phorge/bin/config set phabricator.show-prototypes true
#setup db if not exists
/var/www/phorge/phorge/bin/storage upgrade --force
#start supervisord
/usr/bin/supervisord -n -c /etc/supervisord.conf
