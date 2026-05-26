"""
entrada.py — Captura de entrada del gamepad / joystick.
Mapea botones físicos a acciones lógicas. Funciona con o sin control conectado.
"""

import pygame

ACCION_NINGUNA   = "NINGUNA"
ACCION_ARRIBA    = "ARRIBA"
ACCION_ABAJO     = "ABAJO"
ACCION_IZQUIERDA = "IZQUIERDA"
ACCION_DERECHA   = "DERECHA"
ACCION_CONFIRMAR = "CONFIRMAR"
ACCION_ATRAS     = "ATRAS"
ACCION_INICIO    = "INICIO"


class Entrada:

    MAPA_BOTONES = {
        0: ACCION_CONFIRMAR,
        1: ACCION_ATRAS,
        7: ACCION_INICIO,
    }
    UMBRAL_EJE = 0.5

    def __init__(self):
        pygame.joystick.init()
        cantidad = pygame.joystick.get_count()
        if cantidad > 0:
            self.joystick = pygame.joystick.Joystick(0)
            self.joystick.init()
            print(f"[Entrada] Gamepad conectado: {self.joystick.get_name()}")
        else:
            self.joystick = None
            print("[Entrada] Sin gamepad — usando teclado para pruebas.")

    def leer(self) -> str:
        # pump() es esencial para que pygame procese su cola interna
        # sin esto la ventana se congela aunque no haya gamepad
        pygame.event.pump()

        for evento in pygame.event.get():

            if evento.type == pygame.QUIT:
                return ACCION_ATRAS

            # Teclado — siempre activo con o sin gamepad
            if evento.type == pygame.KEYDOWN:
                return self._tecla_a_accion(evento.key)

            # Control conectado en caliente
            if evento.type == pygame.JOYDEVICEADDED:
                self.joystick = pygame.joystick.Joystick(evento.device_index)
                self.joystick.init()
                print(f"[Entrada] Gamepad conectado: {self.joystick.get_name()}")

            # Control desconectado en caliente
            if evento.type == pygame.JOYDEVICEREMOVED:
                self.joystick = None
                print("[Entrada] Gamepad desconectado — usando teclado.")

            if evento.type == pygame.JOYBUTTONDOWN:
                return self.MAPA_BOTONES.get(evento.button, ACCION_NINGUNA)

            if evento.type == pygame.JOYHATMOTION:
                return self._hat_a_accion(evento.value)

            if evento.type == pygame.JOYAXISMOTION:
                return self._eje_a_accion(evento.axis, evento.value)

        return ACCION_NINGUNA

    def _tecla_a_accion(self, tecla: int) -> str:
        mapa = {
            pygame.K_UP:     ACCION_ARRIBA,
            pygame.K_DOWN:   ACCION_ABAJO,
            pygame.K_LEFT:   ACCION_IZQUIERDA,
            pygame.K_RIGHT:  ACCION_DERECHA,
            pygame.K_RETURN: ACCION_CONFIRMAR,
            pygame.K_ESCAPE: ACCION_ATRAS,
            pygame.K_F1:     ACCION_INICIO,
        }
        return mapa.get(tecla, ACCION_NINGUNA)

    def _hat_a_accion(self, valor: tuple) -> str:
        x, y = valor
        if y == 1:  return ACCION_ARRIBA
        if y == -1: return ACCION_ABAJO
        if x == -1: return ACCION_IZQUIERDA
        if x == 1:  return ACCION_DERECHA
        return ACCION_NINGUNA

    def _eje_a_accion(self, eje: int, valor: float) -> str:
        if abs(valor) < self.UMBRAL_EJE:
            return ACCION_NINGUNA
        if eje == 0:
            return ACCION_DERECHA if valor > 0 else ACCION_IZQUIERDA
        if eje == 1:
            return ACCION_ABAJO if valor > 0 else ACCION_ARRIBA
        return ACCION_NINGUNA