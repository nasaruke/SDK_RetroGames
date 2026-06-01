#!/bin/bash
set -euo pipefail

clear || true

echo ""
echo "==================================================="
echo "  INSTALACIÓN CONSOLA RETRO SDK EN RASPBERRY PI"
echo "==================================================="
echo ""

if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER:-}" != "root" ]; then
    USUARIO="$SUDO_USER"
else
    USUARIO="$(logname 2>/dev/null || echo pi)"
fi

HOME_DIR="/home/$USUARIO"
RUTA_PROYECTO="$HOME_DIR/consola_retro"
RUTA_SRC="$RUTA_PROYECTO/src"
PYTHON_SCRIPT="$RUTA_SRC/main.py"
LOG_FILE="$HOME_DIR/consola_retro.log"
SERVICE_FILE="/etc/systemd/system/consola-retro.service"

if [ ! -d "$HOME_DIR" ]; then
    echo "ERROR: No existe $HOME_DIR. Usuario detectado: $USUARIO"
    exit 1
fi

run_step() {
    local nombre="$1"
    shift
    echo ""
    echo "==================================================="
    echo "$nombre"
    echo "==================================================="
    "$@"
}

run_step "Actualizando sistema base" apt update
run_step "Instalando paquetes base" apt install -y git curl unzip python3 python3-pip python3-dev

run_step "Instalando dependencias SDL" apt install -y \
    libsdl2-2.0-0 \
    libsdl2-dev \
    libsdl2-mixer-dev \
    libsdl2-image-dev \
    libsdl2-ttf-dev

run_step "Instalando Pygame y PyUDEV" apt install -y python3-pygame python3-pyudev
run_step "Instalando Mednafen" apt install -y mednafen

if [ -x /usr/games/mednafen ]; then
    ln -sf /usr/games/mednafen /usr/local/bin/mednafen
elif command -v mednafen >/dev/null 2>&1; then
    ln -sf "$(command -v mednafen)" /usr/local/bin/mednafen
else
    echo "ERROR: Mednafen no quedó instalado correctamente."
    exit 1
fi

run_step "Agregando usuario a grupos video/audio/input/render" usermod -aG video,audio,input,render "$USUARIO"

echo ""
echo "==================================================="
echo "Creando estructura de directorios"
echo "==================================================="

mkdir -p "$RUTA_SRC/roms/nes"
mkdir -p "$RUTA_SRC/roms/snes"
mkdir -p "$RUTA_SRC/roms/gba"
mkdir -p "$HOME_DIR/.mednafen"
mkdir -p /media/pi/usb_retro

chown -R "$USUARIO:$USUARIO" "$RUTA_PROYECTO" "$HOME_DIR/.mednafen" /media/pi

echo ""
echo "==================================================="
echo "Descargando código fuente"
echo "==================================================="

rm -rf "$HOME_DIR/SDK_RetroGames"

sudo -u "$USUARIO" git clone --branch main --single-branch \
    https://github.com/nasaruke/SDK_RetroGames.git "$HOME_DIR/SDK_RetroGames"

cp "$HOME_DIR/SDK_RetroGames/src/"*.py "$RUTA_SRC/"
cp "$HOME_DIR/SDK_RetroGames/src/"*.sh "$RUTA_SRC/" 2>/dev/null || true

chown -R "$USUARIO:$USUARIO" "$RUTA_PROYECTO"

echo ""
echo "==================================================="
echo "Descargando assets, configuración y ROMs"
echo "==================================================="

REPO_RAW="https://raw.githubusercontent.com/nasaruke/SDK_RetroGames/instalaciones"
TEMP_DIR="$HOME_DIR/temp_instalacion"

rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
chown -R "$USUARIO:$USUARIO" "$TEMP_DIR"

