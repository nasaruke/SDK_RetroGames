"""
emulador.py — Lanzamiento del emulador.
Muestra la imagen de controles de la consola y lanza mednafen.
"""

import subprocess
import time
import pygame
import os


class Emulador:

    IMAGENES_CONTROLES = {
        "nes":  "controles_NES.png",
        "snes": "controles_SNES.png",
        "gba":  "controles_GBA.png",
    }

    FLAGS_MEDNAFEN = {
        "nes":  ["-force_module", "nes"],
        "snes": ["-force_module", "snes"],
        "gba":  ["-force_module", "gba"],
    }

    COLOR_FONDO = (10, 10, 20)

    def __init__(self, pantalla, ruta_imagenes: str, mapa_emuladores: dict, duracion_controles: float = 4.0):
        self.pantalla           = pantalla
        self.ruta_imagenes      = ruta_imagenes
        self.mapa_emuladores    = mapa_emuladores
        self.duracion_controles = duracion_controles
        self.proceso            = None  # Referencia al proceso de mednafen

    def lanzar(self, consola: str, nombre_rom: str, ruta_rom: str):
        """
        Flujo completo para iniciar un juego:
            1. Mostrar pantalla de controles.
            2. Cerrar display de pygame para liberar pantalla.
            3. Lanzar mednafen y esperar a que termine.
            4. Reiniciar display de pygame al regresar.
        """
        # Mostrar pantalla de controles — False significa que el usuario canceló
        if not self._mostrar_controles(consola, nombre_rom):
            return

        ejecutable = self.mapa_emuladores.get(consola, "mednafen")
        flags      = self.FLAGS_MEDNAFEN.get(consola, [])
        comando    = [ejecutable] + flags + [ruta_rom]

        print(f"[Emulador] Lanzando: {' '.join(comando)}")

        try:
            # Detener audio y cerrar SOLO el display (igual que el Code.py del equipo)
            # Esto libera la pantalla para que mednafen pueda tomarla
            pygame.mixer.stop()
            pygame.display.quit()

            # Lanzar mednafen como proceso — bloquea hasta que el usuario cierre el juego
            self.proceso = subprocess.Popen(comando)
            self.proceso.wait()  # Esperar a que mednafen termine

        except FileNotFoundError:
            print(f"[Emulador] Error: '{ejecutable}' no encontrado.")

        finally:
            self.proceso = None

            # Reiniciar SOLO el display al regresar — igual que Code.py
            pygame.display.init()
            self.pantalla.superficie = pygame.display.set_mode(
                (self.pantalla.ancho, self.pantalla.alto),
                pygame.FULLSCREEN
            )
            pygame.mouse.set_visible(False)

    def _mostrar_controles(self, consola: str, nombre_rom: str) -> bool:
        """
        Muestra imagen de controles y espera que el usuario presione un botón.
        Devuelve True para jugar, False si presionó Escape para cancelar.
        """
        imagen_nombre = self.IMAGENES_CONTROLES.get(consola)
        ruta_imagen   = os.path.join(self.ruta_imagenes, imagen_nombre) if imagen_nombre else None

        reloj       = pygame.time.Clock()
        parpadeo    = True
        ultimo_flip = 0

        while True:
            ahora = time.time()

            pygame.event.pump()
            for evento in pygame.event.get():
                if evento.type == pygame.JOYBUTTONDOWN:
                    return True
                if evento.type == pygame.KEYDOWN:
                    if evento.key == pygame.K_ESCAPE:
                        return False
                    return True

            if ahora - ultimo_flip > 0.5:
                parpadeo    = not parpadeo
                ultimo_flip = ahora

                self.pantalla.limpiar(self.COLOR_FONDO)

                nombre_sin_ext = os.path.splitext(nombre_rom)[0]
                self.pantalla.dibujar_texto(
                    nombre_sin_ext,
                    x=self.pantalla.ancho // 2, y=30,
                    color=(255, 200, 50), fuente="grande", centrado=True
                )

                if ruta_imagen and os.path.exists(ruta_imagen):
                    ancho_img = int(self.pantalla.ancho * 0.75)
                    alto_img  = int(self.pantalla.alto  * 0.65)
                    pos_x     = (self.pantalla.ancho - ancho_img) // 2
                    self.pantalla.dibujar_imagen(ruta_imagen, pos_x, 100, ancho_img, alto_img)
                else:
                    self.pantalla.dibujar_texto(
                        f"Controles — {consola.upper()}",
                        x=self.pantalla.ancho // 2, y=self.pantalla.alto // 2,
                        color=(200, 200, 200), fuente="normal", centrado=True
                    )

                if parpadeo:
                    self.pantalla.dibujar_texto(
                        ">> Presiona A para jugar  |  Escape para volver <<",
                        x=self.pantalla.ancho // 2, y=self.pantalla.alto - 40,
                        color=(50, 255, 50), fuente="normal", centrado=True
                    )

                self.pantalla.actualizar()

            reloj.tick(30)

    def _mostrar_error(self, mensaje: str):
        """Muestra un mensaje de error en pantalla durante 3 segundos."""
        self.pantalla.limpiar(self.COLOR_FONDO)
        y = self.pantalla.alto // 2 - 40
        for linea in mensaje.split("\n"):
            self.pantalla.dibujar_texto(
                linea,
                x=self.pantalla.ancho // 2, y=y,
                color=(255, 80, 80), fuente="normal", centrado=True
            )
            y += 50
        self.pantalla.actualizar()
        time.sleep(3)