#!/bin/bash

# =============================================================================
# instalar.sh — Instalación automática de Consola Retro SDK
# Proyecto Final — Fundamentos de Sistemas Embebidos UNAM
# =============================================================================

echo ""
echo "==================================================="
echo "   INSTALACIÓN CONSOLA RETRO SDK"
echo "   Fundamentos de Sistemas Embebidos — UNAM"
echo "==================================================="
echo ""

# Obtener usuario actual
USUARIO=$(who am i | awk '{print $1}')
if [ -z "$USUARIO" ]; then
    USUARIO=$(whoami)
fi
HOME_DIR="/home/$USUARIO"
RUTA_PROYECTO="$HOME_DIR/consola_retro"
RUTA_SRC="$RUTA_PROYECTO/src"
PYTHON_SCRIPT="$RUTA_SRC/main.py"
LOG_FILE="$HOME_DIR/consola_retro.log"
REPO_MAIN="https://github.com/nasaruke/SDK_RetroGames.git"

echo "Usuario: $USUARIO"
echo "Proyecto: $RUTA_PROYECTO"
echo ""

# =============================================================================
# PASO 1 — Actualizar sistema
# =============================================================================
echo "==================================================="
echo "PASO 1: Actualizando sistema..."
echo "==================================================="
sudo apt update -y && sudo apt upgrade -y
echo "Sistema actualizado."
echo ""

# =============================================================================
# PASO 2 — Instalar dependencias
# =============================================================================
echo "==================================================="
echo "PASO 2: Instalando dependencias..."
echo "==================================================="

sudo apt install -y git unzip python3 python3-pip python3-dev python3-pygame
sudo apt install -y python3-pyudev
sudo apt install -y mednafen
sudo apt install -y util-linux

# Dependencias SDL necesarias para imagen en Raspbian Lite
sudo apt install -y libsdl2-dev libsdl2-mixer-dev libsdl2-image-dev libsdl2-ttf-dev
sudo apt install -y libsdl2-2.0-0

# Dependencia adicional para Raspberry Pi
sudo apt install -y libatlas-base-dev

echo "Dependencias instaladas."
echo ""

# =============================================================================
# PASO 3 — Clonar rama main (códigos)
# =============================================================================
echo "==================================================="
echo "PASO 3: Clonando repositorio (códigos)..."
echo "==================================================="

if [ -d "$RUTA_PROYECTO" ]; then
    echo "Eliminando instalación anterior..."
    rm -rf "$RUTA_PROYECTO"
fi

git clone --branch main --single-branch "$REPO_MAIN" "$RUTA_PROYECTO"
echo "Códigos clonados en $RUTA_PROYECTO"
echo ""

# =============================================================================
# PASO 4 — Descargar y descomprimir recursos en src/
# =============================================================================
echo "==================================================="
echo "PASO 4: Descargando recursos (ROMs, assets, config)..."
echo "==================================================="

REPO_RAW="https://raw.githubusercontent.com/nasaruke/SDK_RetroGames/instalaciones"
TEMP_DIR="$HOME_DIR/temp_instalacion"
mkdir -p "$TEMP_DIR"

# Crear estructura de carpetas dentro de src/
mkdir -p "$RUTA_SRC/roms/nes"
mkdir -p "$RUTA_SRC/roms/snes"
mkdir -p "$RUTA_SRC/roms/gba"

# Descargar todos los zips
echo "Descargando assets..."
wget -q "$REPO_RAW/assets.zip" -O "$TEMP_DIR/assets.zip"

echo "Descargando config..."
wget -q "$REPO_RAW/config.zip" -O "$TEMP_DIR/config.zip"

echo "Descargando ROMs NES..."
wget -q "$REPO_RAW/nes.zip" -O "$TEMP_DIR/nes.zip"

echo "Descargando ROMs SNES..."
wget -q "$REPO_RAW/snes.zip" -O "$TEMP_DIR/snes.zip"

echo "Descargando ROMs GBA..."
wget -q "$REPO_RAW/gba.zip" -O "$TEMP_DIR/gba.zip"

# Descomprimir en src/
echo "Descomprimiendo assets..."
unzip -q "$TEMP_DIR/assets.zip" -d "$RUTA_SRC/"

