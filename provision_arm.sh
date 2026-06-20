#!/bin/bash
# Metasploitable 3 provisioning script for Ubuntu ARM (ARM64).
# Must be run as root within the target virtual machine.

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run this script as root (sudo ./provision_arm.sh)"
    exit 1
fi

echo "=== STARTING METASPLOITABLE 3 PROVISIONING ON UBUNTU ARM64 ==="

# Global variables
DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND

# Local resource directories (assumes metasploitable3-arm-build folder was uploaded to /tmp)
RESOURCES_DIR="$(cd "$(dirname "$0")" && pwd)"
ASSETS_DIR="$RESOURCES_DIR/assets"
CONFIGS_DIR="$RESOURCES_DIR/configs"

echo "Resource directory detected: $RESOURCES_DIR"

# 1. Configure Multiarch Support and QEMU User Space Emulation
# This is CRITICAL to execute x86_64 binaries (sinatra/loader and five_of_diamonds)
echo "=== 1. Configuring support for x86_64 binaries (Multiarch and QEMU) ==="

# Detect native system architecture (e.g., arm64) and Ubuntu codename
native_arch=$(dpkg --print-architecture)
if command -v lsb_release >/dev/null 2>&1; then
    codename=$(lsb_release -c -s)
else
    codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
fi

echo "Native architecture detected: $native_arch, System Codename: $codename"

# Backup copy of sources.list
cp /etc/apt/sources.list /etc/apt/sources.list.bak

# Add architecture restriction to existing sources if they don't have it already
sed -i -E "s/^deb +([^\[])/deb [arch=$native_arch] \1/g" /etc/apt/sources.list
sed -i -E "s/^deb-src +([^\[])/deb-src [arch=$native_arch] \1/g" /etc/apt/sources.list

# Create specific sources file for amd64 packages pointing to the main repository
cat << EOF > /etc/apt/sources.list.d/amd64.list
deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ ${codename} main restricted universe multiverse
deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ ${codename}-updates main restricted universe multiverse
deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ ${codename}-backports main restricted universe multiverse
deb [arch=amd64] http://security.ubuntu.com/ubuntu/ ${codename}-security main restricted universe multiverse
EOF

# Add amd64 architecture and update repositories
dpkg --add-architecture amd64
apt-get update

# Install emulation and basic x86-64 libraries
apt-get install -y qemu-user-static binfmt-support libc6:amd64 libstdc++6:amd64 zlib1g:amd64
if [ -f "$ASSETS_DIR/libssl1.0.0_1.0.2n-1ubuntu5.13_amd64.deb" ]; then
    dpkg -i "$ASSETS_DIR/libssl1.0.0_1.0.2n-1ubuntu5.13_amd64.deb"
else
    echo "WARNING: Local libssl1.0.0 package not found, attempting to download from internet..."
    wget -q http://security.ubuntu.com/ubuntu/pool/main/o/openssl1.0/libssl1.0.0_1.0.2n-1ubuntu5.13_amd64.deb -O /tmp/libssl1.0.0_amd64.deb
    dpkg -i /tmp/libssl1.0.0_amd64.deb
fi


# 2. Install base prerequisite packages
echo "=== 2. Install base dependencies from APT ==="
apt-get install -y \
    build-essential gcc g++ make unzip git curl \
    mysql-server mysql-client \
    apache2 apache2-dev \
    samba \
    openjdk-11-jdk-headless \
    ruby ruby-dev bundler \
    nodejs npm \
    knockd \
    iptables \
    libxml2-dev libcurl4-openssl-dev libpcre3-dev libbz2-dev libjpeg-dev \
    libpng-dev libfreetype6-dev libmcrypt-dev libmhash-dev libxslt1-dev \
    default-libmysqlclient-dev libsqlite3-dev docker.io mlocate

    # Start and enable Docker service
    systemctl enable docker
    systemctl start docker

# 3. Create Users and Configure SSH
echo "=== 3. Creating users and weak credentials ==="
# Create the docker group if it doesn't exist
groupadd -f docker

