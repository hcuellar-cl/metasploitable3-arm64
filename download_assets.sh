#!/bin/bash
# Script to download dependencies and prepare offline resources for Metasploitable 3 ARM.
# Must be executed on the host machine (Host Mac).

set -euo pipefail

# Target directories
BUILD_DIR="metasploitable3-arm-build"
ASSETS_DIR="$BUILD_DIR/assets"
CONFIGS_DIR="$BUILD_DIR/configs"

echo "=== Creating directory structure ==="
mkdir -p "$ASSETS_DIR"
mkdir -p "$CONFIGS_DIR"

# Function to download files safely and portably
download_file() {
    local file="$1"
    local url="$2"
    local target="$ASSETS_DIR/$file"
    
    if [ -f "$target" ]; then
        echo "✓ $file already exists, skipping download."
    else
        echo "Downloading $file from $url..."
        # Use curl with -L to follow redirects, --fail to exit on HTTP error >= 400, and --retry for resilience
        if ! curl -L --fail --retry 3 --retry-delay 2 -o "$target" "$url"; then
            echo "ERROR: Failed to download $file"
            # Fallback download attempt if ftp.proftpd.org or similar fails
            if [ "$file" == "proftpd-1.3.5.tar.gz" ]; then
                echo "Attempting alternative mirror for ProFTPd..."
                if ! curl -L --fail -o "$target" "https://github.com/proftpd/proftpd/archive/refs/tags/v1.3.5.tar.gz"; then
                    echo "ERROR: Alternative mirror for ProFTPd also failed."
                    exit 1
                fi
            else
                exit 1
            fi
        fi
    fi
}

echo "=== Downloading source packages ==="
download_file "php-5.4.5.tar.gz" "http://museum.php.net/php5/php-5.4.5.tar.gz"
download_file "Unreal3.2.8.1_backdoor.tar.gz" "https://www.exploit-db.com/apps/752e46f2d873c1679fa99de3f52a274d-Unreal3.2.8.1_backdoor.tar_.gz"
download_file "proftpd-1.3.5.tar.gz" "https://ftp.osuosl.org/pub/blfs/conglomeration/proftpd/proftpd-1.3.5.tar.gz"
download_file "drupal-7.5.tar.gz" "https://ftp.drupal.org/files/projects/drupal-7.5.tar.gz"
download_file "coder-7.x-2.5.tar.gz" "https://ftp.drupal.org/files/projects/coder-7.x-2.5.tar.gz"
download_file "apache-continuum-1.4.2-bin.tar.gz" "http://archive.apache.org/dist/continuum/binaries/apache-continuum-1.4.2-bin.tar.gz"
download_file "phpMyAdmin-3.5.8-all-languages.tar.gz" "https://files.phpmyadmin.net/phpMyAdmin/3.5.8/phpMyAdmin-3.5.8-all-languages.tar.gz"
download_file "libxml29_compat.patch" "https://mail.gnome.org/archives/xml/2012-August/txtbgxGXAvz4N.txt"
download_file "metasploitable3-readme.tar.gz" "https://github.com/jbarnett-r7/metasploitable3-readme/archive/refs/heads/master.tar.gz"
download_file "libssl1.0.0_1.0.2n-1ubuntu5.13_amd64.deb" "http://security.ubuntu.com/ubuntu/pool/main/o/openssl1.0/libssl1.0.0_1.0.2n-1ubuntu5.13_amd64.deb"

