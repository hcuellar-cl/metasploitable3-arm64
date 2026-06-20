#!/bin/bash
# Script de auditoría de servicios y configuración para Metasploitable 3 ARM64.
# Ejecutar con privilegios root (sudo ./audit_services.sh) dentro de la VM.

set -u

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Por favor, ejecute este script como root (sudo ./audit_services.sh)"
    exit 1
fi

OUTPUT_FILE="metasploitable_audit.txt"

echo "=== Generando reporte de auditoría en $OUTPUT_FILE ==="

{
    echo "========================================================================"
    echo " REPORTE DE AUDITORÍA: METASPLOITABLE 3 ARM64"
    echo " Fecha: $(date)"
    echo " Kernel: $(uname -a)"
    echo " Arquitectura: $(uname -m)"
    echo "========================================================================"
    echo ""

    echo "=== 1. PUERTOS Y SOCKETS EN ESCUCHA ==="
    if command -v ss &>/dev/null; then
        ss -tulpn
    else
        netstat -tulpn
    fi
    echo ""

    echo "=== 2. ESTADO DE LOS SERVICIOS DE METASPLOITABLE (SYSTEMD) ==="
    declare -a SERVICES=(
        "apache2"
        "mysql"
        "proftpd"
        "unrealircd"
        "continuum"
        "readme_app"
        "sinatra"
        "chatbot"
        "five_of_diamonds"
        "knockd"
        "smbd"
        "nmbd"
    )

    for svc in "${SERVICES[@]}"; do
        echo -n "• Servicio: $svc -> "
        if systemctl is-active --quiet "$svc"; then
            echo "ACTIVO (running)"
        else
            echo "INACTIVO/FALLIDO (dead)"
            systemctl status "$svc" --no-pager | head -n 5
        fi
    done
    echo ""

    echo "=== 3. REGLAS ACTIVAS DEL CORTAFUEGOS (IPTABLES) ==="
    iptables -L -n -v
    echo ""

    echo "=== 4. CONTENEDORES DOCKER ACTIVOS (Bandera 7 de Diamantes) ==="
    if command -v docker &>/dev/null; then
        docker ps -a
    else
        echo "Docker no está instalado en el sistema."
    fi
    echo ""

    echo "=== 5. USUARIOS DEL RETO DE METASPLOITABLE ==="
    declare -a USERS=(
        "leia_organa"
        "luke_skywalker"
        "han_solo"
        "artoo_detoo"
        "c_three_pio"
        "ben_kenobi"
        "darth_vader"
        "anakin_skywalker"
        "jarjar_binks"
        "lando_calrissian"
        "boba_fett"
        "jabba_hutt"
        "greedo"
        "chewbacca"
        "kylo_ren"
    )

    for usr in "${USERS[@]}"; do
        if id "$usr" &>/dev/null; then
            echo "✓ Usuario '$usr' existe en el sistema (UID: $(id -u "$usr"))."
        else
            echo "✗ Usuario '$usr' NO existe."
        fi
    done
    echo ""

    echo "=== 6. VERIFICACIÓN DE CARPETAS DE SERVICIOS CRÍTICOS ==="
    declare -a DIRS=(
        "/var/www/html"
        "/opt/readme_app"
        "/opt/sinatra"
        "/opt/chatbot"
        "/opt/apache_continuum"
        "/opt/unrealircd"
        "/opt/proftpd"
        "/opt/knock_knock"
    )

    for dir in "${DIRS[@]}"; do
        if [ -d "$dir" ]; then
            echo "✓ Directorio '$dir' existe."
        else
            echo "✗ Directorio '$dir' NO existe."
        fi
    done
    echo ""

} > "$OUTPUT_FILE"

echo "=== Reporte generado con éxito en $OUTPUT_FILE ==="
