#!/bin/bash
# Script de aprovisionamiento de Metasploitable 3 para Ubuntu ARM (ARM64).
# Debe ejecutarse como root dentro de la máquina virtual de destino.

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Por favor, ejecute este script como root (sudo ./provision_arm.sh)"
    exit 1
fi

echo "=== INICIANDO APROVISIONAMIENTO DE METASPLOITABLE 3 EN UBUNTU ARM64 ==="

# Variables globales
DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND

# Directorios de recursos locales (se asume que se subió la carpeta metasploitable3-arm-build a /tmp)
RESOURCES_DIR="$(cd "$(dirname "$0")" && pwd)"
ASSETS_DIR="$RESOURCES_DIR/assets"
CONFIGS_DIR="$RESOURCES_DIR/configs"

echo "Directorio de recursos detectado: $RESOURCES_DIR"

# 1. Configurar Soporte Multiarch y Emulación QEMU User Space
# Esto es CRÍTICO para ejecutar los binarios x86_64 (sinatra/loader y five_of_diamonds)
echo "=== 1. Configurando soporte para binarios x86_64 (Multiarch y QEMU) ==="

# Detectar la arquitectura nativa del sistema (ej. arm64) y el codename de Ubuntu
native_arch=$(dpkg --print-architecture)
if command -v lsb_release >/dev/null 2>&1; then
    codename=$(lsb_release -c -s)
else
    codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
fi

echo "Arquitectura nativa detectada: $native_arch, Codename del sistema: $codename"

# Copia de respaldo de sources.list
cp /etc/apt/sources.list /etc/apt/sources.list.bak

# Añadir restricción de arquitectura a las fuentes existentes si no la tienen ya
sed -i -E "s/^deb +([^\[])/deb [arch=$native_arch] \1/g" /etc/apt/sources.list
sed -i -E "s/^deb-src +([^\[])/deb-src [arch=$native_arch] \1/g" /etc/apt/sources.list

# Crear archivo de fuentes específico para paquetes amd64 apuntando al repositorio principal
cat << EOF > /etc/apt/sources.list.d/amd64.list
deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ ${codename} main restricted universe multiverse
deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ ${codename}-updates main restricted universe multiverse
deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ ${codename}-backports main restricted universe multiverse
deb [arch=amd64] http://security.ubuntu.com/ubuntu/ ${codename}-security main restricted universe multiverse
EOF

# Añadir la arquitectura amd64 y actualizar repositorios
dpkg --add-architecture amd64
apt-get update

# Instalar emulación y librerías básicas x86-64
apt-get install -y qemu-user-static binfmt-support libc6:amd64 libstdc++6:amd64 zlib1g:amd64
if [ -f "$ASSETS_DIR/libssl1.0.0_1.0.2n-1ubuntu5.13_amd64.deb" ]; then
    dpkg -i "$ASSETS_DIR/libssl1.0.0_1.0.2n-1ubuntu5.13_amd64.deb"
else
    echo "WARNING: No se encontró el paquete local de libssl1.0.0, intentando descargar de internet..."
    wget -q http://security.ubuntu.com/ubuntu/pool/main/o/openssl1.0/libssl1.0.0_1.0.2n-1ubuntu5.13_amd64.deb -O /tmp/libssl1.0.0_amd64.deb
    dpkg -i /tmp/libssl1.0.0_amd64.deb
fi


# 2. Instalar paquetes de prerrequisitos base
echo "=== 2. Instalar dependencias base desde APT ==="
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

    # Iniciar y habilitar servicio Docker
    systemctl enable docker
    systemctl start docker

# 3. Crear Usuarios y Configurar SSH
echo "=== 3. Creando usuarios y credenciales débiles ==="
# Creamos el grupo docker por si no existe
groupadd -f docker

# Estructura de usuarios a crear
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
        echo "Usuario $user ya existe."
    else
        useradd -m -s /bin/bash -p "$hash" -g 100 -u "$uid" "$user"
        echo "Usuario $user (UID $uid) creado."
    fi
    uid=$((uid + 1))
