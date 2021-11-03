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
nextcloud.occ app:enable encryption
nextcloud.occ app:install files_markdown
nextcloud.occ app:install files_texteditor
nextcloud.occ app:install contacts
nextcloud.occ app:install calendar
nextcloud.occ app:install deck
nextcloud.occ app:install tasks

# Enable encryption
nextcloud.occ encryption:enable

# Configure S3 as primary storage
## Remove last line of config.php
sed -i '$ d' /var/snap/nextcloud/current/nextcloud/config/config.php
## Append config for S3 and closing bracket
cat >> /var/snap/nextcloud/current/nextcloud/config/config.php <<EOF
'objectstore' => [
        'class' => '\\\OC\\\Files\\\ObjectStore\\\S3',
        'arguments' => [
                'bucket' => '${bucket_name}',
                'autocreate' => true,
                'key'    => '${nextcloud_s3_user_id}',
                'secret' => '${nextcloud_s3_user_secret}',
                'use_ssl' => true,
                'region' => '${aws_region}',
                'use_path_style'=>false
        ],
],
'overwriteprotocol' => 'https',
);
EOF

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