curl -fL "$REPO_RAW/assets.zip" -o "$TEMP_DIR/assets.zip"
curl -fL "$REPO_RAW/config.zip" -o "$TEMP_DIR/config.zip"
curl -fL "$REPO_RAW/nes.zip" -o "$TEMP_DIR/nes.zip"
curl -fL "$REPO_RAW/snes.zip" -o "$TEMP_DIR/snes.zip"
curl -fL "$REPO_RAW/gba.zip" -o "$TEMP_DIR/gba.zip"

unzip -oq "$TEMP_DIR/assets.zip" -d "$RUTA_SRC/"
unzip -oq "$TEMP_DIR/config.zip" -d "$RUTA_SRC/"
unzip -oq "$TEMP_DIR/nes.zip" -d "$RUTA_SRC/roms/"
unzip -oq "$TEMP_DIR/snes.zip" -d "$RUTA_SRC/roms/"
unzip -oq "$TEMP_DIR/gba.zip" -d "$RUTA_SRC/roms/"

rm -rf "$TEMP_DIR" "$HOME_DIR/SDK_RetroGames"

chown -R "$USUARIO:$USUARIO" "$RUTA_PROYECTO"

echo ""
echo "==================================================="
echo "Configurando permisos sudo para USB y apagado"
echo "==================================================="

cat > /etc/sudoers.d/consola_retro <<SUDOERS
$USUARIO ALL=(ALL) NOPASSWD: /bin/mount, /bin/umount, /usr/bin/mount, /usr/bin/umount, /sbin/shutdown, /usr/sbin/shutdown
SUDOERS

chmod 440 /etc/sudoers.d/consola_retro

echo ""
echo "==================================================="
echo "Configurando Mednafen"
echo "==================================================="

sudo -u "$USUARIO" env HOME="$HOME_DIR" /usr/local/bin/mednafen >/tmp/mednafen_init.log 2>&1 &
MEDNAFEN_PID=$!

sleep 3

kill "$MEDNAFEN_PID" 2>/dev/null || true
wait "$MEDNAFEN_PID" 2>/dev/null || true

mkdir -p "$HOME_DIR/.mednafen"

if [ -f "$RUTA_SRC/config/mednafen/mednafen.cfg" ]; then
    cp "$RUTA_SRC/config/mednafen/mednafen.cfg" "$HOME_DIR/.mednafen/mednafen.cfg"
    echo "mednafen.cfg copiado."
else
    echo "ADVERTENCIA: No se encontró $RUTA_SRC/config/mednafen/mednafen.cfg"
fi

chown -R "$USUARIO:$USUARIO" "$HOME_DIR/.mednafen"
chmod 755 "$HOME_DIR/.mednafen"

if [ -f "$HOME_DIR/.mednafen/mednafen.cfg" ]; then
    chmod 644 "$HOME_DIR/.mednafen/mednafen.cfg"
fi

echo ""
echo "==================================================="
echo "Configurando variables SDL en .bashrc"
echo "==================================================="

if ! grep -q "SDL_VIDEODRIVER=kmsdrm" "$HOME_DIR/.bashrc" 2>/dev/null; then
    cat >> "$HOME_DIR/.bashrc" <<'BASHRC'

# Variables para Consola Retro SDK en Raspberry Pi OS Lite
export SDL_VIDEODRIVER=kmsdrm
export SDL_AUDIODRIVER=alsa
export PATH="$PATH:/usr/games:/usr/local/bin"
BASHRC
fi

chown "$USUARIO:$USUARIO" "$HOME_DIR/.bashrc"

echo ""
echo "==================================================="
echo "Configurando autoarranque con systemd"
echo "==================================================="

if crontab -u "$USUARIO" -l 2>/dev/null | grep -q "consola_retro\|main.py"; then
    crontab -u "$USUARIO" -l 2>/dev/null | grep -v "consola_retro\|main.py" | crontab -u "$USUARIO" -
    echo "Cron viejo eliminado."
else
    echo "No había cron viejo del proyecto."
fi

systemctl unmask consola-retro.service 2>/dev/null || true