done

# Administradores en grupo sudo
usermod -aG sudo leia_organa
usermod -aG sudo luke_skywalker
usermod -aG sudo han_solo

# Usuarios en grupo docker
usermod -aG docker boba_fett
usermod -aG docker jabba_hutt
usermod -aG docker greedo
usermod -aG docker chewbacca

# SSH key débil para lateralización
echo "Generando par de llaves SSH inseguro para pruebas..."
mkdir -p /home/boba_fett/.ssh
rm -f /home/boba_fett/.ssh/id_rsa /home/boba_fett/.ssh/id_rsa.pub
ssh-keygen -t rsa -N "" -f /home/boba_fett/.ssh/id_rsa -q
chown -R boba_fett:users /home/boba_fett/.ssh
chmod 700 /home/boba_fett/.ssh
chmod 600 /home/boba_fett/.ssh/id_rsa

# Configurar authorized_keys para todos los usuarios con la llave pública de boba_fett
for user in "${!USERS[@]}"; do
    homedir="/home/$user"
    mkdir -p "$homedir/.ssh"
    cp /home/boba_fett/.ssh/id_rsa.pub "$homedir/.ssh/authorized_keys"
    chown -R "$user:users" "$homedir/.ssh"
    chmod 700 "$homedir/.ssh"
    chmod 600 "$homedir/.ssh/authorized_keys"
done

# Configurar sshd
if [ -f "$CONFIGS_DIR/sshd/sshd_config" ]; then
    cp "$CONFIGS_DIR/sshd/sshd_config" /etc/ssh/sshd_config
    systemctl restart ssh || systemctl restart sshd
    echo "✓ SSH configurado de manera insegura."
fi

# 4. Configurar MySQL
echo "=== 4. Configurando base de datos MySQL ==="
# Asegurar inicio de MySQL
systemctl start mysql
# Permitir conexiones remotas
sed -i 's/bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf || true
# Cambiar clave root de MySQL a sploitme de forma idempotente
if mysql -u root -psploitme -e "SELECT 1" &>/dev/null; then
    echo "✓ La contraseña de root de MySQL ya está establecida como 'sploitme'."
else
    mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'sploitme'; FLUSH PRIVILEGES;" || \
    mysql -u root -psploitme -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'sploitme'; FLUSH PRIVILEGES;"
fi
systemctl restart mysql
echo "✓ MySQL iniciado y configurado con clave 'sploitme'."

# 5. Configurar Apache HTTPD
echo "=== 5. Configurando Apache Web Server ==="
mkdir -p /var/www/cgi-bin
mkdir -p /var/www/uploads
chmod 777 /var/www/uploads
cp "$CONFIGS_DIR/apache/hello_world.sh" /var/www/cgi-bin/hello_world.sh
chmod 755 /var/www/cgi-bin/hello_world.sh
cp "$CONFIGS_DIR/apache/cgi-bin.conf" /etc/apache2/conf-available/cgi-bin.conf
cp "$CONFIGS_DIR/apache/dav.conf" /etc/apache2/conf-available/dav.conf

# Habilitar CGI y WebDAV
a2enmod cgi dav dav_fs dav_lock auth_digest
a2enconf cgi-bin dav
a2disconf serve-cgi-bin || true
chmod o+w /var/www/html
rm -f /var/www/html/index.html
systemctl restart apache2
echo "✓ Apache HTTPD configurado con CGI y WebDAV."

# 6. Compilar e Instalar PHP 5.4.5 (Nativo ARM64)
echo "=== 6. Compilando PHP 5.4.5 desde código fuente (nativamente para ARM64) ==="
if [ -f /usr/local/bin/php ] || apache2ctl -M | grep -q php5; then
    echo "✓ PHP 5.4.5 ya está instalado, omitiendo compilación."
