# pixmatic_autoinstall

Modificaciones propias del fork `pixmatic/CachyOS-Live-ISO` (rama `pixmatic_iso`).

Objetivo: ISO mínima de CachyOS, sin interfaz gráfica, que instala el sistema de
forma desatendida con `cachyos-installer` (modo headless) y después restaura la
configuración con etckeeper (`/etc`) y chezmoi (`$HOME`).

Todo el trabajo propio vive en este directorio para minimizar los conflictos al
fusionar periódicamente con upstream (`CachyOS/CachyOS-Live-ISO`).

## Estructura

- `build.sh` — envoltorio de `buildiso.sh` (`sudo ./pixmatic_autoinstall/build.sh [-w] [-r] [-v]`,
  acepta las opciones de `buildiso.sh` salvo `-p`). Copia los scripts y
  `archiso/` a `build/pixmatic/tree`, elimina lo de `remove.list`, aplica el
  overlay `archiso/`, añade `profiledef.append.sh`, hace que la copia de
  `util-iso.sh` cargue `prepare_profile.sh` y ejecuta `./buildiso.sh -p pixmatic`
  en la copia. Resultado en `out/pixmatic/`. Requiere Arch/CachyOS con `archiso`.
- `prepare_profile.sh` — sustituye al `prepare_profile()` de upstream (específico
  del escritorio). El proceso de build (`run_build`, firma, opciones) sigue
  siendo el de upstream.
- `prepare_profile.upstream` — copia de referencia del `prepare_profile()` de
  upstream. Si upstream lo cambia, `build.sh` se detiene y muestra el diff.
- `archiso/packages.x86_64` — lista de paquetes propia (solo consola).
- `archiso/airootfs/` — ficheros que se añaden o sustituyen en el live.
- `remove.list` — rutas del perfil de upstream que se eliminan de la copia.
- `profiledef.append.sh` — ajustes que se añaden al final de `profiledef.sh`.
