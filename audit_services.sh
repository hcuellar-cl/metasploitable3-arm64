#!/bin/bash
# Service and configuration auditing script for Metasploitable 3 ARM64.
# Execute with root privileges (sudo ./audit_services.sh) inside the VM.

set -u

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run this script as root (sudo ./audit_services.sh)"
    exit 1
fi

OUTPUT_FILE="metasploitable_audit.txt"

echo "=== Generating audit report in $OUTPUT_FILE ==="

{
    echo "========================================================================"
    echo " AUDIT REPORT: METASPLOITABLE 3 ARM64"
    echo " Date: $(date)"
    echo " Kernel: $(uname -a)"
    echo " Architecture: $(uname -m)"
    echo "========================================================================"
    echo ""

    echo "=== 1. LISTENING PORTS AND SOCKETS ==="
    if command -v ss &>/dev/null; then
        ss -tulpn
    else
        netstat -tulpn
    fi
    echo ""

    echo "=== 2. STATUS OF METASPLOITABLE SERVICES (SYSTEMD) ==="
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
        echo -n "• Service: $svc -> "
        if systemctl is-active --quiet "$svc"; then
            echo "ACTIVE (running)"
        else
            echo "INACTIVE/FAILED (dead)"
            systemctl status "$svc" --no-pager | head -n 5
        fi
    done
    echo ""

    echo "=== 3. ACTIVE FIREWALL RULES (IPTABLES) ==="
    iptables -L -n -v
    echo ""

    echo "=== 4. ACTIVE DOCKER CONTAINERS (7 of Diamonds Flag) ==="
    if command -v docker &>/dev/null; then
        docker ps -a
    else
        echo "Docker is not installed on the system."
    fi
    echo ""

    echo "=== 5. METASPLOITABLE CHALLENGE USERS ==="
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
            echo "✓ User '$usr' exists in the system (UID: $(id -u "$usr"))."
        else
            echo "✗ User '$usr' DOES NOT exist."
        fi
    done
    echo ""

    echo "=== 6. SERVICE DIRECTORIES VERIFICATION ==="
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
            echo "✓ Directory '$dir' exists."
        else
            echo "✗ Directory '$dir' DOES NOT exist."
        fi
    done
    echo ""

} > "$OUTPUT_FILE"

echo "=== Report successfully generated in $OUTPUT_FILE ==="