# Structure of users to create
declare -A USERS=(
    ["leia_organa"]='$1$N6DIbGGZ$LpERCRfi8IXlNebhQuYLK/'
    ["luke_skywalker"]='$1$/7D55Ozb$Y/aKb.UNrDS2w7nZVq.Ll/'
    ["han_solo"]='$1$6jIF3qTC$7jEXfQsNENuWYeO6cK7m1.'
    ["artoo_detoo"]='$1$tfvzyRnv$mawnXAR4GgABt8rtn7Dfv.'
    ["c_three_pio"]='$1$lXx7tKuo$xuM4AxkByTUD78BaJdYdG.'
    ["ben_kenobi"]='$1$5nfRD/bA$y7ZZD0NimJTbX9FtvhHJX1'
    ["darth_vader"]='$1$rLuMkR1R$YHumHRxhswnfO7eTUUfHJ.'
    ["anakin_skywalker"]='$1$jlpeszLc$PW4IPiuLTwiSH5YaTlRaB0'
    ["jarjar_binks"]='$1$SNokFi0c$F.SvjZQjYRSuoBuobRWMh1'
    ["lando_calrissian"]='$1$Af1ek3xT$nKc8jkJ30gMQWeW/6.ono0'
    ["boba_fett"]='$1$TjxlmV4j$k/rG1vb4.pj.z0yFWJ.ZD0'
    ["jabba_hutt"]='$1$9rpNcs3v$//v2ltj5MYhfUOHYVAzjD/'
    ["greedo"]='$1$vOU.f3Tj$tsgBZJbBS4JwtchsRUW0a1'
    ["chewbacca"]='$1$.qt4t8zH$RdKbdafuqc7rYiDXSoQCI.'
    ["kylo_ren"]='$1$rpvxsssI$hOBC/qL92d0GgmD/uSELx.'
)

uid=1111
for user in "${!USERS[@]}"; do
    hash="${USERS[$user]}"
    if id "$user" &>/dev/null; then
        echo "User $user already exists."
    else
        useradd -m -s /bin/bash -p "$hash" -g 100 -u "$uid" "$user"
        echo "User $user (UID $uid) created."
    fi
    uid=$((uid + 1))
done

# Administrators in sudo group
usermod -aG sudo leia_organa
usermod -aG sudo luke_skywalker
usermod -aG sudo han_solo

# Users in docker group
usermod -aG docker boba_fett
usermod -aG docker jabba_hutt
usermod -aG docker greedo
usermod -aG docker chewbacca

# Weak SSH key for lateral movement
echo "Generating insecure SSH key pair for testing..."
mkdir -p /home/boba_fett/.ssh
rm -f /home/boba_fett/.ssh/id_rsa /home/boba_fett/.ssh/id_rsa.pub
ssh-keygen -t rsa -N "" -f /home/boba_fett/.ssh/id_rsa -q
chown -R boba_fett:users /home/boba_fett/.ssh
chmod 700 /home/boba_fett/.ssh
chmod 600 /home/boba_fett/.ssh/id_rsa

# Configure authorized_keys for all users with boba_fett's public key
for user in "${!USERS[@]}"; do
    homedir="/home/$user"
    mkdir -p "$homedir/.ssh"
    cp /home/boba_fett/.ssh/id_rsa.pub "$homedir/.ssh/authorized_keys"
    chown -R "$user:users" "$homedir/.ssh"
    chmod 700 "$homedir/.ssh"
    chmod 600 "$homedir/.ssh/authorized_keys"
done

# Configure sshd
if [ -f "$CONFIGS_DIR/sshd/sshd_config" ]; then
    cp "$CONFIGS_DIR/sshd/sshd_config" /etc/ssh/sshd_config
    systemctl restart ssh || systemctl restart sshd
    echo "✓ SSH configured insecurely."
fi

# 4. Configure MySQL
echo "=== 4. Configuring MySQL database ==="
# Ensure MySQL is started
systemctl start mysql
# Allow remote connections
sed -i 's/bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf || true
# Change MySQL root password to sploitme in an idempotent way
if mysql -u root -psploitme -e "SELECT 1" &>/dev/null; then
    echo "✓ MySQL root password is already set to 'sploitme'."
else
    mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'sploitme'; FLUSH PRIVILEGES;" || \
    mysql -u root -psploitme -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'sploitme'; FLUSH PRIVILEGES;"
fi
systemctl restart mysql
echo "✓ MySQL started and configured with password 'sploitme'."

# 5. Configure Apache HTTPD
echo "=== 5. Configuring Apache Web Server ==="
mkdir -p /var/www/cgi-bin
mkdir -p /var/www/uploads
chmod 777 /var/www/uploads
cp "$CONFIGS_DIR/apache/hello_world.sh" /var/www/cgi-bin/hello_world.sh
chmod 755 /var/www/cgi-bin/hello_world.sh
cp "$CONFIGS_DIR/apache/cgi-bin.conf" /etc/apache2/conf-available/cgi-bin.conf
cp "$CONFIGS_DIR/apache/dav.conf" /etc/apache2/conf-available/dav.conf