echo "=== Copying local configuration files from repository ==="
SRC_FILES_DIR="metasploitable3/chef/cookbooks/metasploitable/files"
if [ -d "$SRC_FILES_DIR" ]; then
    cp -r "$SRC_FILES_DIR"/* "$CONFIGS_DIR"/
    echo "✓ Local files copied successfully."
else
    echo "ERROR: Source files directory not found ($SRC_FILES_DIR)."
    exit 1
fi

echo "=== Generating resolved configurations from templates ==="

# 1. Resolve knockd.conf
cat << 'EOF' > "$CONFIGS_DIR/knockd/knockd.conf"
[options]
        UseSyslog

[openFlag]
        sequence    = 9560,1080,1200
        seq_timeout = 15
        command     = /sbin/iptables -I INPUT 1 -s %IP% -p tcp --dport 8989 -j ACCEPT
        tcpflags    = syn
        cmd_timeout = 30
        stop_command = /sbin/iptables -D INPUT -s %IP% -p tcp --dport 8989 -j ACCEPT

[closeFlag]
        sequence    = 1200,1080,9560
        seq_timeout = 15
        command     = /sbin/iptables -D INPUT -s %IP% -p tcp --dport 8989 -j ACCEPT
        tcpflags    = syn
EOF
echo "✓ configs/knockd/knockd.conf file generated."

# 2. Resolve payroll.sql
cat << 'EOF' > "$CONFIGS_DIR/payroll_app/payroll.sql"
-- phpMyAdmin SQL Dump
-- version 3.5.8
-- http://www.phpmyadmin.net
-- Host: 127.0.0.1
-- PHP Version: 5.4.5

SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

DROP DATABASE IF EXISTS `payroll`;
CREATE DATABASE `payroll`;
USE `payroll`;

DROP TABLE IF EXISTS `users`;

CREATE TABLE `users` (
  `username` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `first_name` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `last_name` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `salary` int(20) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `users` (`username`, `first_name`, `last_name`, `password`, `salary`) VALUES
('leia_organa', 'Leia', 'Organa', 'help_me_obiwan', 9560),
('luke_skywalker', 'Luke', 'Skywalker', 'like_my_father_beforeme', 1080),
('han_solo', 'Han', 'Solo', 'nerf_herder', 1200),
('artoo_detoo', 'Artoo', 'Detoo', 'b00p_b33p', 22222),
('c_three_pio', 'C', 'Threepio', 'Pr0t0c07', 3200),
('ben_kenobi', 'Ben', 'Kenobi', 'thats_no_m00n', 10000),
('darth_vader', 'Darth', 'Vader', 'Dark_syD3', 6666),
('anakin_skywalker', 'Anakin', 'Skywalker', 'but_master:(', 1025),
('jarjar_binks', 'Jar-Jar', 'Binks', 'mesah_p@ssw0rd', 2048),
('lando_calrissian', 'Lando', 'Calrissian', '@dm1n1str8r', 40000),
('boba_fett', 'Boba', 'Fett', 'mandalorian1', 20000),
('jabba_hutt', 'Jaba', 'Hutt', 'my_kinda_skum', 65000),
('greedo', 'Greedo', 'Rodian', 'hanSh0tF1rst', 50000),
('chewbacca', 'Chewbacca', '', 'rwaaaaawr8', 4500),
('kylo_ren', 'Kylo', 'Ren', 'Daddy_Issues2', 6667);

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
EOF
echo "✓ configs/payroll_app/payroll.sql file generated."

# 3. Resolve start.sh for readme_app
mkdir -p "$CONFIGS_DIR/readme_app"
cat << 'EOF' > "$CONFIGS_DIR/readme_app/start.sh"
#!/bin/sh
cd /opt/readme_app
bundle install --path vendor/bundle
bundle exec rails s -b 0.0.0.0 -p 3500
EOF
chmod +x "$CONFIGS_DIR/readme_app/start.sh"
echo "✓ configs/readme_app/start.sh file generated."

# 4. Ensure sinatra directories contain the correct binary
if [ -f "$CONFIGS_DIR/sinatra/virtualbox/loader" ]; then
    cp "$CONFIGS_DIR/sinatra/virtualbox/loader" "$CONFIGS_DIR/sinatra/loader"
    echo "✓ Sinatra loader (x86_64) copied."
else
    echo "WARNING: Sinatra loader binary not found in virtualbox/"
fi

# Copy server.rb for the Sinatra service without obfuscation/loader
if [ -f "metasploitable3/resources/flags/linux_flags/6_of_clubs/server.rb" ]; then
    cp "metasploitable3/resources/flags/linux_flags/6_of_clubs/server.rb" "$CONFIGS_DIR/sinatra/server.rb"
    echo "✓ Sinatra server.rb copied from flags to configurations."
else
    echo "WARNING: 'server.rb' for sinatra not found in the metasploitable3 repository."
fi

# 5. Copy the provisioning and auditing scripts to the build directory
if [ -f "provision_arm.sh" ]; then
    cp "provision_arm.sh" "$BUILD_DIR/provision_arm.sh"
    chmod +x "$BUILD_DIR/provision_arm.sh"
    echo "✓ Provisioning script 'provision_arm.sh' copied to build directory."
else
    echo "WARNING: 'provision_arm.sh' not found in the root directory."
fi

if [ -f "audit_services.sh" ]; then
    cp "audit_services.sh" "$BUILD_DIR/audit_services.sh"
    chmod +x "$BUILD_DIR/audit_services.sh"
    echo "✓ Auditing script 'audit_services.sh' copied to build directory."
else
    echo "WARNING: 'audit_services.sh' not found in the root directory."
fi

# 6. Create an informative README file in the package
cat << 'EOF' > "$BUILD_DIR/README.txt"
Metasploitable 3 ARM (ARM64) - Offline Provisioning Kit
============================================================

This directory contains pre-downloaded resources and resolved configurations
needed to replicate Metasploitable 3 in an Ubuntu Server ARM64 VM inside UTM.

Deployment Instructions:
1. Copy this directory or the compressed archive 'metasploitable3-arm-build.tar.gz'
   to the guest Ubuntu Server ARM64 VM in UTM.
2. Extract the compressed archive in the VM if needed:
   tar -xvzf metasploitable3-arm-build.tar.gz
3. Enter the extracted directory:
   cd metasploitable3-arm-build
4. Execute the provisioning script with root privileges:
   sudo ./provision_arm.sh

Note: The VM requires temporary internet access during provisioning so apt-get
can download base tools and compilers (build-essential, mysql-server, apache2,
openjdk, samba, nodejs, etc.). The main vulnerable services (PHP 5.4.5,
UnrealIRCd, ProFTPd, Drupal) will compile and install using the pre-downloaded
local archives in the 'assets/' folder.
EOF
echo "✓ README.txt file generated."

echo "=== Creating compressed tar.gz file ==="
tar -czf metasploitable3-arm-build.tar.gz "$BUILD_DIR"
echo "✓ 'metasploitable3-arm-build.tar.gz' file successfully created."

echo "========================================================================="
echo "Preparation COMPLETED successfully."
echo "Build directory: $BUILD_DIR"
echo "Packed archive for the VM: metasploitable3-arm-build.tar.gz"
echo "========================================================================="
