#!/bin/bash
# Script para automatizar el despliegue y aprovisionamiento de Metasploitable 3 ARM64.
# Ejecutar este script desde la máquina anfitriona (Host Mac).

set -euo pipefail

# Leer variables de entorno desde utm.env si existe
if [ -f "utm.env" ]; then
    echo "✓ Archivo de entorno 'utm.env' detectado."
    # Exportar variables de entorno leyendo de utm.env (eliminando retornos de carro de Windows si los hay)
    eval $(sed 's/\r$//' utm.env)
fi

# Parámetros por defecto
DEFAULT_IP="${UTM_HOST_IP:-192.168.64.29}"
DEFAULT_USER="${UTM_USER:-msfadmin}"
DEFAULT_PORT="${UTM_SSH_PORT:-22}"

# Leer parámetros
IP="${1:-$DEFAULT_IP}"
USER="${2:-$DEFAULT_USER}"
PORT="${3:-$DEFAULT_PORT}"


echo "========================================================================="
echo " Despliegue Automatizado de Metasploitable 3 ARM64"
echo " VM Destino: $USER@$IP"
echo "========================================================================="

# Paso 1: Generar/Actualizar el paquete de construcción
echo "=== 1. Reconstruyendo paquete de recursos locales ==="
if [ -f "./download_assets.sh" ]; then
    ./download_assets.sh
else
    echo "ERROR: No se encontró 'download_assets.sh' en el directorio actual."
    exit 1
fi

# Paso 2: Copiar el paquete tarball a la VM mediante SCP
echo "=== 2. Transfiriendo paquete metasploitable3-arm-build.tar.gz a la VM ==="
scp -P "$PORT" -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    metasploitable3-arm-build.tar.gz \
    "$USER@$IP:/tmp/"

# Paso 3: Ejecutar la extracción y aprovisionamiento vía SSH
echo "=== 3. Iniciando aprovisionamiento remoto via SSH (se solicitará password de sudo) ==="
SSH_CMD="cd /tmp && \
         rm -rf metasploitable3-arm-build && \
         tar -xvzf metasploitable3-arm-build.tar.gz && \
         cd metasploitable3-arm-build && \
         echo '=== Iniciando provisión con privilegios root ===' && \
         sudo ./provision_arm.sh"

ssh -p "$PORT" -t -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "$USER@$IP" \
    "$SSH_CMD"

echo "========================================================================="
echo " ¡Despliegue finalizado con éxito!"
echo "========================================================================="