else
    cd /tmp
    tar -xvzf "$ASSETS_DIR/php-5.4.5.tar.gz"
    cd php-5.4.5
    
    # Actualizar config.guess y config.sub para soporte ARM64 (aarch64)
    find . -name "config.guess" -exec cp -f /usr/share/misc/config.guess {} \;
    find . -name "config.sub" -exec cp -f /usr/share/misc/config.sub {} \;
    
    # Aplicar parche de compatibilidad libxml2
    patch -p0 -b < "$ASSETS_DIR/libxml29_compat.patch"
    
    # Solucionar bug de freetype en cabeceras
    mkdir -pv /usr/include/freetype2/freetype && ln -sf /usr/include/freetype2/freetype.h /usr/include/freetype2/freetype/freetype.h || true
    
    # Configurar y compilar nativamente
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
    
    # Copiar configuración de apache para PHP5
    cp "$CONFIGS_DIR/apache/php5.conf" /etc/apache2/mods-available/php5.conf
    cp "$CONFIGS_DIR/apache/php5.load" /etc/apache2/mods-available/php5.load
    
    # Habilitar módulo en Apache
    a2enmod php5
    a2dismod mpm_event || true
    a2enmod mpm_prefork || true
    systemctl restart apache2
    echo "✓ PHP 5.4.5 compilado e instalado con éxito."
fi

# 7. Instalar phpMyAdmin
echo "=== 7. Desplegando phpMyAdmin ==="
if [ -d /var/www/html/phpmyadmin ]; then
    echo "✓ phpMyAdmin ya instalado."
else
    tar -xvzf "$ASSETS_DIR/phpMyAdmin-3.5.8-all-languages.tar.gz" -C /var/www/html
    mv /var/www/html/phpMyAdmin-3.5.8-all-languages /var/www/html/phpmyadmin
    cp "$CONFIGS_DIR/phpmyadmin/config.inc.php" /var/www/html/phpmyadmin/config.inc.php
    systemctl restart apache2
    echo "✓ phpMyAdmin desplegado."
fi

# 8. Compilar e Instalar ProFTPd 1.3.5 (Nativo ARM64)
echo "=== 8. Compilando e instalando ProFTPd 1.3.5 con mod_copy ==="
if [ -f /opt/proftpd/sbin/proftpd ]; then
    echo "✓ ProFTPd ya instalado."
