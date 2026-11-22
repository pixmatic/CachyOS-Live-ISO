# Hyprland frente a niri: diferencias funcionales para juegos y multimedia

Comparación de **capacidades** (protocolos Wayland, salida DRM, Xwayland,
portales) entre Hyprland sin Noctalia y niri, no de estética ni de modelo de
ventanas (mosaico frente a carrusel), que es configurable. La pregunta es si
niri impone restricciones insalvables para juegos y multimedia en el equipo
de destino (AMD Radeon RX 9070 XT, monitor con FreeSync), aun usando
gamescope. Incluye una estimación del tamaño de añadir HDR y gestión de
color a niri.

Estudio exploratorio (2026-11-22): no cambia ninguna decisión de
[decisiones.md](decisiones.md); el escritorio sigue siendo Hyprland.

## Versiones auditadas

| Componente | Repo | Tag | Commit | Paquete publicado (2026-11-22) |
|---|---|---|---|---|
| Hyprland | `hyprwm/Hyprland` | `v0.57.2` | `11cbc6c5` (2026-11-09) | `hyprland` 0.57.2-1 (`extra`) |
| niri | `niri-wm/niri` (antes `YaLTeR/niri`) | `v26.04` | `8ed0da4` (2026-04-25) | `niri` 26.04-1 (`extra`) |

`v26.04` es la última release de niri; lo posterior en `main` se cita como
tal. Estado de PRs de niri y Smithay consultado el 2026-11-22.

## Conclusión

- **Sin monitor HDR, o sin interés en HDR**: niri sirve para juegos y
  multimedia. Con la 9070 XT y VRR, la falta de tearing y de
  `fifo`/`commit-timing` apenas se nota.
- **Con monitor HDR que se quiera aprovechar en el escritorio** (juegos en
  ventana o con gamescope anidado, vídeo HDR): niri no lo permite. Solo hay
  HDR con gamescope como sesión propia (fuera de niri). HDR y gestión de
  color es lo único que **no se puede suplir con otra aplicación**: tiene que
  implementarlo el compositor.

## Lo que Hyprland tiene y niri no

