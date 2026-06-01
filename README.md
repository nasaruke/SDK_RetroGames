## 💻 Metodo de Instalacion
Para una correcta instalacion es necesario que se tengan dos cosas:
- Conexion por cable Ethernet a internet para la Raspberry
- Un Sistema sin entorno grafico y limpio dentro de la Raspberry Pi 4 usado para las pruebas fue Raspberry Pi OS Lite.

Todo archivo necesario para su correcto funcionamiento ya estan dentro de este GitHub por lo que no es necesario cambiar o agregar algun otro detalle, para que se inicialice la instalacion automaticamente dentro de la Raspberry solo es necesario teclear el siguiente comando:
  $ sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/nasaruke/SDK_RetroGames/main/src/instalar.sh)"

  **ADVERTENCIA: A la fecha de este Repositorio la consola funciona para un modelo de Raspberry Pi 4, puede que dentro de versiones antiguas o posteriores a este modelo presenten fallos en la instalacion.**
# Proyecto Final - Sistemas Embebidos

**Materia:** 	Fundamentos de Sistemas Embebidos 
**Semestre:**	2026-2
**Autores:**  
		- Carrillo Viña Sebastian  
		- Rosales Vigil Karla Sofia  
		- Sanchez Diaz Daniel    

## 📌 Descripción 
Este proyecto emula una consola de Videojuegos dentro de una Raspberry Pi 4 que puede correr juegos de tres consolas distintas.
	- Game Boy Advanced (GBA)
	- Nintendo Entertainment System (NES)
	- Super Nintendo Entertainment System (SNES)
Este proyecto puede tambien hacer una copia de las roms que se le pasen por USB automaticamente, ademas de ordenarlas de acuerdo a la consola que esten destinadas, uso de mando Xbox Series S/X y interrupcion de juegos por si se requiere cambiar.

## 🛠️ Hardware Utilizado  
- Imagen: Raspberry Pi OS Lite
- Microcontrolador: Raspberry Pi 4
- Gamepad: Control de Xbox Series S/X
- Monitor: Cualquier monitor con coneccion HDMI
- Audio: Bocinas externas con conexion jack de 3.5 mm 

## 📂 Estructura del Proyecto  
SDK_RetroGames/
├── README.md
├── LICENSE                               #Licencia
├── doc/                             #Carpeta con documentacion de cada uno de los integrantes del equipo
├── vid/                                  #Carpeta con vinculo a video del funcionamiento de la consola
└── src/
    ├── instalar.sh                           #Instalador que configura todo
    ├── main.py                               #Archivo principal de la consola
    ├── pantalla.py                           #Control de pantalla y audio
    ├── entrada.py                            #Lector y traduccion de control 
    ├── arranque.py                           #Inicializacion de la consola
    ├── galeria.py                            #Menu y navegacion por las ROMs
    ├── emulador.py                           #Ejecuta Mednafen para abrir juegos
    ├── usb_monitor.py                        #Deteccion de USB y ROMs
    ├── __init__.py                           #Archivo para organizar el proyecto
    ├── config/                               #Carpeta con configuracion general del sistema
    │   └── mednafen/                         #Carpeta con preconfiguracion de controles y del emulador
    ├── assets/                               #Carpeta con audio y imagenes 
    └── roms/
        ├── nes/      #Contiene los juegos de Nintendo
        ├── snes/     #Contiene los juegos de Super Nintendo
        └── gba/      #Contiene los juegos de GameBoy Advance
