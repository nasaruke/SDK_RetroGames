#!/bin/bash

# Script de instalacion para Consola Retro SDK en Raspberry Pi OS Lite
# Proyecto Final — Fundamentos de Sistemas Embebidos UNAM
# Autor original: nasaruke
# Versión corregida: autoarranque con systemd + permisos de Mednafen/Pygame/SDL

set -e

echo ""
echo ""
echo "==================================================="
echo "  INSTALACIÓN CONSOLA RETRO SDK EN RASPBERRY"
echo "==================================================="
echo ""
echo ""

# El script debe ejecutarse con sudo para poder instalar paquetes,
# crear servicios systemd y configurar permisos.
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: ejecuta este instalador con sudo:"
    echo "sudo bash instalar_consola_retro_arreglado.sh"
    exit 1
fi

# Obtener usuario real aunque se corra con sudo
if [ -n "$SUDO_USER" ]; then
    USUARIO="$SUDO_USER"
else
    USUARIO="pi"
fi

HOME_DIR="/home/$USUARIO"
RUTA_PROYECTO="$HOME_DIR/consola_retro"
RUTA_SRC="$RUTA_PROYECTO/src"
PYTHON_SCRIPT="$RUTA_SRC/main.py"
LOG_FILE="$HOME_DIR/consola_retro.log"
SERVICE_FILE="/etc/systemd/system/consola-retro.service"

if [ ! -d "$HOME_DIR" ]; then
    echo "ERROR: no existe $HOME_DIR"
    echo "Verifica el usuario. Usuario detectado: $USUARIO"
    exit 1
fi

echo "Usuario detectado: $USUARIO"
echo "Carpeta del proyecto: $RUTA_PROYECTO"
echo "Log del sistema: $LOG_FILE"
echo ""

# Función para mostrar mensajes de instalación
function instalar {
    DESCRIPCION="$1"
    shift
    echo ""
    echo ""
    echo "==================================================="
    echo "Instalando/configurando: $DESCRIPCION"
    echo "==================================================="
    echo ""
    "$@"
    if [ $? -eq 0 ]; then
        echo "$DESCRIPCION completado con éxito."
        echo ""
    else
        echo "ERROR en: $DESCRIPCION"
        exit 1
    fi
}

# 0. Detener servicio anterior si existe y limpiar cron viejo
if systemctl list-unit-files | grep -q '^consola-retro.service'; then
    systemctl stop consola-retro.service || true
fi

# El instalador viejo usaba cron @reboot. Se elimina para evitar doble arranque.
if crontab -u "$USUARIO" -l 2>/dev/null | grep -q "consola_retro/src/main.py"; then
    echo "Eliminando autoarranque viejo de cron..."
    crontab -u "$USUARIO" -l 2>/dev/null | grep -v "consola_retro/src/main.py" | crontab -u "$USUARIO" -
fi

# 1. Actualizar sistema base
instalar "paquetes base" apt update
instalar "actualización del sistema" apt upgrade -y

# 2. Instalar dependencias del sistema
instalar "Git, Curl y Unzip" apt install -y git curl unzip
instalar "Python y dependencias básicas" apt install -y python3 python3-pip python3-dev
instalar "dependencias de SDL para Pygame" apt install -y libsdl2-dev libsdl2-mixer-dev libsdl2-image-dev libsdl2-ttf-dev libsdl2-2.0-0
instalar "emulador Mednafen" apt install -y mednafen
instalar "Pygame" apt install -y python3-pygame
instalar "PyUDEV" apt install -y python3-pyudev

# 3. Permisos de usuario para video, audio, controles y render KMS/DRM
echo ""
echo "==================================================="
echo "Configurando grupos del usuario..."
usermod -aG video,audio,input,render "$USUARIO" || true
echo "Usuario $USUARIO agregado a grupos: video, audio, input, render"
echo ""

# 4. Crear estructura de directorios
echo ""
echo "==================================================="
echo "Creando estructura de directorios..."
mkdir -p "$RUTA_SRC/roms/nes"
mkdir -p "$RUTA_SRC/roms/snes"
mkdir -p "$RUTA_SRC/roms/gba"
mkdir -p "$HOME_DIR/.mednafen"

# El código usb_monitor.py usa esta ruta fija.
mkdir -p /media/pi/usb_retro
chown -R "$USUARIO:$USUARIO" /media/pi
chown -R "$USUARIO:$USUARIO" "$RUTA_PROYECTO" "$HOME_DIR/.mednafen"
echo "Directorios creados con éxito."
echo ""

# 5. Clonar el repositorio y copiar código
REPO_DIR="$HOME_DIR/SDK_RetroGames"
echo ""
echo "==================================================="
echo "Clonando repositorio..."
rm -rf "$REPO_DIR"
sudo -u "$USUARIO" git clone --branch main --single-branch https://github.com/nasaruke/SDK_RetroGames.git "$REPO_DIR"

