"""
main.py — Punto de entrada de la Consola Retro SDK.

Este es el ÚNICO archivo que se debe ejecutar:
    python3 main.py
"""

import json
import os
import sys
import shutil

from pantalla    import Pantalla
from entrada     import Entrada
from arranque    import Arranque
from emulador    import Emulador
from usb_monitor import MonitorUSB
from galeria     import Galeria

RUTA_BASE = os.path.dirname(os.path.abspath(__file__))


def _instalar_config_mednafen():
    """Copia mednafen.cfg al lugar correcto al arrancar."""
    origen      = os.path.join(RUTA_BASE, "config", "mednafen", "mednafen.cfg")
    destino_dir = os.path.expanduser("~/.mednafen")
    destino     = os.path.join(destino_dir, "mednafen.cfg")
    if not os.path.exists(origen):
        print(f"[main] Advertencia: config de mednafen no encontrada")
        return
    os.makedirs(destino_dir, exist_ok=True)
    shutil.copy2(origen, destino)
    print(f"[main] Config de mednafen instalada")


def cargar_configuracion(ruta_config: str) -> dict:
    """Lee el JSON de configuración del sistema."""
    if not os.path.exists(ruta_config):
        print(f"[main] ERROR: {ruta_config} no encontrado")
        sys.exit(1)
    with open(ruta_config, "r", encoding="utf-8") as archivo:
        try:
            return json.load(archivo)
        except json.JSONDecodeError as e:
            print(f"[main] ERROR en configuracion.json: {e}")
            sys.exit(1)


def construir_ruta(config: dict, *claves) -> str:
    """Construye ruta absoluta desde la configuración."""
    valor = config
    for clave in claves:
        valor = valor[clave]
    return os.path.join(RUTA_BASE, valor)


def main():
    # 1. Instalar config de mednafen
    _instalar_config_mednafen()

    # 2. Cargar configuración
    ruta_config = os.path.join(RUTA_BASE, "config", "configuracion.json")
    config      = cargar_configuracion(ruta_config)

    cfg_pantalla   = config["pantalla"]
    cfg_emuladores = config["emuladores"]

    # 3. Instanciar módulos
    pantalla = Pantalla(
        ancho             = cfg_pantalla["ancho"],
        alto              = cfg_pantalla["alto"],
        pantalla_completa = cfg_pantalla["pantalla_completa"]
    )

    entrada     = Entrada()
    usb_monitor = MonitorUSB()

    emulador = Emulador(
        pantalla           = pantalla,
        ruta_imagenes      = construir_ruta(config, "rutas", "imagenes"),
        mapa_emuladores    = cfg_emuladores,
        duracion_controles = 4.0
    )

    # Pasar referencia del emulador al monitor USB
    # para que pueda cerrar mednafen si detecta un USB mientras se juega
    ruta_roms = construir_ruta(config, "rutas", "roms")
    usb_monitor.set_emulador(emulador, ruta_roms)

    galeria = Galeria(
        pantalla    = pantalla,
        entrada     = entrada,
        emulador    = emulador,
        usb_monitor = usb_monitor,
        ruta_roms   = ruta_roms
    )

    # 4. Arranque
    arranque = Arranque(
        pantalla    = pantalla,
        ruta_logo   = os.path.join(construir_ruta(config, "rutas", "imagenes"), "logo_SDK.png"),
        ruta_sonido = os.path.join(construir_ruta(config, "rutas", "sonidos"), "entrada_coin.wav"),
        duracion_fade = 1.5
    )
    arranque.ejecutar()

    # 5. Loop principal
    try:
        galeria.ejecutar()
    except KeyboardInterrupt:
        print("\n[main] Salida por teclado.")
    finally:
        pantalla.cerrar()
        print("[main] Sistema cerrado correctamente.")


if __name__ == "__main__":
    main()