| Función | Hyprland 0.57.2 | niri 26.04 | Efecto en juegos y multimedia |
|---|---|---|---|
| **HDR y gestión de color** (`wp_color_management_v1`) | Sí: `render:cm_enabled`, HDR por monitor (`supports_hdr`, `sdr_min_luminance`, `sdr_max_luminance`, `max_luminance`, `sdr_eotf`), `render:cm_auto_hdr` (pasa a HDR cuando una app a pantalla completa es HDR), perfiles ICC (`icc`, `render:icc_vcgt_enabled`) (`src/config/values/ConfigValues.cpp:671-679`) | **No.** La wiki lo dice: *"we don't support HDR or color management yet"* (`docs/wiki/Configuration:-Debug-Options.md:332`). Solo borra `HDR_OUTPUT_METADATA` y `Colorspace` del conector (`src/backend/tty.rs:3269`, `reset_hdr`) | **Bloqueo real.** Sin el protocolo, ni gamescope anidado (`--hdr-enabled`), ni Proton/DXVK con HDR, ni mpv con HDR directo pueden sacar HDR |
| **10 bits por canal** | `bitdepth,10` por monitor | Fuerza 8 bpc al conectar el monitor; solo lo evita la opción de depuración `keep-max-bpc-unchanged` (`niri-config/src/debug.rs:13`). `max-bpc` por monitor llegó a `main` el 2026-05-28 (PR #3158), después de 26.04 | Menos bandas en degradados; sin gestión de color aporta poco |
| **Tearing** (`wp_tearing_control_v1`) | `general:allow_tearing` (`ConfigValues.cpp:186`) y regla de ventana `immediate` | No | Algo más de latencia sin VRR; con FreeSync y VRR casi no se nota. gamescope anidado con `--immediate-flips` tampoco puede usarlo |
| **`fifo-v1`, `commit-timing-v1`, `linux-drm-syncobj-v1`** | Sí (`src/protocols/Fifo`, `CommitTiming`, `DRMSyncobj`; `render:commit_timing_enabled`) | No; PRs abiertos #1449 (*delayed blocker + syncobj + fifo + commit timing*) y #3956 (*linux-drm-syncobj-v1*) | Ritmo de fotogramas algo peor en Vulkan con Mesa reciente. La sincronización explícita es crítica en Nvidia, no en AMD |
| **Portal GlobalShortcuts** | Sí (`src/protocols/GlobalShortcuts`, más el dispatcher `pass`) | No: usa `xdg-desktop-portal-gnome` (`resources/niri-portals.conf`) sobre interfaces de Mutter que implementa (`src/dbus/`), y GlobalShortcuts no está entre ellas | Pulsar para hablar en Discord, atajos globales de OBS. Apaño: binds de niri que lancen un comando |
| Tipo de contenido (`ContentType`, `render:send_content_type`) | Sí; `misc:vrr` = `fullscreen_game` (3) activa VRR solo con juegos a pantalla completa (`ConfigValues.cpp:570-571`) | No (VRR bajo demanda por regla de ventana) | Menor |
| Captura de entrada (`InputCapture`) | Sí | No | Deskflow/input-leap |
| Espejo de monitores | Nativo | No; `wl-mirror` (una ventana, no un espejo real) (`docs/wiki/Screencasting.md:140-151`) | Menor |
| Plugins | Sí | No | — |

## Lo que niri tiene a la par de Hyprland

VRR (con modo bajo demanda por regla de ventana), direct scanout,
`drm-lease` (VR), restricción de puntero y puntero relativo, inhibición de
reposo y de atajos, `gamma-control`, `screencopy`, puntero y teclado
virtuales (Sunshine), compartir pantalla y ventana por portal (interfaz
`mutter_screen_cast`), multi-GPU. Protocolos registrados en niri: macros
`delegate_*!` de `src/` y módulos de `src/protocols/`.

**Xwayland.** Hyprland lo integra. niri usa `xwayland-satellite`, que lanza
solo (sección `xwayland-satellite` de la configuración). Funciona con Steam,
Proton y Discord (`docs/wiki/Xwayland.md:30`), pero una ventana X11 no puede
posicionarse sola, y algunos juegos con lanzadores o ventanas atípicas dan
guerra.

## gamescope

- **Anidado en niri**: funciona, solo en SDR y sin tearing. La wiki lo
  recomienda para juegos a pantalla completa problemáticos en un compositor
  sin apilamiento, con `--backend sdl` para atrapar bien el cursor
  (`docs/wiki/Application-Issues.md:79-91`).
- **Como sesión propia** (gamescope-session / Steam Big Picture desde otra
  TTY): gamescope maneja DRM directamente y tiene HDR, VRR y tearing sea cual
  sea el escritorio. Es el único rodeo para HDR con niri, a costa de cambiar
  de sesión para jugar.

## Estimación: añadir HDR y gestión de color a niri

### Referencia: Hyprland 0.57.2

Ficheros dedicados, unas **3.100 líneas**:

| Pieza | Líneas |
|---|---|
| Protocolo `wp_color_management_v1` (`src/protocols/ColorManagement.{cpp,hpp}`) | 1.172 |
| Matemática de color: primarios, funciones de transferencia, descripciones de imagen (`src/helpers/cm/ColorManagement.{cpp,hpp}`) | 1.016 |
| Perfiles ICC (`src/helpers/cm/ICC.cpp`) | 320 |
| CTM (`src/protocols/CTMControl.*`) | 229 |
| Shaders: conversión, PQ y mapeo de tonos (`src/render/shaders/glsl/CM.glsl`, `cm_helpers.glsl`, `tonemap.glsl`, `gain.glsl`) | 390 |

Más unas **400 referencias** fuera de esos ficheros: `src/output/Monitor.cpp`
(70: metadatos HDR del conector, cambio automático a HDR),
`src/render/Renderer.cpp` (55), `src/render/OpenGL.cpp` (36: shader según la
descripción de imagen de cada superficie), buffers de trabajo, blur,
captura… Estimadas en otras **1.000-2.000 líneas** de cambios. Unos 78
commits desde 2025 mencionan HDR o gestión de color en el mensaje.

### niri: dos proyectos

1. **Smithay** (protocolo, tipos, renderer GLES y DRM). Sin hacer; dos PRs
   en borrador:
   - #1143, *color management/representation protocols*: +3.244/−7, 13
     ficheros, actualizado el 2026-10-22.
   - #982, *feature: Color management*: +3.438/−1.417, 58 ficheros, parado
     desde el 2026-05-12.
2. **niri**: configuración por monitor (HDR, luminancias, bpc), mandar
   `HDR_OUTPUT_METADATA` y `Colorspace` al conector, render y efectos
   (sombras, bordes, blur, animaciones) en espacio lineal, mapeo de tonos en
   la captura de pantalla, criterio de direct scanout. Estimado en
   **2.000-3.000 líneas**.

**Total estimado: 5.000-8.000 líneas.**

### Lo difícil no es la cantidad

- **El render entero cambia de espacio de color**: mezclar SDR y HDR exige
  componer en espacio lineal (normalmente FP16) y revisar cada shader y
  efecto, no solo añadir uno nuevo.
- **Hay que coordinar con Smithay**: niri depende de que Smithay acepte y
  publique la base, y esos PRs llevan años en borrador.
- **Requiere probar con hardware real**: muchos monitores y EDID
  (luminancias, metadatos, comportamiento de cada fabricante); los bugs de
  color no salen en los tests.
- **Hay que mantenerlo**: Hyprland sigue puliéndolo release a release.

Como proyecto personal: meses para alguien con experiencia en Rust,
gráficos y Wayland, sin garantía de aceptación upstream. No es previsible
que niri tenga HDR pronto.