else
    cd /tmp
    tar -xvzf "$ASSETS_DIR/proftpd-1.3.5.tar.gz"
    cd proftpd-1.3.5
    
    # Actualizar config.guess y config.sub para soporte ARM64 (aarch64)
    find . -name "config.guess" -exec cp -f /usr/share/misc/config.guess {} \;
    find . -name "config.sub" -exec cp -f /usr/share/misc/config.sub {} \;
    
    ./configure --prefix=/opt/proftpd --with-modules=mod_copy
    make -j$(nproc)
    make install
    
    # Servicio init
    cp "$CONFIGS_DIR/proftpd/proftpd" /etc/init.d/proftpd
    sed -i -e 's/\r//g' /etc/init.d/proftpd
    chmod +x /etc/init.d/proftpd
    
    # Copiar scripts de renovación
    cp "$CONFIGS_DIR/proftpd/proftpd_ip_renewer.rb" /opt/proftpd/proftpd_ip_renewer.rb
    cp "$CONFIGS_DIR/proftpd/hosts_renewer.rb" /opt/proftpd/hosts_renewer.rb
    chmod +x /opt/proftpd/*.rb
    
    # Escribir archivos de servicio Systemd modernos
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
    echo "✓ ProFTPd 1.3.5 configurado y corriendo."
fi

# 9. Compilar e Instalar UnrealIRCd 3.2.8.1 Backdoored (Nativo ARM64)
echo "=== 9. Compilando e instalando UnrealIRCd 3.2.8.1 (Backdoored) ==="
if [ -f /opt/unrealircd/Unreal3.2/unreal ]; then
    echo "✓ UnrealIRCd ya instalado."
else
    mkdir -p /opt/unrealircd
    cd /opt/unrealircd
    tar -xvzf "$ASSETS_DIR/Unreal3.2.8.1_backdoor.tar.gz"
    
    # Copiar configuraciones
    cp "$CONFIGS_DIR/unrealircd/unrealircd.conf" /opt/unrealircd/Unreal3.2/unrealircd.conf
    cp "$CONFIGS_DIR/unrealircd/ircd.motd" /opt/unrealircd/Unreal3.2/ircd.motd
    
    # Pre-extraemos y parcheamos el soporte de arquitectura para las bibliotecas internas en extras/ (TRE regex y c-ares)
    echo "Parcheando bibliotecas internas (TRE y c-ares) de UnrealIRCd..."
    cd /opt/unrealircd/Unreal3.2/extras
    for pkg in tre.tar.gz c-ares.tar.gz; do
        if [ -f "$pkg" ]; then
            if [ "$pkg" = "tre.tar.gz" ]; then
                dir_name="tre-0.7.5"
            else
                dir_name="c-ares-1.6.0"
            fi
            echo "Parcheando $pkg (directorio: $dir_name)..."
            tar -xvzf "$pkg"
            find "$dir_name" -name "config.guess" -exec cp -f /usr/share/misc/config.guess {} \;
            find "$dir_name" -name "config.sub" -exec cp -f /usr/share/misc/config.sub {} \;
            rm -f "$pkg"
            tar -czf "$pkg" "$dir_name"
            rm -rf "$dir_name"
        fi
    done
    
    # Compilar
    cd /opt/unrealircd/Unreal3.2
    
    # Actualizar config.guess y config.sub para soporte ARM64 (aarch64) en el directorio principal de UnrealIRCd
    find . -name "config.guess" -exec cp -f /usr/share/misc/config.guess {} \;
    find . -name "config.sub" -exec cp -f /usr/share/misc/config.sub {} \;
    
    # El código antiguo de C de UnrealIRCd necesita -fcommon y -fgnu89-inline en compiladores modernos para evitar errores de símbolos duplicados y de funciones inline no definidas
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
    
    # Ajustar permisos para boba_fett
    chown -R boba_fett:users /opt/unrealircd
    
    # Crear servicio Systemd
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
    echo "✓ UnrealIRCd iniciado como boba_fett."
fi

# 10. Instalar Apache Continuum 1.4.2
echo "=== 10. Instalando Apache Continuum 1.4.2 ==="
if [ -d /opt/apache_continuum/apache-continuum-1.4.2 ]; then
    echo "✓ Apache Continuum ya está instalado."
else
    mkdir -p /opt/apache_continuum
    tar -xvzf "$ASSETS_DIR/apache-continuum-1.4.2-bin.tar.gz" -C /opt/apache_continuum
    
    # Crear enlace simbólico para que el Wrapper de Tanuki (x86_64) se ejecute vía QEMU en ARM64
    ln -s wrapper-linux-x86-64 /opt/apache_continuum/apache-continuum-1.4.2/bin/wrapper-linux-aarch64-64
    
    # Inyectar archivos pre-configurados (contienen vulnerabilidad/usuario)
    rm -rf /opt/apache_continuum/apache-continuum-1.4.2/data
    tar -xvzf "$CONFIGS_DIR/apache_continuum/data.tar.gz" -C /opt/apache_continuum/apache-continuum-1.4.2/
    
    # Escribir servicio Systemd
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
    echo "✓ Apache Continuum configurado e iniciado."
fi

# 11. Desplegar Drupal 7.5
echo "=== 11. Desplegando Drupal 7.5 ==="
if [ -d /var/www/html/drupal ] && mysql -u root -psploitme -e "SHOW DATABASES LIKE 'drupal';" | grep -q drupal; then
    echo "✓ Drupal ya instalado y base de datos configurada."
else
    rm -rf /var/www/html/drupal
    mkdir -p /var/www/html/drupal
    tar -xvzf "$ASSETS_DIR/drupal-7.5.tar.gz" -C /var/www/html/drupal --strip-components 1
    
    # Modulo Coder vulnerable
    mkdir -p /var/www/html/drupal/sites/all/modules
    tar -xvzf "$ASSETS_DIR/coder-7.x-2.5.tar.gz" -C /var/www/html/drupal/sites/all/modules
    
    # Sitio por defecto y base de datos
    tar -xvzf "$CONFIGS_DIR/drupal/default_site.tar.gz" -C /var/www/html/drupal/sites/
    chown -R www-data:www-data /var/www/html/drupal
    
    # Inyectar base de datos
    mysql -u root -psploitme -e "CREATE DATABASE IF NOT EXISTS drupal;"
    # En MySQL 8 se debe crear el usuario primero y luego otorgar privilegios por separado (sin IDENTIFIED BY en GRANT)
    mysql -u root -psploitme -e "CREATE USER IF NOT EXISTS 'root'@'localhost' IDENTIFIED BY 'sploitme';" || true
    mysql -u root -psploitme -e "GRANT SELECT, INSERT, DELETE, CREATE, DROP, INDEX, ALTER ON drupal.* TO 'root'@'localhost';"
    mysql -u root -psploitme drupal < "$CONFIGS_DIR/drupal/drupal.sql"
    echo "✓ Base de datos de Drupal inicializada."
fi

# 12. Desplegar Payroll App
echo "=== 12. Configurando Payroll App ==="
cp "$CONFIGS_DIR/payroll_app/payroll_app.php" /var/www/html/payroll_app.php
chmod 755 /var/www/html/payroll_app.php

poc_dir="/home/kylo_ren/poc/payroll_app"
mkdir -p "$poc_dir"
cp "$CONFIGS_DIR/payroll_app/poc.rb" "$poc_dir/poc.rb"
chmod 755 "$poc_dir/poc.rb"
chown -R kylo_ren:users /home/kylo_ren/poc

# Inyectar DB Payroll
mysql -u root -psploitme < "$CONFIGS_DIR/payroll_app/payroll.sql"
echo "✓ Payroll App desplegada y base de datos inyectada."

# 13. Desplegar Readme App (Rails)
echo "=== 13. Desplegando Readme App ==="
if [ -f /etc/systemd/system/readme_app.service ]; then
    echo "✓ Readme App ya instalada."
else
    rm -rf /opt/readme_app
    mkdir -p /opt/readme_app
    tar -xvzf "$ASSETS_DIR/metasploitable3-readme.tar.gz" -C /opt/readme_app --strip-components 1
    
    # Aplicar parche BigDecimal.new y Fixnum/Bignum para Ruby 2.7
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
    
    # Instalar dependencias ruby
    cd /opt/readme_app
    # Evitar instalación interactiva
    bundle config set --local path 'vendor/bundle'
    # Asegurar que las cabeceras de SQLite3 estén instaladas
    apt-get install -y libsqlite3-dev
    
    # Crear wrappers temporales de gcc/g++ para forzar -Wno-error al final de los comandos de compilación
    # Esto es necesario porque algunas gemas (como byebug) tienen -Werror hardcodeado en su extconf.rb
    cat << 'EOF' > /tmp/gcc-wrapper
#!/bin/bash
exec /usr/bin/gcc "$@" -Wno-error -Wno-error=incompatible-pointer-types
EOF
    cat << 'EOF' > /tmp/g++-wrapper
#!/bin/bash
exec /usr/bin/g++ "$@" -Wno-error -Wno-error=incompatible-pointer-types
EOF
    chmod +x /tmp/gcc-wrapper /tmp/g++-wrapper

    # Pre-instalar gemas nativas con CFLAGS correctas para Ruby 2.7 y evitar errores por warnings
    CC=/tmp/gcc-wrapper CXX=/tmp/g++-wrapper gem install json -v '1.8.3' --install-dir vendor/bundle/ruby/2.7.0 -- --with-cflags="-Drb_cFixnum=rb_cInteger -Drb_cBignum=rb_cInteger"
    CC=/tmp/gcc-wrapper CXX=/tmp/g++-wrapper gem install byebug -v '8.2.2' --install-dir vendor/bundle/ruby/2.7.0
    CC=/tmp/gcc-wrapper CXX=/tmp/g++-wrapper gem install sqlite3 -v '1.3.11' --install-dir vendor/bundle/ruby/2.7.0 -- --with-cflags="-Drb_cFixnum=rb_cInteger -Drb_cBignum=rb_cInteger"

    rm -f /tmp/gcc-wrapper /tmp/g++-wrapper
    
    bundle install
    
    chown -R chewbacca:users /opt/readme_app
    
    # Servicio Systemd
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
    echo "✓ Readme App configurada como servicio."
fi

# 14. Desplegar Sinatra App (Ejecutado vía Ruby para evitar problemas de firmas con /etc/passwd)
echo "=== 14. Desplegando Sinatra App (Bypassing loader) ==="
if [ -f /opt/sinatra/server.rb ]; then
    echo "✓ Sinatra ya instalado."
else
    mkdir -p /opt/sinatra /var/opt/sinatra
    chmod 777 /opt/sinatra /var/opt/sinatra
    
    cp "$CONFIGS_DIR/sinatra/Gemfile" /opt/sinatra/Gemfile
    cp "$CONFIGS_DIR/sinatra/server.rb" /opt/sinatra/server.rb
    chmod 755 /opt/sinatra/server.rb
    
    # Instalar dependencias ruby para sinatra
    cd /opt/sinatra
    bundle install || true
    
    # Servicio Systemd
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
    echo "✓ Sinatra App desplegado en el puerto 8181."
fi

# 15. Desplegar Chatbot Nodejs
echo "=== 15. Desplegando Chatbot Node.js ==="
if [ -d /opt/chatbot ] && [ -f /etc/systemd/system/chatbot.service ]; then
    echo "✓ Chatbot ya instalado."
else
    rm -rf /opt/chatbot
    unzip -o "$CONFIGS_DIR/chatbot/chatbot.zip" -d /opt
    chown -R root:root /opt/chatbot
    chmod -R 700 /opt/chatbot
    # No es necesario correr npm install ya que chatbot.zip incluye node_modules completo con express y cors
    
    # Ejecutar script de instalación (crea chatbot.conf)
    # Ya que install.sh asume Upstart, crearemos directamente el servicio en Systemd
    # Asegurar permisos de ejecución para scripts shell
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
    echo "✓ Chatbot Node.js corriendo."
fi

# 16. Configurar Samba
echo "=== 16. Configurando recursos de Samba ==="
cp "$CONFIGS_DIR/samba/smb.conf" /etc/samba/smb.conf
# Copiar base de datos de contraseñas Samba pre-generada
cp "$CONFIGS_DIR/samba/passdb.tdb" /var/lib/samba/private/passdb.tdb
chmod 600 /var/lib/samba/private/passdb.tdb
systemctl restart smbd nmbd
echo "✓ Samba configurado e iniciado."

# 17. Configurar Knockd
echo "=== 17. Configurando Knockd (Port Knocking) ==="
cp "$CONFIGS_DIR/knockd/knockd.conf" /etc/knockd.conf
cp "$CONFIGS_DIR/knockd/knockd" /etc/default/knockd

# Detectar la interfaz de red activa de forma dinámica y configurarla en /etc/default/knockd
default_interface=$(ip route | grep '^default' | awk '{print $5}' | head -n1)
if [ -z "$default_interface" ]; then
    default_interface=$(ip -o link show | awk -F': ' '$2 != "lo" && $2 !~ "^docker" && $2 !~ "^veth" {print $2; exit}')
fi
if [ -n "$default_interface" ]; then
    echo "Interfaz de red detectada para knockd: $default_interface"
    sed -i "s/#KNOCKD_OPTS=.*/KNOCKD_OPTS=\"-i $default_interface\"/" /etc/default/knockd