# Enable CGI and WebDAV
a2enmod cgi dav dav_fs dav_lock auth_digest
a2enconf cgi-bin dav
a2disconf serve-cgi-bin || true
chmod o+w /var/www/html
rm -f /var/www/html/index.html
systemctl restart apache2
echo "✓ Apache HTTPD configured with CGI and WebDAV."

# 6. Compile and Install PHP 5.4.5 (Native ARM64)
echo "=== 6. Compiling PHP 5.4.5 from source (natively for ARM64) ==="
if [ -f /usr/local/bin/php ] || apache2ctl -M | grep -q php5; then
    echo "✓ PHP 5.4.5 is already installed, skipping compilation."
else
    cd /tmp
    tar -xvzf "$ASSETS_DIR/php-5.4.5.tar.gz"
    cd php-5.4.5
    
    # Update config.guess and config.sub for ARM64 (aarch64) support
    find . -name "config.guess" -exec cp -f /usr/share/misc/config.guess {} \;
    find . -name "config.sub" -exec cp -f /usr/share/misc/config.sub {} \;
    
    # Apply libxml2 compatibility patch
    patch -p0 -b < "$ASSETS_DIR/libxml29_compat.patch"
    
    # Fix freetype header bug
    mkdir -pv /usr/include/freetype2/freetype && ln -sf /usr/include/freetype2/freetype.h /usr/include/freetype2/freetype/freetype.h || true
    
    # Configure and compile natively
    ./configure \
        --with-apxs2=/usr/bin/apxs \
        --with-mysqli \
        --enable-embedded-mysqli \
        --with-gd \
        --with-mcrypt \
        --enable-mbstring \
        --with-pdo-mysql \
        --with-libxml-dir \
        --with-xsl
    
    make -j$(nproc)
    make install
    
    # Copy apache configuration for PHP5
    cp "$CONFIGS_DIR/apache/php5.conf" /etc/apache2/mods-available/php5.conf
    cp "$CONFIGS_DIR/apache/php5.load" /etc/apache2/mods-available/php5.load
    
    # Enable module in Apache
    a2enmod php5
    a2dismod mpm_event || true
    a2enmod mpm_prefork || true
    systemctl restart apache2
    echo "✓ PHP 5.4.5 compiled and installed successfully."
fi

# 7. Install phpMyAdmin
echo "=== 7. Deploying phpMyAdmin ==="
if [ -d /var/www/html/phpmyadmin ]; then
    echo "✓ phpMyAdmin already installed."
else
    tar -xvzf "$ASSETS_DIR/phpMyAdmin-3.5.8-all-languages.tar.gz" -C /var/www/html
    mv /var/www/html/phpMyAdmin-3.5.8-all-languages /var/www/html/phpmyadmin
    cp "$CONFIGS_DIR/phpmyadmin/config.inc.php" /var/www/html/phpmyadmin/config.inc.php
    systemctl restart apache2
    echo "✓ phpMyAdmin deployed."
fi

# 8. Compile and Install ProFTPd 1.3.5 (Native ARM64)
echo "=== 8. Compiling and installing ProFTPd 1.3.5 with mod_copy ==="
if [ -f /opt/proftpd/sbin/proftpd ]; then
    echo "✓ ProFTPd already installed."
