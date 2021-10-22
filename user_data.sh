#!/bin/bash

# Update ubuntu and install nextcloud snap
apt update && apt upgrade
snap install nextcloud

# Install nextcloud and configure admin user
nextcloud.manual-install "${admin_user}" "${admin_pass}"

# Configure nextcloud port
snap set nextcloud ports.http="${nextcloud_port}"

# Configure trusted domain
nextcloud.occ config:system:set trusted_domains 1 --value="${a_record}"

# Configure apps
nextcloud.occ app:disable dashboard
nextcloud.occ app:disable text
nextcloud.occ app:enable files_external
nextcloud.occ app:install files_markdown
nextcloud.occ app:install files_texteditor
nextcloud.occ app:install contacts
nextcloud.occ app:install calendar
nextcloud.occ app:install deck
nextcloud.occ app:install tasks

# Add group user
nextcloud.occ group:add user

# Create default user and add to group user
export OC_PASS=${default_user_pass}
nextcloud.occ user:add \
--password-from-env \
--display-name="${default_user}" \
--group="user" \
"${default_user}"

# Configure S3 bucket
nextcloud.occ files_external:create "AmazonS3" amazons3 amazons3::accesskey
nextcloud.occ files_external:config 1 bucket "${bucket_name}"
nextcloud.occ files_external:config 1 region "${aws_region}"
nextcloud.occ files_external:config 1 use_ssl true
nextcloud.occ files_external:config 1 key "${nextcloud_s3_user_id}"
nextcloud.occ files_external:config 1 secret "${nextcloud_s3_user_secret}"
nextcloud.occ files_external:applicable 1 --add-user "${default_user}"

# Stop and start all services
snap stop nextcloud
snap start nextcloud