fi

systemctl daemon-reload
systemctl enable knockd
systemctl restart knockd
echo "✓ Knockd habilitado y configurado en puerto 8989."

# 18. Desplegar Banderas (CTF)
echo "=== 18. Distribuyendo Banderas CTF (Cards) ==="

# 10 of Clubs (Wav file)
mkdir -p /home/artoo_detoo/music
cp "$CONFIGS_DIR/flags/10_of_clubs.wav" /home/artoo_detoo/music/10_of_clubs.wav
chown -R artoo_detoo:users /home/artoo_detoo/music
chmod 410 /home/artoo_detoo/music/10_of_clubs.wav

# 10 of Spades
cp "$CONFIGS_DIR/flags/flag_images/10 of spades.png" /opt/readme_app/public/images/10_of_spades.png || true
chmod 644 /opt/readme_app/public/images/10_of_spades.png || true

# 8 of Clubs (Directorio recursivo aleatorio)
prev_dirs=""
# Rutas fijas basadas en la receta de chef
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

# 5 of Diamonds (Servicio x86_64 que corre en puerto 8989 via QEMU emulado)
mkdir -p /opt/knock_knock
cp "$CONFIGS_DIR/flags/five_of_diamonds" /opt/knock_knock/five_of_diamonds
chmod 755 /opt/knock_knock/five_of_diamonds
# Crear Systemd service para five of diamonds
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