else
    cd /tmp
    tar -xvzf "$ASSETS_DIR/proftpd-1.3.5.tar.gz"
    cd proftpd-1.3.5
    
    # Update config.guess and config.sub for ARM64 (aarch64) support
    find . -name "config.guess" -exec cp -f /usr/share/misc/config.guess {} \;
    find . -name "config.sub" -exec cp -f /usr/share/misc/config.sub {} \;
    
    ./configure --prefix=/opt/proftpd --with-modules=mod_copy
    make -j$(nproc)
    make install
    
    # Init service
    cp "$CONFIGS_DIR/proftpd/proftpd" /etc/init.d/proftpd
    sed -i -e 's/\r//g' /etc/init.d/proftpd
    chmod +x /etc/init.d/proftpd
    
    # Copy renewal scripts
    cp "$CONFIGS_DIR/proftpd/proftpd_ip_renewer.rb" /opt/proftpd/proftpd_ip_renewer.rb
    cp "$CONFIGS_DIR/proftpd/hosts_renewer.rb" /opt/proftpd/hosts_renewer.rb
    chmod +x /opt/proftpd/*.rb
    
    # Write modern Systemd service files
    cat << 'EOF' > /etc/systemd/system/proftpd.service
[Unit]
Description=ProFTPD Vulnerable Server
After=network.target

[Service]
Type=forking
ExecStart=/etc/init.d/proftpd start
ExecStop=/etc/init.d/proftpd stop
PIDFile=/opt/proftpd/var/proftpd.pid
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    cat << 'EOF' > /etc/systemd/system/proftpd_ip_renewer.service
[Unit]
Description=ProFTPD IP Renewer
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/ruby /opt/proftpd/proftpd_ip_renewer.rb
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    cat << 'EOF' > /etc/systemd/system/hosts_renewer.service
[Unit]
Description=Hosts Renewer
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/ruby /opt/proftpd/hosts_renewer.rb
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable proftpd proftpd_ip_renewer hosts_renewer
    systemctl start proftpd proftpd_ip_renewer hosts_renewer
    echo "✓ ProFTPd 1.3.5 configured and running."
fi

# 9. Compile and Install UnrealIRCd 3.2.8.1 Backdoored (Native ARM64)
echo "=== 9. Compiling and installing UnrealIRCd 3.2.8.1 (Backdoored) ==="
if [ -f /opt/unrealircd/Unreal3.2/unreal ]; then
    echo "✓ UnrealIRCd already installed."
else
    mkdir -p /opt/unrealircd
    cd /opt/unrealircd
    tar -xvzf "$ASSETS_DIR/Unreal3.2.8.1_backdoor.tar.gz"
    
    # Copy configurations
    cp "$CONFIGS_DIR/unrealircd/unrealircd.conf" /opt/unrealircd/Unreal3.2/unrealircd.conf
    cp "$CONFIGS_DIR/unrealircd/ircd.motd" /opt/unrealircd/Unreal3.2/ircd.motd
    
    # Pre-extract and patch architecture support for internal libraries in extras/ (TRE regex and c-ares)
    echo "Patching internal libraries (TRE and c-ares) of UnrealIRCd..."
    cd /opt/unrealircd/Unreal3.2/extras
    for pkg in tre.tar.gz c-ares.tar.gz; do
        if [ -f "$pkg" ]; then
            if [ "$pkg" = "tre.tar.gz" ]; then
                dir_name="tre-0.7.5"
            else
                dir_name="c-ares-1.6.0"
            fi
            echo "Patching $pkg (directory: $dir_name)..."
            tar -xvzf "$pkg"
            find "$dir_name" -name "config.guess" -exec cp -f /usr/share/misc/config.guess {} \;
            find "$dir_name" -name "config.sub" -exec cp -f /usr/share/misc/config.sub {} \;
            rm -f "$pkg"
            tar -czf "$pkg" "$dir_name"
            rm -rf "$dir_name"
        fi
    done
    
    # Compile
    cd /opt/unrealircd/Unreal3.2
    
    # Update config.guess and config.sub for ARM64 (aarch64) support in main UnrealIRCd directory
    find . -name "config.guess" -exec cp -f /usr/share/misc/config.guess {} \;
    find . -name "config.sub" -exec cp -f /usr/share/misc/config.sub {} \;
    
    # Old C code of UnrealIRCd requires -fcommon and -fgnu89-inline on modern compilers to avoid duplicate symbol errors and undefined inline function errors
    export CFLAGS="-fcommon -fgnu89-inline"
    ./configure \
        --with-showlistmodes \
        --enable-hub \
        --enable-prefixaq \
        --with-listen=5 \
        --with-dpath=/opt/unrealircd/Unreal3.2 \
        --with-spath=/opt/unrealircd/Unreal3.2/src/ircd \
        --with-nick-history=2000 \
        --with-sendq=3000000 \
        --with-bufferpool=18 \
        --with-hostname=metasploitableub \
        --with-permissions=0600 \
        --with-fd-setsize=1024 \
        --enable-dynamic-linking
    
    make
    
    # Adjust permissions for boba_fett
    chown -R boba_fett:users /opt/unrealircd
    
    # Create Systemd service
    cat << 'EOF' > /etc/systemd/system/unrealircd.service
[Unit]
Description=UnrealIRCd Backdoored Daemon
After=network.target

[Service]
Type=forking
User=boba_fett
WorkingDirectory=/opt/unrealircd/Unreal3.2
ExecStart=/opt/unrealircd/Unreal3.2/unreal start
ExecStop=/opt/unrealircd/Unreal3.2/unreal stop
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable unrealircd
    systemctl start unrealircd
    echo "✓ UnrealIRCd started as boba_fett."
fi

# 10. Install Apache Continuum 1.4.2
echo "=== 10. Installing Apache Continuum 1.4.2 ==="
if [ -d /opt/apache_continuum/apache-continuum-1.4.2 ]; then
    echo "✓ Apache Continuum is already installed."
else
    mkdir -p /opt/apache_continuum
    tar -xvzf "$ASSETS_DIR/apache-continuum-1.4.2-bin.tar.gz" -C /opt/apache_continuum
    
    # Create symbolic link so the Tanuki Wrapper (x86_64) runs via QEMU on ARM64
    ln -s wrapper-linux-x86-64 /opt/apache_continuum/apache-continuum-1.4.2/bin/wrapper-linux-aarch64-64
    
    # Inject pre-configured files (contains vulnerability/user)
    rm -rf /opt/apache_continuum/apache-continuum-1.4.2/data
    tar -xvzf "$CONFIGS_DIR/apache_continuum/data.tar.gz" -C /opt/apache_continuum/apache-continuum-1.4.2/
    
    # Write Systemd service
    cat << 'EOF' > /etc/systemd/system/continuum.service
[Unit]
Description=Apache Continuum vulnerable server
After=network.target

[Service]
Type=forking
ExecStart=/opt/apache_continuum/apache-continuum-1.4.2/bin/continuum start
ExecStop=/opt/apache_continuum/apache-continuum-1.4.2/bin/continuum stop
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable continuum
    systemctl start continuum
    echo "✓ Apache Continuum configured and started."
fi

# 11. Deploy Drupal 7.5
echo "=== 11. Deploying Drupal 7.5 ==="
if [ -d /var/www/html/drupal ] && mysql -u root -psploitme -e "SHOW DATABASES LIKE 'drupal';" | grep -q drupal; then
    echo "✓ Drupal already installed and database configured."
else
    rm -rf /var/www/html/drupal
    mkdir -p /var/www/html/drupal
    tar -xvzf "$ASSETS_DIR/drupal-7.5.tar.gz" -C /var/www/html/drupal --strip-components 1
    
    # Vulnerable Coder module
    mkdir -p /var/www/html/drupal/sites/all/modules
    tar -xvzf "$ASSETS_DIR/coder-7.x-2.5.tar.gz" -C /var/www/html/drupal/sites/all/modules
    
    # Default site and database
    tar -xvzf "$CONFIGS_DIR/drupal/default_site.tar.gz" -C /var/www/html/drupal/sites/
    chown -R www-data:www-data /var/www/html/drupal
    
    # Inject database
    mysql -u root -psploitme -e "CREATE DATABASE IF NOT EXISTS drupal;"
    # In MySQL 8, the user must be created first, then privileges granted separately (without IDENTIFIED BY in GRANT)
    mysql -u root -psploitme -e "CREATE USER IF NOT EXISTS 'root'@'localhost' IDENTIFIED BY 'sploitme';" || true
    mysql -u root -psploitme -e "GRANT SELECT, INSERT, DELETE, CREATE, DROP, INDEX, ALTER ON drupal.* TO 'root'@'localhost';"
    mysql -u root -psploitme drupal < "$CONFIGS_DIR/drupal/drupal.sql"
    echo "✓ Drupal database initialized."
fi

# 12. Deploy Payroll App
echo "=== 12. Configuring Payroll App ==="
cp "$CONFIGS_DIR/payroll_app/payroll_app.php" /var/www/html/payroll_app.php
chmod 755 /var/www/html/payroll_app.php

poc_dir="/home/kylo_ren/poc/payroll_app"
mkdir -p "$poc_dir"
cp "$CONFIGS_DIR/payroll_app/poc.rb" "$poc_dir/poc.rb"
chmod 755 "$poc_dir/poc.rb"
chown -R kylo_ren:users /home/kylo_ren/poc

# Inject Payroll DB
mysql -u root -psploitme < "$CONFIGS_DIR/payroll_app/payroll.sql"
echo "✓ Payroll App deployed and database injected."

# 13. Deploy Readme App (Rails)
echo "=== 13. Deploying Readme App ==="
if [ -f /etc/systemd/system/readme_app.service ]; then
    echo "✓ Readme App already installed."
else
    rm -rf /opt/readme_app
    mkdir -p /opt/readme_app
    tar -xvzf "$ASSETS_DIR/metasploitable3-readme.tar.gz" -C /opt/readme_app --strip-components 1
    
    # Apply BigDecimal.new and Fixnum/Bignum patch for Ruby 2.7
    cat << 'EOF' > /tmp/boot_patch.rb
require 'bigdecimal'
unless BigDecimal.respond_to?(:new)
  def BigDecimal.new(*args, **kwargs)
    BigDecimal(*args, **kwargs)
  end
end
if defined?(Fixnum) && Fixnum == Integer
  Object.send(:remove_const, :Fixnum)
  class Fixnum < Integer; end
end
if defined?(Bignum) && Bignum == Integer
  Object.send(:remove_const, :Bignum)
  class Bignum < Integer; end
end
EOF
    cat /opt/readme_app/config/boot.rb >> /tmp/boot_patch.rb
    mv /tmp/boot_patch.rb /opt/readme_app/config/boot.rb

    cp "$CONFIGS_DIR/readme_app/start.sh" /opt/readme_app/start.sh
    chmod 755 /opt/readme_app/start.sh
    
    # Install ruby dependencies
    cd /opt/readme_app
    # Avoid interactive installation
    bundle config set --local path 'vendor/bundle'
    # Ensure SQLite3 headers are installed
    apt-get install -y libsqlite3-dev
    
    # Create temporary gcc/g++ wrappers to force -Wno-error at the end of compilation commands
    # This is necessary because some gems (like byebug) have -Werror hardcoded in their extconf.rb
    cat << 'EOF' > /tmp/gcc-wrapper
#!/bin/bash
exec /usr/bin/gcc "$@" -Wno-error -Wno-error=incompatible-pointer-types
EOF
    cat << 'EOF' > /tmp/g++-wrapper
#!/bin/bash
exec /usr/bin/g++ "$@" -Wno-error -Wno-error=incompatible-pointer-types
EOF
    chmod +x /tmp/gcc-wrapper /tmp/g++-wrapper

    # Pre-install native gems with correct CFLAGS for Ruby 2.7 and avoid warning errors
    CC=/tmp/gcc-wrapper CXX=/tmp/g++-wrapper gem install json -v '1.8.3' --install-dir vendor/bundle/ruby/2.7.0 -- --with-cflags="-Drb_cFixnum=rb_cInteger -Drb_cBignum=rb_cInteger"
    CC=/tmp/gcc-wrapper CXX=/tmp/g++-wrapper gem install byebug -v '8.2.2' --install-dir vendor/bundle/ruby/2.7.0
    CC=/tmp/gcc-wrapper CXX=/tmp/g++-wrapper gem install sqlite3 -v '1.3.11' --install-dir vendor/bundle/ruby/2.7.0 -- --with-cflags="-Drb_cFixnum=rb_cInteger -Drb_cBignum=rb_cInteger"

    rm -f /tmp/gcc-wrapper /tmp/g++-wrapper
    
    bundle install
    
    chown -R chewbacca:users /opt/readme_app
    
    # Systemd Service
    cat << 'EOF' > /etc/systemd/system/readme_app.service
[Unit]
Description=Run ReadMe Rails App
After=network.target

[Service]
Type=simple
User=chewbacca
WorkingDirectory=/opt/readme_app
ExecStart=/opt/readme_app/start.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable readme_app
    systemctl start readme_app
    echo "✓ Readme App configured as a service."
fi

# 14. Deploy Sinatra App (Executed via Ruby to avoid signature issues with /etc/passwd)
echo "=== 14. Deploying Sinatra App (Bypassing loader) ==="
if [ -f /opt/sinatra/server.rb ]; then
    echo "✓ Sinatra already installed."
else
    mkdir -p /opt/sinatra /var/opt/sinatra
    chmod 777 /opt/sinatra /var/opt/sinatra
    
    cp "$CONFIGS_DIR/sinatra/Gemfile" /opt/sinatra/Gemfile
    cp "$CONFIGS_DIR/sinatra/server.rb" /opt/sinatra/server.rb
    chmod 755 /opt/sinatra/server.rb
    
    # Install ruby dependencies for sinatra
    cd /opt/sinatra
    bundle install || true
    
    # Systemd Service
    cat << 'EOF' > /etc/systemd/system/sinatra.service
[Unit]
Description=Run vulnerable Sinatra (Ruby)
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/sinatra
ExecStart=/usr/bin/ruby /opt/sinatra/server.rb
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable sinatra
    systemctl start sinatra
    echo "✓ Sinatra App deployed on port 8181."
fi

# 15. Deploy Chatbot Nodejs
echo "=== 15. Deploying Chatbot Node.js ==="
if [ -d /opt/chatbot ] && [ -f /etc/systemd/system/chatbot.service ]; then
    echo "✓ Chatbot already installed."
else
    rm -rf /opt/chatbot
    unzip -o "$CONFIGS_DIR/chatbot/chatbot.zip" -d /opt
    chown -R root:root /opt/chatbot
    chmod -R 700 /opt/chatbot
    # No need to run npm install as chatbot.zip includes full node_modules with express and cors
    
    # Run installation script (creates chatbot.conf)
    # Since install.sh assumes Upstart, we will create the Systemd service directly
    # Ensure execution permissions for shell scripts
    chmod +x /opt/chatbot/*.sh
    
    cat << 'EOF' > /etc/systemd/system/chatbot.service
[Unit]
Description=Run Chatbot Node.js Server
After=network.target

[Service]
Type=forking
WorkingDirectory=/opt/chatbot
ExecStart=/opt/chatbot/start.sh
ExecStop=/opt/chatbot/stop.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable chatbot
    systemctl start chatbot
    echo "✓ Chatbot Node.js running."
fi

# 16. Configure Samba
echo "=== 16. Configuring Samba resources ==="
cp "$CONFIGS_DIR/samba/smb.conf" /etc/samba/smb.conf
# Copy pre-generated Samba passwords database
cp "$CONFIGS_DIR/samba/passdb.tdb" /var/lib/samba/private/passdb.tdb
chmod 600 /var/lib/samba/private/passdb.tdb
systemctl restart smbd nmbd
echo "✓ Samba configured and started."

# 17. Configure Knockd
echo "=== 17. Configuring Knockd (Port Knocking) ==="
cp "$CONFIGS_DIR/knockd/knockd.conf" /etc/knockd.conf
cp "$CONFIGS_DIR/knockd/knockd" /etc/default/knockd

# Dynamically detect the active network interface and configure it in /etc/default/knockd
default_interface=$(ip route | grep '^default' | awk '{print $5}' | head -n1)
if [ -z "$default_interface" ]; then
    default_interface=$(ip -o link show | awk -F': ' '$2 != "lo" && $2 !~ "^docker" && $2 !~ "^veth" {print $2; exit}')
fi
if [ -n "$default_interface" ]; then
    echo "Network interface detected for knockd: $default_interface"
    sed -i "s/#KNOCKD_OPTS=.*/KNOCKD_OPTS=\"-i $default_interface\"/" /etc/default/knockd