echo "Descomprimiendo config..."
unzip -q "$TEMP_DIR/config.zip" -d "$RUTA_SRC/"

echo "Descomprimiendo ROMs NES..."
unzip -q "$TEMP_DIR/nes.zip" -d "$RUTA_SRC/roms/"

echo "Descomprimiendo ROMs SNES..."
unzip -q "$TEMP_DIR/snes.zip" -d "$RUTA_SRC/roms/"

echo "Descomprimiendo ROMs GBA..."
unzip -q "$TEMP_DIR/gba.zip" -d "$RUTA_SRC/roms/"

# Limpiar archivos temporales
rm -rf "$TEMP_DIR"
echo "Recursos instalados."
echo ""

# =============================================================================
# PASO 5 — Crear carpeta de montaje USB y permisos
# =============================================================================
echo "==================================================="
echo "PASO 5: Configurando permisos USB y shutdown..."
echo "==================================================="

sudo mkdir -p /media/pi/usb_retro
sudo chown $USUARIO:$USUARIO /media/pi
sudo chown $USUARIO:$USUARIO /media/pi/usb_retro

# Permisos para mount, umount y shutdown sin contraseña
echo "$USUARIO ALL=(ALL) NOPASSWD: /bin/mount, /bin/umount, /sbin/shutdown" | sudo tee /etc/sudoers.d/mount_usb_retro
sudo chmod 440 /etc/sudoers.d/mount_usb_retro

echo "Permisos configurados."
echo ""

# =============================================================================
# PASO 6 — Configurar mednafen
# =============================================================================
echo "==================================================="
echo "PASO 6: Configurando mednafen..."
echo "==================================================="

mkdir -p "$HOME_DIR/.mednafen"

# Correr mednafen una vez para generar su cfg base
echo "Generando configuración base de mednafen..."
sudo -u $USUARIO mednafen &
MEDNAFEN_PID=$!
sleep 10
kill $MEDNAFEN_PID 2>/dev/null
wait $MEDNAFEN_PID 2>/dev/null

# Copiar el cfg ya configurado con los controles Xbox
if [ -f "$RUTA_SRC/config/mednafen/mednafen.cfg" ]; then
    cp "$RUTA_SRC/config/mednafen/mednafen.cfg" "$HOME_DIR/.mednafen/mednafen.cfg"
    echo "mednafen.cfg con controles Xbox Series copiado."
else
    echo "ADVERTENCIA: No se encontró config/mednafen/mednafen.cfg"
fi

echo "Mednafen configurado."
echo ""

# =============================================================================
# PASO 7 — Variables de entorno SDL
# =============================================================================
echo "==================================================="
echo "PASO 7: Configurando variables SDL..."
echo "==================================================="

if ! grep -q "SDL_VIDEODRIVER" "$HOME_DIR/.bashrc"; then
    echo "" >> "$HOME_DIR/.bashrc"
    echo "# Variables para pygame en Raspbian Lite sin escritorio" >> "$HOME_DIR/.bashrc"
    echo "export SDL_VIDEODRIVER=kmsdrm" >> "$HOME_DIR/.bashrc"
    echo "export SDL_AUDIODRIVER=alsa" >> "$HOME_DIR/.bashrc"
    echo "Variables SDL agregadas a .bashrc"
else
    echo "Variables SDL ya existen."
fi
echo ""

# =============================================================================
# PASO 8 — Ocultar mensajes de arranque
# =============================================================================
echo "==================================================="
echo "PASO 8: Ocultando mensajes de arranque..."
echo "==================================================="

CMDLINE="/boot/firmware/cmdline.txt"
if [ ! -f "$CMDLINE" ]; then
    CMDLINE="/boot/cmdline.txt"
fi

if [ -f "$CMDLINE" ]; then
    if ! grep -q "quiet loglevel=0 logo.nologo fsck.mode=skip" "$CMDLINE"; then
        sudo sed -i 's/$/ quiet loglevel=0 logo.nologo fsck.mode=skip rd.systemd.show_status=false rd.udev.log_level=3/' "$CMDLINE"
        echo "Mensajes del kernel ocultados."
    else
        echo "Kernel ya estaba configurado."
    fi
