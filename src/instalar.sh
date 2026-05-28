#!/bin/bash

# Script de instalacion para Consola Retro SDK en Raspberry Pi OS Lite
# Proyecto Final — Fundamentos de Sistemas Embebidos UNAM
# Autor: nasaruke

echo ""
echo ""
echo "==================================================="
echo "  INSTALACIÓN CONSOLA RETRO SDK EN RASPBERRY  "
echo "==================================================="
echo ""
echo ""

# Obtener usuario real aunque se corra con sudo
if [ -n "$SUDO_USER" ]; then
    USUARIO=$SUDO_USER
else
    USUARIO=$(whoami)
fi
HOME_DIR="/home/$USUARIO"
RUTA_PROYECTO="$HOME_DIR/consola_retro"
RUTA_SRC="$RUTA_PROYECTO/src"
PYTHON_SCRIPT="$RUTA_SRC/main.py"
LOG_FILE="$HOME_DIR/consola_retro.log"

echo "Usuario detectado: $USUARIO"
echo "Carpeta del proyecto: $RUTA_PROYECTO"
echo ""

# Función para mostrar mensajes de instalación
function instalar {
    echo ""
    echo ""
    echo "==================================================="
    echo "Instalando $1..."
    echo "==================================================="
    echo ""
    echo ""
    shift
    $@
    if [ $? -eq 0 ]; then
        echo "$1 se instaló con éxito!"
        echo ""
    else
        echo "Error al instalar $1"
        exit 1
    fi
}

# 0. Actualizar sistema base
instalar "paquetes base" sudo apt update && sudo apt upgrade -y

# 1. Instalar git, curl y clonar el repositorio
instalar "Git y Curl" sudo apt install git curl -y
git clone --branch main --single-branch https://github.com/nasaruke/SDK_RetroGames.git "$HOME_DIR/SDK_RetroGames"

# 2. Instalar dependencias esenciales
instalar "Python y dependencias básicas" sudo apt install -y python3 python3-pip python3-dev

# 3. Instalar dependencias para Pygame
instalar "dependencias de SDL para Pygame" sudo apt install -y libsdl2-dev libsdl2-mixer-dev libsdl2-image-dev libsdl2-ttf-dev

# 4. Instalar el emulador Mednafen
instalar "emulador Mednafen" sudo apt install -y mednafen

# 5. Instalar paquetes Python
instalar "Pygame" sudo apt install -y python3 python3-pygame
instalar "PyUDEV" sudo apt install -y python3 python3-pyudev

# 6. Instalar dependencias adicionales para Raspberry Pi
instalar "dependencias adicionales" sudo apt install -y libsdl2-2.0-0

# 6.1 Instalar cron
instalar "Cron" sudo apt install -y cron
sudo systemctl enable cron
sudo systemctl start cron

# 7. Crear estructura de directorios
echo ""
echo ""
echo "==================================================="
echo "Creando estructura de directorios..."

mkdir -p "$RUTA_SRC/roms/nes"
mkdir -p "$RUTA_SRC/roms/snes"
mkdir -p "$RUTA_SRC/roms/gba"

# Crear carpeta .mednafen con permisos correctos desde el inicio
sudo -u $USUARIO mkdir -p "$HOME_DIR/.mednafen"

# Carpeta de montaje para USB
sudo mkdir -p /media/pi/usb_retro
sudo chown $USUARIO:$USUARIO /media/pi
sudo chown $USUARIO:$USUARIO /media/pi/usb_retro

echo "Directorios creados con éxito!"
echo ""

# 8. Copiar los códigos del repo clonado a src/
echo ""
echo ""
echo "==================================================="
echo "Copiando códigos del repositorio..."

cp "$HOME_DIR/SDK_RetroGames/src/"*.py "$RUTA_SRC/"
cp "$HOME_DIR/SDK_RetroGames/src/"*.sh "$RUTA_SRC/" 2>/dev/null
chown -R $USUARIO:$USUARIO "$RUTA_PROYECTO"