fi

systemctl daemon-reload
systemctl enable knockd
systemctl restart knockd
echo "✓ Knockd enabled and configured on port 8989."

# 18. Deploy Flags (CTF)
echo "=== 18. Distributing CTF Flags (Cards) ==="

# 10 of Clubs (Wav file)
mkdir -p /home/artoo_detoo/music
cp "$CONFIGS_DIR/flags/10_of_clubs.wav" /home/artoo_detoo/music/10_of_clubs.wav
chown -R artoo_detoo:users /home/artoo_detoo/music
chmod 410 /home/artoo_detoo/music/10_of_clubs.wav

# 10 of Spades
cp "$CONFIGS_DIR/flags/flag_images/10 of spades.png" /opt/readme_app/public/images/10_of_spades.png || true
chmod 644 /opt/readme_app/public/images/10_of_spades.png || true

# 8 of Clubs (Random recursive directory)
prev_dirs=""
# Fixed paths based on chef recipe
for d in 42 17 88 5 99 23 71 12 3 55 60 74 9 33 21 8 47 11 92 80; do
    prev_dirs="$prev_dirs/$d"
    mkdir -p "/home/anakin_skywalker$prev_dirs"
    chown anakin_skywalker:users "/home/anakin_skywalker$prev_dirs"
    chmod 770 "/home/anakin_skywalker$prev_dirs"
