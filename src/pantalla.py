"""
pantalla.py — Gestión de pantalla y renderizado.
Todo lo de pygame pasa por aquí; los demás módulos no llaman a pygame directamente.
"""

import pygame
import os


class Pantalla:

    def __init__(self, ancho: int, alto: int, pantalla_completa: bool = True):
        pygame.init()
        pygame.mixer.init()

        self.ancho = ancho
        self.alto  = alto

        bandera = pygame.FULLSCREEN if pantalla_completa else 0
        self.superficie = pygame.display.set_mode((ancho, alto), bandera)
        pygame.display.set_caption("Consola Retro SDK")

        self.fuente_grande  = pygame.font.SysFont("monospace", 52, bold=True)
        self.fuente_normal  = pygame.font.SysFont("monospace", 32)
        self.fuente_pequena = pygame.font.SysFont("monospace", 20)

        pygame.mouse.set_visible(False)

    def limpiar(self, color: tuple = (0, 0, 0)):
        self.superficie.fill(color)

    def dibujar_imagen(self, ruta: str, x: int, y: int, ancho: int = None, alto: int = None):
        if not os.path.exists(ruta):
            print(f"[Pantalla] Imagen no encontrada: {ruta}")
            return False
        imagen = pygame.image.load(ruta).convert_alpha()
        if ancho and alto:
            imagen = pygame.transform.scale(imagen, (ancho, alto))
        self.superficie.blit(imagen, (x, y))
        return True

    def dibujar_texto(self, texto: str, x: int, y: int,
                      color: tuple = (255, 255, 255),
                      fuente: str = "normal",
                      centrado: bool = False):
        mapa = {
            "grande":  self.fuente_grande,
            "normal":  self.fuente_normal,
            "pequena": self.fuente_pequena,
        }
        fuente_obj = mapa.get(fuente, self.fuente_normal)
        superficie_texto = fuente_obj.render(texto, True, color)
        if centrado:
            rect = superficie_texto.get_rect(center=(x, y))
            self.superficie.blit(superficie_texto, rect)
        else:
            self.superficie.blit(superficie_texto, (x, y))

    def dibujar_rectangulo(self, x: int, y: int, ancho: int, alto: int,
                           color: tuple, relleno: bool = True, grosor_borde: int = 2):
        rect = pygame.Rect(x, y, ancho, alto)
        if relleno:
            pygame.draw.rect(self.superficie, color, rect)
        else:
            pygame.draw.rect(self.superficie, color, rect, grosor_borde)

    def reproducir_sonido(self, ruta: str):
        if not os.path.exists(ruta):
            print(f"[Pantalla] Sonido no encontrado: {ruta}")
            return False
        sonido = pygame.mixer.Sound(ruta)
        sonido.play()
        return True

    def actualizar(self):
        pygame.display.flip()

    def cerrar(self):
        pygame.quit()