echo "Códigos copiados con éxito!"
echo ""

# 9. Descargar y descomprimir recursos desde branch instalaciones
echo ""
echo ""
echo "==================================================="
echo "Descargando y copiando archivos de consola..."

REPO_RAW="https://raw.githubusercontent.com/nasaruke/SDK_RetroGames/instalaciones"
TEMP_DIR="$HOME_DIR/temp_instalacion"
mkdir -p "$TEMP_DIR"

echo "Descargando assets..."
curl -fsSL "$REPO_RAW/assets.zip" -o "$TEMP_DIR/assets.zip"

echo "Descargando config..."
curl -fsSL "$REPO_RAW/config.zip" -o "$TEMP_DIR/config.zip"

echo "Descargando ROMs NES..."
curl -fsSL "$REPO_RAW/nes.zip" -o "$TEMP_DIR/nes.zip"

echo "Descargando ROMs SNES..."
curl -fsSL "$REPO_RAW/snes.zip" -o "$TEMP_DIR/snes.zip"

echo "Descargando ROMs GBA..."
curl -fsSL "$REPO_RAW/gba.zip" -o "$TEMP_DIR/gba.zip"

# Descomprimir en src/
unzip -q "$TEMP_DIR/assets.zip" -d "$RUTA_SRC/"
unzip -q "$TEMP_DIR/config.zip" -d "$RUTA_SRC/"
unzip -q "$TEMP_DIR/nes.zip"    -d "$RUTA_SRC/roms/"
unzip -q "$TEMP_DIR/snes.zip"   -d "$RUTA_SRC/roms/"
unzip -q "$TEMP_DIR/gba.zip"    -d "$RUTA_SRC/roms/"

# Limpiar temporales y repo clonado
rm -rf "$TEMP_DIR"
rm -rf "$HOME_DIR/SDK_RetroGames"

chown -R $USUARIO:$USUARIO "$RUTA_PROYECTO"
echo "Archivos copiados con éxito!"
echo ""

# 10. Permisos para mount, umount y shutdown sin contraseña
echo ""
echo ""
echo "==================================================="
echo "Configurando permisos USB y shutdown..."

echo "$USUARIO ALL=(ALL) NOPASSWD: /bin/mount, /bin/umount, /sbin/shutdown" | sudo tee /etc/sudoers.d/consola_retro
sudo chmod 440 /etc/sudoers.d/consola_retro

echo "Permisos configurados con éxito!"
echo ""

# 11. Hacer que el programa se ejecute al encender con cron
echo ""
echo ""
echo "==================================================="
echo "Aplicando configuracion de arranque automatico...."

# Verificar que el script existe
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "Error: El archivo $PYTHON_SCRIPT no existe."
    exit 1
fi

# Crear archivo de log
touch "$LOG_FILE"
chown $USUARIO:$USUARIO "$LOG_FILE"

# Agregar arranque con cron incluyendo variables SDL
CRON_CMD="@reboot export SDL_VIDEODRIVER=kmsdrm && export SDL_AUDIODRIVER=alsa && cd $RUTA_SRC && python3 $PYTHON_SCRIPT >> $LOG_FILE 2>&1"

if crontab -u $USUARIO -l 2>/dev/null | grep -q "$PYTHON_SCRIPT"; then
    echo "Cron ya está configurado para ejecutar $PYTHON_SCRIPT al inicio."
else
    (crontab -u $USUARIO -l 2>/dev/null; echo "$CRON_CMD") | crontab -u $USUARIO -
    echo "Configuración de cron agregada para ejecutar $PYTHON_SCRIPT al inicio."
fi
echo "¡Listo! configuracion de autoarranque hecha"

# 12. Copiar configuracion inicial de mednafen
echo ""
echo ""
echo "==================================================="
echo "Aplicando la configuracion de Mednafen...."