done
cp "$CONFIGS_DIR/flags/flag_images/8 of clubs.png" "/home/anakin_skywalker$prev_dirs/8_of_clubs.png"
chown anakin_skywalker:users "/home/anakin_skywalker$prev_dirs/8_of_clubs.png"
chmod 644 "/home/anakin_skywalker$prev_dirs/8_of_clubs.png"

# 3 of Hearts
mkdir -p /lost+found
cp "$CONFIGS_DIR/flags/flag_images/3 of hearts.png" /lost+found/3_of_hearts.png
chmod 600 /lost+found/3_of_hearts.png

# 9 of Diamonds
mkdir -p /home/kylo_ren/.secret_files
cp "$CONFIGS_DIR/flags/my_recordings_do_not_open.iso" /home/kylo_ren/.secret_files/my_recordings_do_not_open.iso
chown -R kylo_ren:users /home/kylo_ren/.secret_files
chmod 610 /home/kylo_ren/.secret_files/my_recordings_do_not_open.iso
updatedb || true

# 5 of Diamonds (x86_64 service running on port 8989 via QEMU emulation)
mkdir -p /opt/knock_knock
cp "$CONFIGS_DIR/flags/five_of_diamonds" /opt/knock_knock/five_of_diamonds
chmod 755 /opt/knock_knock/five_of_diamonds
# Create Systemd service for five of diamonds
cat << 'EOF' > /etc/systemd/system/five_of_diamonds.service
[Unit]
Description=Run vulnerable custom http on 8989 (x86_64 via QEMU)
After=network.target

