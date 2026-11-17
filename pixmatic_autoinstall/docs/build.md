# Construcción de la ISO

Cómo se construye nuestra ISO sin modificar ficheros de upstream, qué hay que
vigilar al fusionar upstream y cómo se comporta el live.

## Uso

```bash
sudo ./pixmatic_autoinstall/build.sh [opciones de buildiso.sh salvo -p]
```

Funciona desde cualquier directorio (calcula las rutas desde su propia
ubicación). El `buildiso.sh` de upstream ignora `pixmatic_autoinstall/`: con
él sale la ISO oficial de escritorio. Requisitos del host: `archiso`,
`mkinitcpio-archiso`, `squashfs-tools`, root y una CPU con x86-64-v3.

## Qué hace `build.sh`

Es un **envoltorio de `buildiso.sh`**:

1. Copia `*.sh` y `archiso/` a `build/pixmatic/tree` (ignorado por git).
2. Elimina de la copia las rutas de `remove.list` y aplica el overlay
   `pixmatic_autoinstall/archiso/` (`packages.x86_64`, `pacman.conf` con repos
   x86-64-v3, motd, environment, `default.target` → `multi-user.target`,
   `efiboot/loader/`). Solo se copia `pixmatic_autoinstall/archiso/`; nada más
   de `pixmatic_autoinstall/` (p. ej. `upstream-src/`) acaba en la ISO.
3. Añade `profiledef.append.sh` al final de la copia de `profiledef.sh` (no
   cambiar `iso_name`: `run_build` espera `cachyos-<fecha>-x86_64.iso`).
4. Añade al final de la copia de `util-iso.sh` un `import` de
   `prepare_profile.sh`, que **sustituye** a `prepare_profile()` (la de
   upstream es específica del escritorio), y de `trap_exit.sh`, que sustituye
   a `trap_exit()` para no avisar de error al terminar bien (mismo cambio que
   el PR upstream #122; cuando lo fusionen, `build.sh` avisa y se borran
   `trap_exit.sh` y su import). Nunca se parchea con `sed`: añadir líneas al
   final no depende de patrones y no falla en silencio.
5. Copia `settings.jsonc` (la configuración de `pixmatic-install`) tal
   cual, con sus comentarios, a `/etc/pixmatic/settings.jsonc`, para poder
   editarlo en el live; `pixmatic-install` quita las líneas que empiezan por
   `//` al leerlo (solo comentarios de línea completa, para no romper valores
   con `//`). Antes lo valida igual que el instalador (requiere `jq` en el
   host; aborta si no es un objeto JSON) y lo instala con `/etc/pixmatic` 700 y el fichero 600 (vía
   `profiledef.append.sh`).
6. Ejecuta `./buildiso.sh "$@" -p pixmatic` en la copia y mueve el resultado a
   `out/pixmatic/` (`cachyos-pixmatic-linux-AAMMDD.iso`). El éxito se
   comprueba por la ISO generada, no solo por el código de salida.

Reparto: *qué va en la ISO* (`prepare_profile`, paquetes, overlay) es
nuestro; *cómo se construye* (`buildiso.sh`, `run_build`, firma, opciones) es
de upstream y se hereda solo.

## `settings.jsonc`

- Configuración de `pixmatic-install`, con esquema propio: **todas** las
  opciones presentes, las no usadas comentadas en su sitio con descripción,
  valores posibles y valor por defecto. Si se quiere omitir algo, se comenta,
  no se borra. Las de fases futuras van comentadas y marcadas «NO
  IMPLEMENTADA»
  ([decisiones.md §8](decisiones.md#8-configuración-del-instalador-settingsjsonc)).

## Vigilancia tras cada merge de upstream

El procedimiento completo está en
[sincronizacion-upstream.md](sincronizacion-upstream.md). Lo que `build.sh`
vigila por sí solo:

- `prepare_profile.upstream` guarda el `prepare_profile()` de upstream. Si
  cambia, `build.sh` se detiene con el diff: revisar si hay que llevar algo a
  `prepare_profile.sh` y regenerar la referencia con
  `awk '/^prepare_profile\(\)/,/^}/' util-iso.sh > pixmatic_autoinstall/prepare_profile.upstream`.
- `pacman.conf.upstream` es copia del `archiso/pacman.conf` de upstream (el del
  overlay es ese mismo más los repos -v3). Si cambia, `build.sh` se detiene:
  llevar el cambio al overlay y `cp archiso/pacman.conf
  pixmatic_autoinstall/pacman.conf.upstream`.

A mano: revisar `git diff` de `buildiso.sh` y `util-iso.sh`, y que no se
renombren rutas o paquetes de `remove.list` / `packages.x86_64`.

## Ficheros de upstream modificados

Mantener esta lista al día (fichero — motivo):

- _(ninguno por ahora)_

## Comportamiento del live (sin probar aún)

systemd-boot sin menú (solo UEFI) → initramfs archiso (`copytoram=auto`) →
`multi-user.target` → `pacman-init`, NetworkManager, resolved, sshd →
autologin de `liveuser` (sudo sin contraseña) en tty1 → motd → **menú del
instalador** (`pixmatic-menu`, lanzado por `/etc/profile.d/pixmatic-menu.sh`
en tty1 y al entrar por SSH;
[decisiones.md §10](decisiones.md#10-menú-del-live-2026-11-17)): instalar
(elegir disco de la lista y confirmar el borrado; al terminar, reiniciar,
apagar o consola), editar `settings.jsonc` (`/etc/pixmatic/settings.jsonc`,
con sus comentarios), modo consola o apagar. **No instala nada sin
confirmación.** El menú ejecuta `pixmatic-install <disco>` (contraseñas tal
cual de `user_pass`/`root_pass`; log en `/var/log/pixmatic-install.log`,
copiado también al sistema instalado).

Detalles: teclado español en la consola del live (`vconsole.conf` del
overlay), wifi con `nmtui`, SSH como `root` o `liveuser` sin contraseña ni
claves (`ssh/sshd_config.d/20-pixmatic.conf`), el mecanismo `script=` de upstream no aplica (solo root+zsh).

## Estructura de upstream (referencia)

- `buildiso.sh`: punto de entrada (`sudo ./buildiso.sh -p desktop -v -w`).
- `util-iso.sh`: `prepare_profile`, `run_build`; genera motd, mirrorlist,
  etiquetas de versión y edición y el enlace del display manager; llama a
  `mkarchiso`.
- `util.sh`, `util-msg.sh`, `util-iso-mount.sh`: utilidades.
- `archiso/`: perfil archiso (`profiledef.sh`, `packages_desktop.x86_64` →
  `packages.x86_64`, `pacman.conf`, `bootstrap_packages.x86_64`, `grub/`,
  `syslinux/`, `efiboot/`, `airootfs/`).
- Solo existe el perfil `desktop` (los demás se eliminaron en `0f91b1e`);
  `handheld` vive en la rama `cachyos-deckify`.
- `testiso.sh`, `testcases/`, `machines/`: tests en QEMU.
- `.github/workflows/build.yml`: CI de upstream (solo push a `master` y PRs;
  no construye nuestra ISO).
