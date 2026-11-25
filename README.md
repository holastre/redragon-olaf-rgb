# Redragon Olaf RGB (macOS)

Aplicación nativa de macOS (SwiftUI + AppKit + IOKit) para controlar la iluminación RGB —tecla por tecla, efectos globales y efectos reactivos en tiempo real— del teclado mecánico **Redragon K648GG-RGB (Olaf)** por USB, sin necesidad de software de Windows ni drivers de kernel.

> Native macOS RGB controller app for the **Redragon K648GG-RGB (Olaf)** wired mechanical keyboard (`0x258A:0x0049`, Sinowealth MCU) built with SwiftUI and IOKit.

---

## Características principales

* **Mapa interactivo exacto de 94 teclas (US):** Coordenadas físicas y slots LED (`0..101`) extraídos de la configuración oficial del Redragon K648-RGB, con vista previa en tiempo real.
* **Control individual por tecla:**
  * Herramientas **Seleccionar** (clic, `⌘+clic`, arrastre y selección rápida por zonas), **Pincel** y **Borrador**.
  * Selector de color nativo, paleta rápida, código `#HEX` y velocidad independiente por tecla.
  * **11 modos por tecla:** *Heredar global*, *Color fijo*, *Respiración*, *Latido / Pulso*, *Arcoíris propio*, *Destello*, *Parpadeo*, *Alternar 2 colores*, *Reactiva (encender)*, *Reactiva (destello)* y *Apagada*.
* **16 efectos globales (10 ambientales + 6 reactivos):**
  * **Ambientales:** *Onda Arcoíris*, *Color Sólido*, *Respiración*, *Ciclo de Espectro*, *Aurora Dual*, *Fuego / Brasas*, *Lluvia Matrix*, *Estrellas*, *Pulso Radial* y *Solo por Tecla*.
  * **Reactivos al teclear (45 FPS):** *Estela Reactiva*, *Onda Expansiva*, *Onda Arcoíris*, *Cruz Láser*, *Chispas Reactivas* y *Mapa de Calor*.
  * **Capa reactiva superpuesta:** Agrega *Destello tecla*, *Onda expansiva*, *Cruz láser* u *Onda arcoíris* encima de cualquier modo ambiental.
* **14 presets rápidos + perfiles personalizados:** Guardado automático en `Application Support` y cambio rápido desde la app o la barra de menú.
* **Listo para uso diario en macOS:**
  * Ícono en la barra de menú con acceso dinámico a tus perfiles guardados, presets y control de brillo.
  * Opción de iniciar oculta en la barra de menú y ocultar el ícono del Dock al cerrar la ventana.
  * Apagado automático de LEDs al bloquear pantalla o entrar en reposo, y restauración automática al despertar.
  * Uso mínimo de CPU (pausa automática del envío USB en modos estáticos o cuando no hay actividad reactiva).

---

## Seguridad del protocolo USB HID

Este proyecto está diseñado para operar **de forma segura** sobre el microcontrolador Sinowealth (`VID 0x258A`, `PID 0x0049`):

* **Solo RAM volátil (`Report ID 0x08`):** Únicamente envía el *HID Feature Report* `0x08` de 382 bytes (encabezado `08 0A 7A 01` + 126 tripletas RGB) a la Interfaz HID #1 (`MaxFeatureReportSize >= 382`).
* **Nunca escribe en flash ni bootloader:** No envía reportes `0x05` ni `0x06`, evitando riesgos de bloqueo (*brick*) del firmware.
* **Sin interferencia al escribir:** Abre las interfaces HID en modo no exclusivo (`kIOHIDOptionsTypeNone`). Las pulsaciones para efectos reactivos solo se procesan en memoria y nunca se guardan ni registran.

---

## Requisitos

* **macOS 14.0 (Sonoma)** o superior.
* **Command Line Tools de Xcode** (`swiftc`, `iconutil`, `codesign`). No requiere instalar Xcode completo ni dependencias externas.
* Teclado **Redragon K648GG-RGB (Olaf)** conectado por USB.

---

## Compilación e instalación

1. Clona el repositorio y compila el bundle `.app`:

```bash
git clone https://github.com/holastre/redragon-olaf-rgb.git
cd redragon-olaf-rgb
chmod +x build.sh
./build.sh
```

2. Esto generará `Redragon Olaf RGB.app` firmado localmente (*ad-hoc*) en la raíz del proyecto.
3. Copia `Redragon Olaf RGB.app` a tu carpeta `/Applications` y ábrela.

### Permiso de Monitoreo de entrada (macOS)

macOS requiere permiso explícito para abrir la interfaz HID del teclado y escuchar pulsaciones para los efectos reactivos:

1. Al abrir la app, haz clic en **«Solicitar permiso»** (o abre **Ajustes del Sistema → Privacidad y seguridad → Monitoreo de entrada**).
2. Activa **Redragon Olaf RGB** en la lista.
3. Reinicia la app. El indicador superior pasará a verde (`Gaming Keyboard conectado (258a:0049)`).

> **Nota al recompilar:** Al usar firma *ad-hoc*, cada compilación cambia la huella (`cdhash`) del ejecutable. Si tras recompilar macOS vuelve a mostrar el aviso de permiso, elimina la entrada anterior con **`–`** en *Monitoreo de entrada*, vuelve a agregar la nueva copia con **`+`** y reinicia la app.

---

## Estructura del proyecto

```text
redragon-olaf-rgb/
├── build.sh                  # Compila el binario SwiftUI/IOKit, genera AppIcon.icns y firma el bundle
├── Resources/
│   ├── Info.plist            # Metadatos del bundle macOS y descripción de uso HID
│   └── make_icon.swift       # Generador programático del ícono AppIcon.icns
└── Sources/
    ├── AppMain.swift         # AppDelegate, ventana principal, barra de menú y eventos de bloqueo/reposo
    ├── ContentView.swift     # Interfaz SwiftUI, teclado visual interactivo e inspector lateral
    ├── HIDController.swift   # Comunicación USB HID segura (Report 0x08) y listener de pulsaciones
    ├── K648Layout.swift      # Geometría de las 94 teclas, slots LED y tabla de códigos USB HID
    ├── RGBEngine.swift       # Motor de efectos a 45 FPS, LiveFrameStore y persistencia de estado
    └── RGBModels.swift       # Modelos de color/gamma, efectos, presets y perfiles
```
