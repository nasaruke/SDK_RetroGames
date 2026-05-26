"""
usb_monitor.py — Monitoreo y copia de ROMs desde USB.
Usa un hilo separado con pyudev para detectar USB en cualquier momento,
incluso mientras mednafen está corriendo.
"""

import os
import shutil
import glob
import subprocess
import threading
import time


class MonitorUSB:

    EXTENSIONES_POR_CONSOLA = {
        "nes":  [".nes"],
        "snes": [".smc", ".sfc"],
        "gba":  [".gba"],
    }

    PUNTO_MONTAJE = "/media/pi/usb_retro"

    DISPOSITIVOS_USB = [
        "/dev/sda1", "/dev/sda",
        "/dev/sdb1", "/dev/sdb",
        "/dev/sdc1", "/dev/sdc",
    ]

    def __init__(self, punto_montaje: str = "/media/pi"):
        self.punto_montaje       = self.PUNTO_MONTAJE
        self._usb_nuevo          = False
        self._lock               = threading.Lock()
        self._dispositivo_actual = None
        self._emulador_ref       = None
        self._ruta_roms          = None

        # Crear carpeta de montaje si no existe
        os.makedirs(self.PUNTO_MONTAJE, exist_ok=True)

        # Iniciar hilo de monitoreo en segundo plano
        self._hilo = threading.Thread(
            target=self._monitorear_udev,
            daemon=True
        )
        self._hilo.start()
        print("[MonitorUSB] Hilo de monitoreo iniciado")

    def set_emulador(self, emulador, ruta_roms: str):
        """
        Registra referencia al emulador y ruta de ROMs.
        Necesario para cerrar mednafen si se detecta USB durante el juego.
        """
        self._emulador_ref = emulador
        self._ruta_roms    = ruta_roms

    def hay_nuevo_usb(self) -> bool:
        """
        Devuelve True si hay USB nuevo listo para procesar.
        Llamado por la galería en cada frame.
        """
        with self._lock:
            if self._usb_nuevo:
                self._usb_nuevo = False
                return True
        return False

    def copiar_roms_de_usb(self, ruta_roms_local: str) -> int:
        """
        Copia ROMs del USB montado al proyecto evitando duplicados.
        Desmonta el USB al terminar.
        """
        total = 0

        if not os.path.exists(self.PUNTO_MONTAJE):
            print("[MonitorUSB] Punto de montaje no existe")
            return 0

        for consola, extensiones in self.EXTENSIONES_POR_CONSOLA.items():
            roms_en_usb = self._buscar_archivos(self.PUNTO_MONTAJE, extensiones)
            destino     = os.path.join(ruta_roms_local, consola)
            os.makedirs(destino, exist_ok=True)
            ya_existen  = {f.lower() for f in os.listdir(destino)}

            for ruta_rom in roms_en_usb:
                nombre = os.path.basename(ruta_rom)
                if nombre.lower() in ya_existen:
                    print(f"[MonitorUSB] Duplicado omitido: {nombre}")
                    continue
                shutil.copy2(ruta_rom, os.path.join(destino, nombre))
                ya_existen.add(nombre.lower())
                total += 1
                print(f"[MonitorUSB] Copiada: {nombre}")

        self._desmontar()
        return total

    # ------------------------------------------------------------------ #
    #  Hilo de monitoreo                                                   #
    # ------------------------------------------------------------------ #

    def _monitorear_udev(self):
        """
        Corre en segundo plano escuchando eventos USB con pyudev.
        Si pyudev no está disponible usa polling cada 2 segundos.
        """
        try:
            import pyudev
            context = pyudev.Context()
            monitor = pyudev.Monitor.from_netlink(context)
            monitor.filter_by(subsystem='block', device_type='partition')

            print("[MonitorUSB] Escuchando eventos USB con pyudev...")

            for device in iter(monitor.poll, None):
                if device.action == 'add':
                    print(f"[MonitorUSB] Dispositivo detectado: {device.device_node}")
                    time.sleep(1)

                    if self._montar(device.device_node):
                        # Si mednafen está corriendo cerrarlo primero
                        if self._emulador_ref and self._emulador_ref.proceso:
                            print("[MonitorUSB] Cerrando mednafen para copiar ROMs...")
                            self._emulador_ref.proceso.terminate()
                            self._emulador_ref.proceso.wait()
                            self._emulador_ref.proceso = None
                            time.sleep(0.5)

                        with self._lock:
                            self._usb_nuevo = True

                elif device.action == 'remove':
                    print("[MonitorUSB] USB desconectado")

        except ImportError:
            print("[MonitorUSB] pyudev no disponible, usando polling...")
            self._monitorear_polling()

    def _monitorear_polling(self):
        """
        Fallback sin pyudev.
        Revisa cada 2 segundos si hay dispositivos nuevos en /dev/sd*.
        """
        vistos = set(self._listar_dispositivos_dev())

        while True:
            time.sleep(2)
            actuales = set(self._listar_dispositivos_dev())
            nuevos   = actuales - vistos

            if nuevos:
                vistos = actuales
                for dispositivo in nuevos:
                    time.sleep(1)
                    if self._montar(dispositivo):
                        if self._emulador_ref and self._emulador_ref.proceso:
                            print("[MonitorUSB] Cerrando mednafen para copiar ROMs...")
                            self._emulador_ref.proceso.terminate()
                            self._emulador_ref.proceso.wait()
                            self._emulador_ref.proceso = None
                            time.sleep(0.5)

                        with self._lock:
                            self._usb_nuevo = True
                        break

    # ------------------------------------------------------------------ #
    #  Métodos internos                                                    #
    # ------------------------------------------------------------------ #

    def _listar_dispositivos_dev(self) -> list:
        """Lista dispositivos de bloque USB en /dev/sd*."""
        return [d for d in self.DISPOSITIVOS_USB if os.path.exists(d)]

    def _montar(self, dispositivo: str) -> bool:
        """Monta el dispositivo USB en PUNTO_MONTAJE."""
        try:
            resultado = subprocess.run(
                ["mountpoint", "-q", self.PUNTO_MONTAJE],
                capture_output=True
            )
            if resultado.returncode == 0:
                return True

            subprocess.run(
                ["sudo", "mount", "-o", "ro", dispositivo, self.PUNTO_MONTAJE],
                check=True, capture_output=True
            )
            print(f"[MonitorUSB] Montado: {dispositivo} → {self.PUNTO_MONTAJE}")
            self._dispositivo_actual = dispositivo
            return True

        except subprocess.CalledProcessError as e:
            print(f"[MonitorUSB] Error al montar {dispositivo}: {e}")
            return False

    def _desmontar(self):
        """Desmonta el USB después de copiar."""
        try:
            subprocess.run(
                ["sudo", "umount", self.PUNTO_MONTAJE],
                check=True, capture_output=True
            )
            print("[MonitorUSB] USB desmontado")
        except subprocess.CalledProcessError as e:
            print(f"[MonitorUSB] Error al desmontar: {e}")

    def _buscar_archivos(self, ruta_base: str, extensiones: list) -> list:
        """Busca recursivamente archivos con las extensiones dadas."""
        encontrados = []
        for ext in extensiones:
            encontrados.extend(
                glob.glob(os.path.join(ruta_base, "**", f"*{ext}"), recursive=True)
            )
        return encontrados