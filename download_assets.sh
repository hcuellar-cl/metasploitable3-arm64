#!/bin/bash
# Script para descargar dependencias y preparar recursos offline para Metasploitable 3 ARM.
# Debe ejecutarse en la máquina anfitriona (Host Mac).

set -euo pipefail

# Directorios de destino
BUILD_DIR="metasploitable3-arm-build"
ASSETS_DIR="$BUILD_DIR/assets"
CONFIGS_DIR="$BUILD_DIR/configs"

echo "=== Creando estructura de directorios ==="
mkdir -p "$ASSETS_DIR"
mkdir -p "$CONFIGS_DIR"

# Función para descargar archivos de forma segura y portable
download_file() {
    local file="$1"
    local url="$2"
    local target="$ASSETS_DIR/$file"
    
    if [ -f "$target" ]; then
        echo "✓ $file ya existe, omitiendo descarga."
    else
        echo "Descargando $file de $url..."
        # Usamos curl con -L para seguir redirecciones, --fail para salir con error en HTTP >= 400 y --retry para resiliencia
        if ! curl -L --fail --retry 3 --retry-delay 2 -o "$target" "$url"; then
            echo "ERROR: Falló la descarga de $file"
            # Intento de descarga alternativo si falla ftp.proftpd.org o similar
            if [ "$file" == "proftpd-1.3.5.tar.gz" ]; then
                echo "Intentando espejo alternativo para ProFTPd..."
                if ! curl -L --fail -o "$target" "https://github.com/proftpd/proftpd/archive/refs/tags/v1.3.5.tar.gz"; then
                    echo "ERROR: También falló el espejo alternativo de ProFTPd."
                    exit 1
                fi
            else
                exit 1
            fi
        fi
    fi
}

echo "=== Descargando paquetes fuente ==="
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


echo "=== Copiando archivos de configuración locales del repositorio ==="
SRC_FILES_DIR="metasploitable3/chef/cookbooks/metasploitable/files"
if [ -d "$SRC_FILES_DIR" ]; then
    cp -r "$SRC_FILES_DIR"/* "$CONFIGS_DIR"/
    echo "✓ Archivos locales copiados con éxito."
else
    echo "ERROR: No se encontró el directorio de archivos origen ($SRC_FILES_DIR)."
    exit 1
fi

echo "=== Generando configuraciones resueltas a partir de plantillas ==="

# 1. Resolver knockd.conf
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
echo "✓ Archivo configs/knockd/knockd.conf generado."

# 2. Resolver payroll.sql
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
echo "✓ Archivo configs/payroll_app/payroll.sql generado."

# 3. Resolver start.sh de readme_app
mkdir -p "$CONFIGS_DIR/readme_app"
cat << 'EOF' > "$CONFIGS_DIR/readme_app/start.sh"
#!/bin/sh
cd /opt/readme_app
bundle install --path vendor/bundle
bundle exec rails s -b 0.0.0.0 -p 3500
EOF
chmod +x "$CONFIGS_DIR/readme_app/start.sh"
echo "✓ Archivo configs/readme_app/start.sh generado."

if [ -f "$CONFIGS_DIR/sinatra/virtualbox/loader" ]; then
    cp "$CONFIGS_DIR/sinatra/virtualbox/loader" "$CONFIGS_DIR/sinatra/loader"
    echo "✓ Copiado sinatra loader (x86_64)."
else
    echo "WARNING: No se encontró sinatra loader binary en virtualbox/"
fi

# Copiar el server.rb para el servicio Sinatra sin obfuscación/loader
if [ -f "metasploitable3/resources/flags/linux_flags/6_of_clubs/server.rb" ]; then
    cp "metasploitable3/resources/flags/linux_flags/6_of_clubs/server.rb" "$CONFIGS_DIR/sinatra/server.rb"
    echo "✓ Copiado sinatra server.rb de flags a configuraciones."
else
    echo "WARNING: No se encontró 'server.rb' de sinatra en el repositorio de metasploitable3."
fi


# 5. Copiar los scripts de aprovisionamiento y auditoría al directorio de construcción
if [ -f "provision_arm.sh" ]; then
    cp "provision_arm.sh" "$BUILD_DIR/provision_arm.sh"
    chmod +x "$BUILD_DIR/provision_arm.sh"
    echo "✓ Copiado script de aprovisionamiento 'provision_arm.sh' al directorio de construcción."
else
    echo "WARNING: No se encontró 'provision_arm.sh' en el directorio raíz."
fi

if [ -f "audit_services.sh" ]; then
    cp "audit_services.sh" "$BUILD_DIR/audit_services.sh"
    chmod +x "$BUILD_DIR/audit_services.sh"
    echo "✓ Copiado script de auditoría 'audit_services.sh' al directorio de construcción."
else
    echo "WARNING: No se encontró 'audit_services.sh' en el directorio raíz."
fi

# 6. Crear un archivo README informativo en el paquete
cat << 'EOF' > "$BUILD_DIR/README.txt"
Metasploitable 3 ARM (ARM64) - Kit de aprovisionamiento offline
============================================================

Este directorio contiene los recursos pre-descargados y las configuraciones resueltas
necesarias para replicar Metasploitable 3 en una máquina virtual Ubuntu Server ARM64 en UTM.

Instrucciones de Despliegue:
1. Copia este directorio o el archivo comprimido 'metasploitable3-arm-build.tar.gz'
   a la máquina virtual Ubuntu Server ARM64 de UTM.
2. Extrae el archivo comprimido en la máquina virtual si es necesario:
   tar -xvzf metasploitable3-arm-build.tar.gz
3. Entra al directorio extraído:
   cd metasploitable3-arm-build
4. Ejecuta el script de aprovisionamiento con privilegios de root:
   sudo ./provision_arm.sh

Nota: La máquina virtual debe tener acceso temporal a internet durante el aprovisionamiento
para que apt-get pueda descargar las herramientas base y compiladores (build-essential,
mysql-server, apache2, openjdk, samba, nodejs, etc.). Los servicios vulnerables
principales (PHP 5.4.5, UnrealIRCd, ProFTPd, Drupal) se compilarán e instalarán
utilizando las dependencias pre-descargadas de forma local en la carpeta 'assets/'.
EOF
echo "✓ Archivo README.txt generado."

echo "=== Creando archivo comprimido tar.gz ==="
tar -czf metasploitable3-arm-build.tar.gz "$BUILD_DIR"
echo "✓ Archivo 'metasploitable3-arm-build.tar.gz' creado con éxito."

echo "========================================================================="
echo "Preparación COMPLETADA con éxito."
echo "Directorio de compilación: $BUILD_DIR"
echo "Archivo empaquetado para la VM: metasploitable3-arm-build.tar.gz"
echo "========================================================================="