echo ""
echo "==================================================="
echo "Copiando códigos del repositorio..."
cp "$REPO_DIR/src/"*.py "$RUTA_SRC/"
cp "$REPO_DIR/src/"*.sh "$RUTA_SRC/" 2>/dev/null || true
chown -R "$USUARIO:$USUARIO" "$RUTA_PROYECTO"
echo "Códigos copiados con éxito."
echo ""

# 6. Descargar y descomprimir recursos desde branch instalaciones
echo ""
echo "==================================================="
echo "Descargando y copiando archivos de consola..."
REPO_RAW="https://raw.githubusercontent.com/nasaruke/SDK_RetroGames/instalaciones"
TEMP_DIR="$HOME_DIR/temp_instalacion"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
chown -R "$USUARIO:$USUARIO" "$TEMP_DIR"

echo "Descargando assets..."
sudo -u "$USUARIO" curl -fsSL "$REPO_RAW/assets.zip" -o "$TEMP_DIR/assets.zip"

echo "Descargando config..."
sudo -u "$USUARIO" curl -fsSL "$REPO_RAW/config.zip" -o "$TEMP_DIR/config.zip"

echo "Descargando ROMs NES..."
sudo -u "$USUARIO" curl -fsSL "$REPO_RAW/nes.zip" -o "$TEMP_DIR/nes.zip"

echo "Descargando ROMs SNES..."
sudo -u "$USUARIO" curl -fsSL "$REPO_RAW/snes.zip" -o "$TEMP_DIR/snes.zip"

echo "Descargando ROMs GBA..."
sudo -u "$USUARIO" curl -fsSL "$REPO_RAW/gba.zip" -o "$TEMP_DIR/gba.zip"

unzip -q -o "$TEMP_DIR/assets.zip" -d "$RUTA_SRC/"
unzip -q -o "$TEMP_DIR/config.zip" -d "$RUTA_SRC/"
unzip -q -o "$TEMP_DIR/nes.zip"    -d "$RUTA_SRC/roms/"
unzip -q -o "$TEMP_DIR/snes.zip"   -d "$RUTA_SRC/roms/"
unzip -q -o "$TEMP_DIR/gba.zip"    -d "$RUTA_SRC/roms/"

rm -rf "$TEMP_DIR"
rm -rf "$REPO_DIR"
chown -R "$USUARIO:$USUARIO" "$RUTA_PROYECTO"
echo "Archivos copiados con éxito."
echo ""

# 7. Permisos para mount, umount y shutdown sin contraseña
echo ""
echo "==================================================="
echo "Configurando permisos USB y shutdown..."
echo "$USUARIO ALL=(ALL) NOPASSWD: /bin/mount, /bin/umount, /usr/bin/mount, /usr/bin/umount, /sbin/shutdown, /usr/sbin/shutdown" > /etc/sudoers.d/consola_retro
chmod 440 /etc/sudoers.d/consola_retro
echo "Permisos configurados con éxito."
echo ""

# 8. Configuración de Mednafen con permisos correctos
echo ""
echo "==================================================="
echo "Aplicando configuración de Mednafen..."
mkdir -p "$HOME_DIR/.mednafen"
chown -R "$USUARIO:$USUARIO" "$HOME_DIR/.mednafen"

# Copiar cfg con controles ya configurados sin dejarlo como root.
if [ -f "$RUTA_SRC/config/mednafen/mednafen.cfg" ]; then
    install -o "$USUARIO" -g "$USUARIO" -m 0644 "$RUTA_SRC/config/mednafen/mednafen.cfg" "$HOME_DIR/.mednafen/mednafen.cfg"
    echo "mednafen.cfg copiado con permisos correctos."
else
    echo "ADVERTENCIA: no se encontró $RUTA_SRC/config/mednafen/mednafen.cfg"
fi

# Reparación extra para evitar el error PermissionError: /home/pi/.mednafen/mednafen.cfg
chown -R "$USUARIO:$USUARIO" "$HOME_DIR/.mednafen"
chmod -R u+rwX "$HOME_DIR/.mednafen"
[ -f "$HOME_DIR/.mednafen/mednafen.cfg" ] && chmod 644 "$HOME_DIR/.mednafen/mednafen.cfg"

# 9. Variables SDL en bashrc para pruebas manuales
echo ""
echo "==================================================="
echo "Configurando variables SDL en .bashrc..."
if ! grep -q "SDL_VIDEODRIVER=kmsdrm" "$HOME_DIR/.bashrc"; then
    cat >> "$HOME_DIR/.bashrc" << BASHRC

