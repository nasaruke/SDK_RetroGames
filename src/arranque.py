"""
arranque.py — Secuencia de arranque.
Muestra logo_SDK.png con fade-in y reproduce entrada_coin.wav.
"""

import pygame
import os


class Arranque:

    COLOR_FONDO = (0, 0, 0)

    def __init__(self, pantalla, ruta_logo: str, ruta_sonido: str, duracion_fade: float = 1.5):
        self.pantalla      = pantalla
        self.ruta_logo     = ruta_logo
        self.ruta_sonido   = ruta_sonido
        self.duracion_fade = duracion_fade

    def ejecutar(self):
        if not os.path.exists(self.ruta_logo):
            print(f"[Arranque] Logo no encontrado: {self.ruta_logo}")
            return

        logo = pygame.image.load(self.ruta_logo).convert_alpha()

        # Escalar logo al 50% del ancho manteniendo proporción
        escala     = self.pantalla.ancho // 2
        proporcion = logo.get_height() / logo.get_width()
        logo       = pygame.transform.scale(logo, (escala, int(escala * proporcion)))

        pos_x = (self.pantalla.ancho  - logo.get_width())  // 2
        pos_y = (self.pantalla.alto   - logo.get_height()) // 2

        self.pantalla.reproducir_sonido(self.ruta_sonido)

        self._fade(logo, pos_x, pos_y, direccion="in")

        # Pausa 2 segundos cancelable con Escape
        reloj = pygame.time.Clock()
        for _ in range(120):
            for evento in pygame.event.get():
                if evento.type == pygame.QUIT:
                    self.pantalla.cerrar()
                    raise SystemExit
                if evento.type == pygame.KEYDOWN and evento.key == pygame.K_ESCAPE:
                    return
            reloj.tick(60)

        self._fade(logo, pos_x, pos_y, direccion="out")

    def _fade(self, logo, pos_x, pos_y, direccion="in"):
        reloj = pygame.time.Clock()
        pasos = int(self.duracion_fade * 60)

        for i in range(pasos + 1):
            # Escape durante el fade
            for evento in pygame.event.get():
                if evento.type == pygame.QUIT:
                    self.pantalla.cerrar()
                    raise SystemExit
                if evento.type == pygame.KEYDOWN and evento.key == pygame.K_ESCAPE:
                    return

            progreso   = i / pasos
            alpha      = int(255 * progreso) if direccion == "in" else int(255 * (1 - progreso))
            logo_alpha = logo.copy()
            logo_alpha.set_alpha(alpha)

            self.pantalla.limpiar(self.COLOR_FONDO)
            self.pantalla.superficie.blit(logo_alpha, (pos_x, pos_y))
            self.pantalla.actualizar()
            reloj.tick(60)