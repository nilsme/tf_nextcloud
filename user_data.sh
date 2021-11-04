#!/bin/bash

# Update ubuntu and install nextcloud snap
apt update && apt --yes upgrade
snap install nextcloud

# Create data directory for manual install and set rights
mkdir /var/snap/nextcloud/common/nextcloud/data
chmod 770 /var/snap/nextcloud/common/nextcloud/data

# Install Nextcloud, configure MariaDB and set admin user
nextcloud.occ maintenance:install \
  --database "mysql" \
  --database-name "nextcloud"  \
  --database-host "${mariadb_host}" \
  --database-port "${mariadb_port}" \
  --database-user "${mariadb_user}" \
  --database-pass "${mariadb_pass}" \
  --admin-user "${admin_user}" \
  --admin-pass "${admin_pass}" \
  --data-dir "/var/snap/nextcloud/common/nextcloud/data"

# Configure S3 as primary storage
nextcloud.occ config:system:set objectstore class --value=\\OC\\Files\\ObjectStore\\S3
nextcloud.occ config:system:set objectstore arguments bucket --value="${bucket_name}"
nextcloud.occ config:system:set objectstore arguments autocreate --value=true --type=boolean
nextcloud.occ config:system:set objectstore arguments key --value="${nextcloud_s3_user_id}"
nextcloud.occ config:system:set objectstore arguments secret --value="${nextcloud_s3_user_secret}"
nextcloud.occ config:system:set objectstore arguments use_ssl --value=true --type=boolean
nextcloud.occ config:system:set objectstore arguments region --value="${aws_region}"
nextcloud.occ config:system:set objectstore arguments use_path_style --value=false --type=boolean

# Enforce https protocol
nextcloud.occ config:system:set overwriteprotocol --value=https

# Configure nextcloud port
snap set nextcloud ports.http="${nextcloud_port}"

# Configure trusted domain
nextcloud.occ config:system:set trusted_domains 1 --value="${a_record}"

# Configure apps
nextcloud.occ app:disable dashboard
nextcloud.occ app:disable text
nextcloud.occ app:enable files_external
nextcloud.occ app:enable encryption
nextcloud.occ app:install files_markdown
nextcloud.occ app:install files_texteditor
nextcloud.occ app:install contacts
nextcloud.occ app:install calendar
nextcloud.occ app:install deck
nextcloud.occ app:install tasks

# Enable encryption
nextcloud.occ encryption:enable

# Add group user
nextcloud.occ group:add user

# Create default user and add to group user
export OC_PASS=${default_user_pass}
nextcloud.occ user:add \
  --password-from-env \
  --display-name="${default_user}" \
  --group="user" \
  "${default_user}"

# Stop and start all services
snap stop nextcloud
snap start nextcloud

# Reboot system
reboot --now
