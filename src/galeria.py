"""
galeria.py — Menú principal con lista de ROMs y navegación por gamepad.
Loop principal del sistema. Start o Escape muestran confirmación de salida.
"""

import pygame
import os
import subprocess
from entrada import (
    ACCION_ARRIBA, ACCION_ABAJO, ACCION_CONFIRMAR, ACCION_ATRAS, ACCION_INICIO
)

COLOR_FONDO       = (15,  15,  20)
COLOR_TITULO      = (255, 200,  50)
COLOR_SELECCION   = (50,  150, 255)
COLOR_TEXTO       = (220, 220, 220)
COLOR_CONSOLA_TAG = (100, 255, 150)


class Galeria:

    CONSOLAS = {
        "nes":  [".nes"],
        "snes": [".smc", ".sfc"],
        "gba":  [".gba"],
    }

    ETIQUETAS = {
        "nes":  "Nintendo NES",
        "snes": "Super Nintendo",
        "gba":  "Game Boy Advance",
    }

    def __init__(self, pantalla, entrada, emulador, usb_monitor, ruta_roms: str):
        self.pantalla     = pantalla
        self.entrada      = entrada
        self.emulador     = emulador
        self.usb_monitor  = usb_monitor
        self.ruta_roms    = ruta_roms
        self.indice       = 0
        self.en_ejecucion = True
        self.catalogo     = self._escanear_roms()
        self.lista_plana  = self._aplanar_catalogo()

    def ejecutar(self):
        """Loop principal del menú."""
        reloj = pygame.time.Clock()
        while self.en_ejecucion:
            if self.usb_monitor.hay_nuevo_usb():
                self._manejar_usb_nuevo()
            accion = self.entrada.leer()
            self._procesar_accion(accion)
            self._dibujar()
            self.pantalla.actualizar()
            reloj.tick(30)

    def actualizar_catalogo(self):
        """Vuelve a escanear ROMs y reconstruye la lista."""
        self.catalogo    = self._escanear_roms()
        self.lista_plana = self._aplanar_catalogo()
        if self.indice >= len(self.lista_plana):
            self.indice = max(0, len(self.lista_plana) - 1)

    def _procesar_accion(self, accion: str):
        """Navega el menú o lanza el juego seleccionado."""
        if accion == ACCION_ARRIBA and self.indice > 0:
            self.indice -= 1

        elif accion == ACCION_ABAJO and self.indice < len(self.lista_plana) - 1:
            self.indice += 1

        elif accion == ACCION_CONFIRMAR and self.lista_plana:
            consola, nombre, ruta = self.lista_plana[self.indice]
            self.emulador.lanzar(consola, nombre, ruta)

        elif accion in (ACCION_INICIO, ACCION_ATRAS):
            if self._confirmar_salida():
                self.en_ejecucion = False
                # Apagar la Raspberry Pi completamente
                subprocess.run(["sudo", "shutdown", "-h", "now"])

    def _confirmar_salida(self) -> bool:
        """
        Muestra pantalla de confirmación antes de apagar.
        A para confirmar, B o Escape para cancelar.
        """
        reloj = pygame.time.Clock()

        while True:
            pygame.event.pump()
            for evento in pygame.event.get():
                if evento.type == pygame.JOYBUTTONDOWN:
                    if evento.button == 0:
                        return True
                    if evento.button == 1:
                        return False
                if evento.type == pygame.KEYDOWN:
                    if evento.key == pygame.K_RETURN:
                        return True
                    if evento.key == pygame.K_ESCAPE:
                        return False

            self.pantalla.limpiar(COLOR_FONDO)
            self.pantalla.dibujar_texto(
                "¿Salir de la consola?",
                x=self.pantalla.ancho // 2, y=self.pantalla.alto // 2 - 60,
                color=(255, 200, 50), fuente="grande", centrado=True
            )
            self.pantalla.dibujar_texto(
                "A  →  Sí, apagar",
                x=self.pantalla.ancho // 2, y=self.pantalla.alto // 2 + 20,
                color=(100, 255, 100), fuente="normal", centrado=True
            )
            self.pantalla.dibujar_texto(
                "B  →  No, volver al menú",
                x=self.pantalla.ancho // 2, y=self.pantalla.alto // 2 + 70,
                color=(255, 100, 100), fuente="normal", centrado=True
            )
            self.pantalla.actualizar()
            reloj.tick(30)

    def _dibujar(self):
        """Dibuja fondo, título y lista de juegos."""
        self.pantalla.limpiar(COLOR_FONDO)

        self.pantalla.dibujar_texto(
            "★  CONSOLA RETRO SDK  ★",
            x=self.pantalla.ancho // 2, y=40,
            color=COLOR_TITULO, fuente="grande", centrado=True
        )
        self.pantalla.dibujar_rectangulo(
            x=60, y=90, ancho=self.pantalla.ancho - 120, alto=2, color=COLOR_TITULO
        )

        if not self.lista_plana:
            self.pantalla.dibujar_texto(
                "Sin ROMs — agrega archivos a roms/nes, roms/snes o roms/gba",
                x=self.pantalla.ancho // 2, y=self.pantalla.alto // 2,
                color=(200, 80, 80), fuente="normal", centrado=True
            )
            return

        visible_max      = 14
        inicio           = max(0, self.indice - visible_max // 2)
        fin              = min(len(self.lista_plana), inicio + visible_max)
        y_pos            = 120
        paso             = (self.pantalla.alto - 180) // visible_max
        consola_anterior = None

        for i in range(inicio, fin):
            consola, nombre, _ = self.lista_plana[i]
            es_seleccionado    = (i == self.indice)

            if consola != consola_anterior:
                self.pantalla.dibujar_texto(
                    f"── {self.ETIQUETAS[consola]} ──",
                    x=80, y=y_pos, color=COLOR_CONSOLA_TAG, fuente="pequena"
                )
                y_pos += paso - 4
                consola_anterior = consola

            if es_seleccionado:
                self.pantalla.dibujar_rectangulo(
                    x=60, y=y_pos - 4,
                    ancho=self.pantalla.ancho - 120, alto=paso - 2,
                    color=COLOR_SELECCION
                )
                color_texto = (0, 0, 0)
            else:
                color_texto = COLOR_TEXTO

            self.pantalla.dibujar_texto(
                f"  {os.path.splitext(nombre)[0]}",
                x=80, y=y_pos, color=color_texto, fuente="normal"
            )
            y_pos += paso

        self.pantalla.dibujar_texto(
            "↑↓ Navegar    A Jugar    Start Salir",
            x=self.pantalla.ancho // 2, y=self.pantalla.alto - 30,
            color=(120, 120, 120), fuente="pequena", centrado=True
        )

    def _manejar_usb_nuevo(self):
        """Pausa el menú, copia ROMs del USB y recarga el catálogo."""
        self.pantalla.limpiar(COLOR_FONDO)
        self.pantalla.dibujar_texto(
            "USB detectado — copiando ROMs...",
            x=self.pantalla.ancho // 2, y=self.pantalla.alto // 2,
            color=COLOR_TITULO, fuente="normal", centrado=True
        )
        self.pantalla.actualizar()
        nuevas = self.usb_monitor.copiar_roms_de_usb(self.ruta_roms)
        self.pantalla.limpiar(COLOR_FONDO)
        self.pantalla.dibujar_texto(
            f"{nuevas} ROMs nuevas añadidas",
            x=self.pantalla.ancho // 2, y=self.pantalla.alto // 2,
            color=COLOR_CONSOLA_TAG, fuente="normal", centrado=True
        )
        self.pantalla.actualizar()
        pygame.time.wait(2000)
        self.actualizar_catalogo()

    def _escanear_roms(self) -> dict:
        """Escanea carpeta de ROMs y devuelve dict por consola."""
        catalogo = {}
        for consola, extensiones in self.CONSOLAS.items():
            carpeta = os.path.join(self.ruta_roms, consola)
            if not os.path.isdir(carpeta):
                catalogo[consola] = []
                continue
            catalogo[consola] = sorted([
                f for f in os.listdir(carpeta)
                if os.path.splitext(f)[1].lower() in extensiones
            ])
        return catalogo

    def _aplanar_catalogo(self) -> list:
        """Convierte el dict de catálogo en lista plana para navegación."""
        lista = []
        for consola, roms in self.catalogo.items():
            for nombre in roms:
                ruta = os.path.join(self.ruta_roms, consola, nombre)
                lista.append((consola, nombre, ruta))
        return lista