# 8 of Hearts (Base de datos MySQL secreta)
mysql -u root -psploitme -e "CREATE DATABASE IF NOT EXISTS super_secret_db;"
mysql -u root -psploitme -e "CREATE USER IF NOT EXISTS 'root'@'localhost' IDENTIFIED BY 'sploitme';" || true
mysql -u root -psploitme -e "GRANT ALL PRIVILEGES ON super_secret_db.* TO 'root'@'localhost';"
mysql -u root -psploitme super_secret_db < "$CONFIGS_DIR/flags/super_secret_db.sql"

# Joker - Red
cp "$CONFIGS_DIR/flags/joker.png" /etc/joker.png
chmod 600 /etc/joker.png

# 7 of Diamonds (En contenedor Docker)
echo "Configurando contenedor Docker para la bandera 7 de diamantes..."
if systemctl is-active --quiet docker; then
    mkdir -p /opt/docker
    cp "$CONFIGS_DIR/flags/Dockerfile" /opt/docker/Dockerfile
    cp "$CONFIGS_DIR/flags/7_of_diamonds.zip" /opt/docker/7_of_diamonds.zip
    
    cd /opt/docker
    docker build -t 7_of_diamonds . || true
    docker run -d --name 7_of_diamonds --restart always -t -i 7_of_diamonds || true
    rm -f /opt/docker/7_of_diamonds.zip
    echo "✓ Contenedor Docker 7_of_diamonds desplegado."
else
    echo "WARNING: Docker no está activo. Se omitió la creación del contenedor 7_of_diamonds."
fi

# 19. Aplicar reglas de Firewall
echo "=== 19. Configurando reglas de cortafuegos (iptables) ==="
# Limpiar reglas anteriores
iptables -F
iptables -X

# Permitir tráfico local loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Permitir conexiones establecidas/relacionadas
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Permitir ping (ICMP)
iptables -A INPUT -p icmp -j ACCEPT

# Permitir puertos específicos de Metasploitable
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

# Knockd bloquea el puerto 8989 por defecto (se abre mediante knocking)
iptables -A INPUT -p tcp --dport 8989 -j DROP

# Denegar el resto del tráfico entrante
iptables -P INPUT DROP

# Guardar reglas
if command -v iptables-save &>/dev/null; then
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4
fi

echo "=== APROVISIONAMIENTO COMPLETADO CON ÉXITO ==="
echo "La máquina virtual Metasploitable 3 ARM está lista para usarse."
echo "Puedes comprobar el estado de los puertos utilizando: netstat -tulpn"
echo "========================================================"