touch "$LOG_FILE"
chown "$USUARIO:$USUARIO" "$LOG_FILE"
chmod 664 "$LOG_FILE"

if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "ERROR: No existe $PYTHON_SCRIPT"
    exit 1
fi

cat > "$SERVICE_FILE" <<SERVICE
[Unit]
Description=Consola Retro SDK
After=multi-user.target sound.target local-fs.target
Wants=sound.target
ConditionPathExists=!/boot/NO_CONSOLA
ConditionPathExists=!/boot/firmware/NO_CONSOLA

[Service]
Type=simple
User=$USUARIO
Group=$USUARIO
WorkingDirectory=$RUTA_SRC
Environment=HOME=$HOME_DIR
Environment=USER=$USUARIO
Environment=SDL_VIDEODRIVER=kmsdrm
Environment=SDL_AUDIODRIVER=alsa
Environment=PYTHONUNBUFFERED=1
Environment=PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:/usr/games
ExecStart=/usr/bin/python3 $PYTHON_SCRIPT
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable consola-retro.service

echo ""
echo "==================================================="
echo "Configurando tty2 para mantenimiento"
echo "==================================================="

systemctl enable getty@tty2.service 2>/dev/null || true

echo ""
echo "==================================================="
echo "Ocultando mensajes de arranque"
echo "==================================================="

CMDLINE="/boot/firmware/cmdline.txt"
if [ ! -f "$CMDLINE" ]; then
    CMDLINE="/boot/cmdline.txt"
fi

if [ -f "$CMDLINE" ]; then
    sed -i 's/ *init=\/bin\/bash//g' "$CMDLINE"

    for PARAM in \
        "quiet" \
        "loglevel=0" \
        "logo.nologo" \
        "vt.global_cursor_default=0" \
        "consoleblank=0" \
        "systemd.show_status=false" \
        "rd.systemd.show_status=false" \
        "udev.log_level=0" \
        "rd.udev.log_level=0" \
        "plymouth.ignore-serial-consoles"
    do
        if ! grep -qw "$PARAM" "$CMDLINE"; then
            sed -i "s/$/ $PARAM/" "$CMDLINE"
        fi
    done
fi

truncate -s 0 /etc/motd || true
truncate -s 0 /etc/issue || true
truncate -s 0 /etc/issue.net || true

mkdir -p /etc/systemd/system.conf.d
cat > /etc/systemd/system.conf.d/quiet.conf <<'EOF'
[Manager]
LogLevel=emerg
ShowStatus=no
EOF

cat > /etc/profile.d/hide_cursor.sh <<'EOF'
setterm -cursor off 2>/dev/null || true
EOF
chmod +x /etc/profile.d/hide_cursor.sh

sed -i 's/^#\?PrintLastLog.*/PrintLastLog no/' /etc/ssh/sshd_config 2>/dev/null || true
sed -i 's/^#\?PrintLastLog=.*/PrintLastLog=no/' /etc/systemd/logind.conf 2>/dev/null || true

echo ""
echo "==================================================="
echo " INSTALACIÓN COMPLETADA"
echo "==================================================="
echo ""
echo "Usuario: $USUARIO"
echo "Mednafen: $(command -v mednafen || true)"
echo "Servicio: $SERVICE_FILE"
echo "Log: $LOG_FILE"
echo ""
echo "Comandos útiles:"
echo "  Ver log:        cat $LOG_FILE"
echo "  Estado:         sudo systemctl status consola-retro.service"
echo "  Desactivar:     sudo systemctl disable --now consola-retro.service"
echo "  Activar:        sudo systemctl enable --now consola-retro.service"
echo "  Mantenimiento:  sudo touch /boot/NO_CONSOLA && sudo reboot"
echo "  Volver normal:  sudo rm /boot/NO_CONSOLA && sudo reboot"
echo ""
echo "El sistema se reiniciará en 10 segundos..."
sleep 10

reboot