# Correr mednafen como usuario normal para generar cfg con permisos correctos
echo "Generando configuración base de mednafen..."
sudo -u $USUARIO /usr/games/mednafen &
MEDNAFEN_PID=$!
sleep 10
kill $MEDNAFEN_PID 2>/dev/null
wait $MEDNAFEN_PID 2>/dev/null

# Copiar cfg con controles Xbox como usuario normal
# Esto evita el error de permisos que ocurre cuando root copia el archivo
if [ -f "$RUTA_SRC/config/mednafen/mednafen.cfg" ]; then
    sudo -u $USUARIO cp "$RUTA_SRC/config/mednafen/mednafen.cfg" "$HOME_DIR/.mednafen/mednafen.cfg"
    sudo chown -R $USUARIO:$USUARIO "$HOME_DIR/.mednafen/"
    sudo chmod 755 "$HOME_DIR/.mednafen/"
    sudo chmod 644 "$HOME_DIR/.mednafen/mednafen.cfg"
    echo "mednafen.cfg con controles Xbox Series copiado."
else
    echo "ADVERTENCIA: No se encontró mednafen.cfg"
fi

# 13. Configurar variables de entorno SDL en .bashrc
echo ""
echo ""
echo "==================================================="
echo "Configurando variables SDL..."

if ! grep -q "SDL_VIDEODRIVER" "$HOME_DIR/.bashrc"; then
    echo "" >> "$HOME_DIR/.bashrc"
    echo "# Variables para pygame en Raspbian Lite sin escritorio" >> "$HOME_DIR/.bashrc"
    echo "export SDL_VIDEODRIVER=kmsdrm" >> "$HOME_DIR/.bashrc"
    echo "export SDL_AUDIODRIVER=alsa" >> "$HOME_DIR/.bashrc"
    echo "Variables SDL agregadas a .bashrc"
else
    echo "Variables SDL ya existen en .bashrc"
fi

# 14. Configurar login automático
echo ""
echo ""
echo "==================================================="
echo "Configurando login automático..."

sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null << AUTOLOGIN
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USUARIO --noclear %I \$TERM
AUTOLOGIN

sudo systemctl daemon-reload
echo "Login automático configurado para $USUARIO."

# 15. Modificar cmdline.txt para ocultar mensajes de arranque
echo ""
echo ""
echo "==================================================="
echo "Modificando cmdline.txt para ocultar mensajes..."

CMDLINE="/boot/firmware/cmdline.txt"
if [ ! -f "$CMDLINE" ]; then
    CMDLINE="/boot/cmdline.txt"
fi

if [ -f "$CMDLINE" ]; then
    if ! grep -q "quiet loglevel=0 logo.nologo fsck.mode=skip" "$CMDLINE"; then
        sudo sed -i 's/$/ quiet loglevel=0 logo.nologo fsck.mode=skip rd.systemd.show_status=false rd.udev.log_level=3/' "$CMDLINE"
        echo "Parámetros agregados a cmdline.txt"
    else
        echo "Los parámetros ya existen en cmdline.txt"
    fi
fi

# Suprimir mensajes de bienvenida de Debian
sudo truncate -s 0 /etc/motd
sudo truncate -s 0 /etc/issue
sudo truncate -s 0 /etc/issue.net
sudo sed -i 's/^#PrintLastLog=yes/PrintLastLog=no/' /etc/systemd/logind.conf
sudo sed -i 's/^PrintLastLog=yes/PrintLastLog=no/' /etc/systemd/logind.conf

# 16. Mostrar mensaje de salida
echo ""
echo "================================================="
echo " INSTALACIÓN COMPLETADA SATISFACTORIAMENTE! "
echo "================================================="
echo ""
echo "Para ver errores: cat $LOG_FILE"
echo ""
echo "El sistema se reiniciará en 10 segundos..."
sleep 10
sudo reboot
