#!/bin/bash

# [SETUP] Install necessary packages, including git
echo -e "[SETUP] Install packages"
apt-get update -qq > /dev/null 2>&1 && apt-get install -qq > /dev/null 2>&1 -y git wget php php-sqlite3 php-xml perl perl-doc fcgiwrap unzip jq

# Add VERSION file
wget -q -O - https://api.tavuru.de/version/Ym0T/pterodactyl-nginx-egg | grep -o '"version":"[^"]*"' | cut -d'"' -f4 | head -1 > /mnt/server/VERSION

# Change to server directory
cd /mnt/server || { echo "[ERROR] Failed to access /mnt/server"; exit 1; }

# [SETUP] Create necessary folders
echo -e "[SETUP] Create folders"
mkdir -p logs tmp www nginx

# Clone the default repository into a temporary directory
echo "[Git] Cloning default repository 'https://github.com/Riptiaz/pterodactyl-nginx-egg' into temporary directory."
git clone https://github.com/Riptiaz/pterodactyl-nginx-egg /mnt/server/gtemp > /dev/null 2>&1 && echo "[Git] Repository cloned successfully." || { echo "[Git] Error: Default repository clone failed."; exit 21; }

# Copy the necessary folders and files
echo "[Git] Copying folders and files from default repository."
cp -r /mnt/server/gtemp/nginx /mnt/server || { echo "[Git] Error: Copying 'nginx' folder failed."; exit 22; }
cp -r /mnt/server/gtemp/php /mnt/server || { echo "[Git] Error: Copying 'php' folder failed."; exit 22; }
cp -r /mnt/server/gtemp/modules /mnt/server || { echo "[Git] Error: Copying 'modules' folder failed."; exit 22; }
cp /mnt/server/gtemp/start-modules.sh /mnt/server || { echo "[Git] Error: Copying 'start-modules.sh' failed."; exit 22; }
cp /mnt/server/gtemp/LICENSE /mnt/server || { echo "[Git] Error: Copying 'LICENSE' failed."; exit 22; }
chmod +x /mnt/server/start-modules.sh
find /mnt/server/modules -type f -name "*.sh" -exec chmod +x {} \;

# Remove temporary cloned repository
rm -rf /mnt/server/gtemp

# Ensure only one main option is active
COUNT_TRUE=$(( ${AZURIOM:-0} + ${LAUNCHER:-0} + ${WORDPRESS:-0} ))
if [[ "$COUNT_TRUE" -gt 1 ]]; then
    echo "[ERROR] Only one option (AZURIOM, LAUNCHER, WORDPRESS) can be active at a time."
    exit 1
fi

# Remove existing configurations in conf.d
echo "[Clean] Removing existing configurations in conf.d folder..."
rm -rf /mnt/server/nginx/conf.d/* || { echo "[Clean] Error: Failed to clean conf.d"; exit 33; }

# Define the correct configuration file based on the selected option
CONFIG_FILE="default.conf.base" # Default config file
if [[ "${AZURIOM}" == "true" || "${AZURIOM}" == "1" ]]; then
    CONFIG_FILE="default.conf.azuriom"
elif [[ "${LAUNCHER}" == "true" || "${LAUNCHER}" == "1" ]]; then
    CONFIG_FILE="default.conf.launcher"
fi

# Download and rename the appropriate configuration file
CONFIG_URL="https://raw.githubusercontent.com/Riptiaz/pterodactyl-nginx-egg/main/nginx/conf.d/${CONFIG_FILE}"
echo "[Download] Downloading configuration file: $CONFIG_FILE"
wget -q -O /mnt/server/nginx/conf.d/default.conf "$CONFIG_URL" || { echo "[Download] Error: Failed to download $CONFIG_FILE"; exit 32; }
echo "[Setup] Successfully set up default.conf using $CONFIG_FILE"

# [AZURIOM] Install Azuriom if requested
if [[ "${AZURIOM}" == "true" || "${AZURIOM}" == "1" ]]; then
    echo "[Azuriom] Preparing 'www' directory..."
    rm -rf /mnt/server/www && mkdir -p /mnt/server/www
    cd /mnt/server/www || { echo "[Azuriom] Error: Could not access /mnt/server/www"; exit 1; }

    ZIP_URL="https://github.com/Azuriom/AzuriomInstaller/releases/latest/download/AzuriomInstaller.zip"
    ZIP_FILE="/mnt/server/tmp/AzuriomInstaller.zip"

    echo "[Azuriom] Downloading installer from $ZIP_URL"
    wget -q -O $ZIP_FILE $ZIP_URL || { echo "[Azuriom] Error: Failed to download ZIP file."; exit 32; }

    echo "[Azuriom] Extracting ZIP file..."
    unzip -q $ZIP_FILE -d /mnt/server/www || { echo "[Azuriom] Error: Failed to extract ZIP."; exit 34; }
    rm -f $ZIP_FILE
    echo "[Azuriom] Installation complete."
fi

# [LAUNCHER] Install CentralCorp Launcher if requested
if [[ "${LAUNCHER}" == "true" || "${LAUNCHER}" == "1" ]]; then
    echo "[Launcher] Preparing 'www' directory..."
    rm -rf /mnt/server/www && mkdir -p /mnt/server/www
    cd /mnt/server/www || { echo "[Launcher] Error: Could not access /mnt/server/www"; exit 1; }

    echo "[Launcher] Cloning CentralCorp-Panel..."
    git clone "https://github.com/Riptiaz/CentralCorp-Panel.git" /mnt/server/www > /dev/null 2>&1 || { echo "[Launcher] Error: git clone failed."; exit 14; }
    echo "[Launcher] Installation complete."
fi

# Check if GIT_ADDRESS is set
if [ -n "${GIT_ADDRESS}" ]; then
    [[ ${GIT_ADDRESS} != *.git ]] && GIT_ADDRESS="${GIT_ADDRESS}.git"
    echo "[Git] Using repository: ${GIT_ADDRESS}"

    if [ -n "${USERNAME}" ] && [ -n "${ACCESS_TOKEN}" ]; then
        echo "[Git] Using authenticated Git access."
        GIT_DOMAIN=$(echo "${GIT_ADDRESS}" | cut -d/ -f3)
        GIT_REPO=$(echo "${GIT_ADDRESS}" | cut -d/ -f4-)
        GIT_ADDRESS="https://${USERNAME}:${ACCESS_TOKEN}@${GIT_DOMAIN}/${GIT_REPO}"
    fi

    mkdir -p /mnt/server/www && rm -rf /mnt/server/www/*

    cd /mnt/server/www || { echo "[Git] Error: Could not access /mnt/server/www"; exit 1; }

    git clone ${GIT_ADDRESS} . > /dev/null 2>&1 || { echo "[Git] Error: git clone failed for 'www'."; exit 14; }
fi

# Install WordPress if requested
if [ "${WORDPRESS}" == "true" ] || [ "${WORDPRESS}" == "1" ]; then
    echo "[WordPress] Installing WordPress..."
    cd /mnt/server/www || exit 1
    wget -q http://wordpress.org/latest.tar.gz || { echo "[WordPress] Error: Downloading WordPress failed."; exit 16; }
    tar xzf latest.tar.gz
    mv wordpress/* .
    rm -rf wordpress latest.tar.gz
    echo "[WordPress] Installation complete - http://ip:port/wp-admin"
elif [ -z "${GIT_ADDRESS}" ]; then
    echo "<?php phpinfo(); ?>" > www/index.php
fi

echo -e "[DONE] All installations completed successfully."
echo -e "[INFO] You can now start the Nginx web server."