fi

# Suprimir mensajes de bienvenida de Debian
sudo truncate -s 0 /etc/motd
sudo truncate -s 0 /etc/issue
sudo truncate -s 0 /etc/issue.net

# Deshabilitar mensaje de último login
sudo sed -i 's/^#PrintLastLog=yes/PrintLastLog=no/' /etc/systemd/logind.conf
sudo sed -i 's/^PrintLastLog=yes/PrintLastLog=no/' /etc/systemd/logind.conf

echo "Mensajes de arranque ocultados."
echo ""

# =============================================================================
# PASO 9 — Arranque automático con cron (igual que ccjpmmGaming)
# =============================================================================
echo "==================================================="
echo "PASO 9: Configurando arranque automático con cron..."
echo "==================================================="

# Crear archivo de log
touch "$LOG_FILE"
chown $USUARIO:$USUARIO "$LOG_FILE"

# Verificar que el script existe
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "ERROR: No se encontró $PYTHON_SCRIPT"
    exit 1
fi

# Agregar arranque con cron usando @reboot
# Incluye las variables SDL necesarias para pygame
CRON_CMD="@reboot export SDL_VIDEODRIVER=kmsdrm && export SDL_AUDIODRIVER=alsa && cd $RUTA_SRC && python3 $PYTHON_SCRIPT >> $LOG_FILE 2>&1"

if crontab -u $USUARIO -l 2>/dev/null | grep -q "$PYTHON_SCRIPT"; then
    echo "Cron ya está configurado."
else
    (crontab -u $USUARIO -l 2>/dev/null; echo "$CRON_CMD") | crontab -u $USUARIO -
    echo "Cron configurado para arranque automático."
fi

# Deshabilitar systemd si estaba configurado antes
sudo systemctl disable consola-retro.service 2>/dev/null
sudo rm -f /etc/systemd/system/consola-retro.service
sudo systemctl daemon-reload

echo "Arranque automático configurado."
echo ""

# =============================================================================
# PASO 10 — Login automático sin contraseña
# =============================================================================
echo "==================================================="
echo "PASO 10: Configurando login automático..."
echo "==================================================="

sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null << AUTOLOGIN
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USUARIO --noclear %I \$TERM
AUTOLOGIN

sudo systemctl daemon-reload
echo "Login automático configurado para $USUARIO."
echo ""

# =============================================================================
# PASO 11 — Verificar instalación
# =============================================================================
echo "==================================================="
echo "PASO 11: Verificando instalación..."
echo "==================================================="

echo "Verificando estructura de archivos..."
ls "$RUTA_SRC/config/configuracion.json"    && echo "  ✓ configuracion.json"  || echo "  ✗ configuracion.json NO encontrado"
ls "$RUTA_SRC/config/mednafen/mednafen.cfg" && echo "  ✓ mednafen.cfg"        || echo "  ✗ mednafen.cfg NO encontrado"
ls "$RUTA_SRC/assets/imagenes/logo_SDK.png" && echo "  ✓ logo_SDK.png"        || echo "  ✗ logo_SDK.png NO encontrado"
ls "$RUTA_SRC/roms/nes/"                    && echo "  ✓ ROMs NES"            || echo "  ✗ ROMs NES NO encontradas"

echo "Verificación completada."
echo ""

# =============================================================================
# RESUMEN
# =============================================================================
echo "==================================================="
echo "   INSTALACIÓN COMPLETADA EXITOSAMENTE"
echo "==================================================="
echo ""
echo "  ✓ Dependencias instaladas"
echo "  ✓ Códigos clonados de GitHub"
echo "  ✓ ROMs y assets en src/"
echo "  ✓ mednafen configurado con controles Xbox Series"
echo "  ✓ Permisos USB y shutdown configurados"
echo "  ✓ Mensajes de arranque ocultados"
echo "  ✓ Arranque automático con cron configurado"
echo "  ✓ Login automático configurado"
echo ""
echo "Para ver errores: cat $LOG_FILE"
echo ""
echo "El sistema se reiniciará en 10 segundos..."
sleep 10
sudo reboot