# Variables para Consola Retro SDK en Raspberry Pi OS Lite sin escritorio
export SDL_VIDEODRIVER=kmsdrm
export SDL_AUDIODRIVER=alsa
BASHRC
    chown "$USUARIO:$USUARIO" "$HOME_DIR/.bashrc"
    echo "Variables SDL agregadas a .bashrc."
else
    echo "Variables SDL ya existen en .bashrc."
fi

# 10. Verificar que main.py existe
echo ""
echo "==================================================="
echo "Verificando instalación..."
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "ERROR: El archivo $PYTHON_SCRIPT no existe."
    exit 1
fi
if [ ! -f "$RUTA_SRC/config/configuracion.json" ]; then
    echo "ERROR: Falta $RUTA_SRC/config/configuracion.json"
    exit 1
fi

touch "$LOG_FILE"
chown "$USUARIO:$USUARIO" "$LOG_FILE"
chmod 664 "$LOG_FILE"

echo "Archivos principales encontrados."
echo ""

# 11. Autoarranque con systemd en lugar de cron
echo ""
echo "==================================================="
echo "Configurando autoarranque con systemd..."
cat > "$SERVICE_FILE" << SERVICE
[Unit]
Description=Consola Retro SDK
After=local-fs.target systemd-user-sessions.service sound.target
Wants=sound.target
Conflicts=getty@tty1.service

[Service]
Type=simple
User=$USUARIO
Group=$USUARIO
SupplementaryGroups=video audio input render
WorkingDirectory=$RUTA_SRC
Environment=SDL_VIDEODRIVER=kmsdrm
Environment=SDL_AUDIODRIVER=alsa
Environment=PYTHONUNBUFFERED=1
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
StandardInput=tty
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE
ExecStart=/usr/bin/python3 $PYTHON_SCRIPT
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
SERVICE

chmod 644 "$SERVICE_FILE"
systemctl daemon-reload
systemctl enable consola-retro.service

echo "Servicio systemd creado: $SERVICE_FILE"
echo ""

# 12. Configurar login automático como respaldo para mantenimiento manual
# Nota: el servicio consola-retro toma tty1; si se desactiva el servicio, queda el autologin disponible.
echo ""
echo "==================================================="
echo "Configurando login automático de respaldo..."
mkdir -p /etc/systemd/system/getty@tty1.service.d/
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << AUTOLOGIN
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USUARIO --noclear %I \$TERM
AUTOLOGIN
systemctl daemon-reload
echo "Login automático configurado para $USUARIO."
echo ""

# 13. Ocultar mensajes de arranque
echo ""
echo "==================================================="
echo "Modificando cmdline.txt para ocultar mensajes..."
CMDLINE="/boot/firmware/cmdline.txt"
if [ ! -f "$CMDLINE" ]; then
    CMDLINE="/boot/cmdline.txt"
fi

if [ -f "$CMDLINE" ]; then
    if ! grep -q "quiet loglevel=0 logo.nologo fsck.mode=skip" "$CMDLINE"; then
        sed -i 's/$/ quiet loglevel=0 logo.nologo fsck.mode=skip rd.systemd.show_status=false rd.udev.log_level=3/' "$CMDLINE"
        echo "Parámetros agregados a cmdline.txt."
    else
        echo "Los parámetros ya existen en cmdline.txt."
    fi
else
    echo "ADVERTENCIA: no se encontró cmdline.txt."
fi

# Suprimir mensajes de bienvenida de Debian
truncate -s 0 /etc/motd || true
truncate -s 0 /etc/issue || true
truncate -s 0 /etc/issue.net || true
sed -i 's/^#PrintLastLog=yes/PrintLastLog=no/' /etc/systemd/logind.conf || true
sed -i 's/^PrintLastLog=yes/PrintLastLog=no/' /etc/systemd/logind.conf || true

# 14. Mensaje final
echo ""
echo "================================================="
echo " INSTALACIÓN COMPLETADA SATISFACTORIAMENTE"
echo "================================================="
echo ""
echo "Cambios importantes aplicados:"
echo "  - Se eliminó el autoarranque viejo por cron."
echo "  - Se creó consola-retro.service con systemd."
echo "  - Se repararon permisos de /home/$USUARIO/.mednafen."
echo "  - Se agregaron grupos video/audio/input/render para Pygame, SDL y controles."
echo ""
echo "Comandos útiles:"
echo "  Ver log:       cat $LOG_FILE"
echo "  Ver servicio:  sudo systemctl status consola-retro.service"
echo "  Ver errores:   journalctl -u consola-retro.service -b"
echo "  Probar manual: cd $RUTA_SRC && python3 main.py"
echo ""
echo "El sistema se reiniciará en 10 segundos..."
sleep 10
reboot