[Service]
Type=simple
ExecStart=/opt/knock_knock/five_of_diamonds
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable five_of_diamonds
systemctl start five_of_diamonds

# 2 of Spades
cp "$CONFIGS_DIR/flags/2_of_spades.pcapng" /home/leia_organa/2_of_spades.pcapng
chown leia_organa:users /home/leia_organa/2_of_spades.pcapng
chmod 600 /home/leia_organa/2_of_spades.pcapng

# 8 of Hearts (Secret MySQL database)
mysql -u root -psploitme -e "CREATE DATABASE IF NOT EXISTS super_secret_db;"
mysql -u root -psploitme -e "CREATE USER IF NOT EXISTS 'root'@'localhost' IDENTIFIED BY 'sploitme';" || true
mysql -u root -psploitme -e "GRANT ALL PRIVILEGES ON super_secret_db.* TO 'root'@'localhost';"
mysql -u root -psploitme super_secret_db < "$CONFIGS_DIR/flags/super_secret_db.sql"

# Joker - Red
cp "$CONFIGS_DIR/flags/joker.png" /etc/joker.png
chmod 600 /etc/joker.png

# 7 of Diamonds (In Docker container)
echo "Configuring Docker container for the 7 of diamonds flag..."
if systemctl is-active --quiet docker; then
    mkdir -p /opt/docker
    cp "$CONFIGS_DIR/flags/Dockerfile" /opt/docker/Dockerfile
    cp "$CONFIGS_DIR/flags/7_of_diamonds.zip" /opt/docker/7_of_diamonds.zip
    
    cd /opt/docker
    docker build -t 7_of_diamonds . || true
    docker run -d --name 7_of_diamonds --restart always -t -i 7_of_diamonds || true
    rm -f /opt/docker/7_of_diamonds.zip
    echo "✓ Docker container 7_of_diamonds deployed."
else
    echo "WARNING: Docker is not active. Skipped 7_of_diamonds container creation."
fi

# 19. Apply Firewall rules
echo "=== 19. Configuring firewall rules (iptables) ==="
# Clear previous rules
iptables -F
iptables -X

# Allow local loopback traffic
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established/related connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow ping (ICMP)
iptables -A INPUT -p icmp -j ACCEPT

# Allow specific Metasploitable ports
iptables -A INPUT -p tcp --dport 22 -j ACCEPT    # SSH
iptables -A INPUT -p tcp --dport 21 -j ACCEPT    # FTP (ProFTPD)
iptables -A INPUT -p tcp --dport 80 -j ACCEPT    # HTTP (Apache y Chatbot UI)
iptables -A INPUT -p tcp --dport 445 -j ACCEPT   # Samba
iptables -A INPUT -p tcp --dport 6697 -j ACCEPT  # IRC (UnrealIRCd)
iptables -A INPUT -p tcp --dport 8080 -j ACCEPT  # Continuum
iptables -A INPUT -p tcp --dport 3000 -j ACCEPT  # Chatbot NodeJS
iptables -A INPUT -p tcp --dport 3500 -j ACCEPT  # Readme App
iptables -A INPUT -p tcp --dport 8181 -j ACCEPT  # Sinatra
iptables -A INPUT -p tcp --dport 631 -j ACCEPT   # CUPS

# Knockd blocks port 8989 by default (opened via knocking)
iptables -A INPUT -p tcp --dport 8989 -j DROP

# Deny rest of incoming traffic
iptables -P INPUT DROP

# Save rules
if command -v iptables-save &>/dev/null; then
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4
fi

echo "=== PROVISIONING COMPLETED SUCCESSFULLY ==="
echo "The Metasploitable 3 ARM virtual machine is ready to be used."
echo "You can check the status of the ports using: netstat -tulpn"
echo "========================================================"
