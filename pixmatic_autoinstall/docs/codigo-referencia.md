# Código de referencia

Clones de upstream que se auditan, en `pixmatic_autoinstall/upstream-src/`.
Están **ignorados por git** (`pixmatic_autoinstall/.gitignore`); no son
submódulos, sino material de consulta sin commits fijados que mantener. Se
actualizan con `git pull`/`git fetch`. Son clones parciales
(`--filter=blob:none`): no usar comandos que lean blobs de todo el árbol
(`git ls-tree -l`, `git grep` sobre la historia…), porque disparan descargas.

Regla: se audita **lo que se empaqueta realmente**, no solo `master`.

## Clones (estado a 2026-11-16)

| Carpeta | Repo | Rama/estado | Qué se empaqueta |
|---|---|---|---|
| `CachyOS-PKGBUILDS/` | `CachyOS/CachyOS-PKGBUILDS` | `master` (`a7b3058`), `--depth 1` | PKGBUILDs: `cachyos-calamares-staging/` (el que usa la ISO), `cachyos-calamares/` (paquete `cachyos-calamares-next`), `cachyos-cli-installer-new/` |
| `cachyos-calamares/` | `CachyOS/cachyos-calamares` | `cachyos-dev` (`199d71543`, 2026-09-26) + `origin/cachyos-staging` (`42a91ab23`, 2026-11-15) | **rama `cachyos-staging`** (git, sin commit fijo), paquete `cachyos-calamares-staging` 3.4.2-3 |
| `New-Cli-Installer/` | `CachyOS/New-Cli-Installer` | `master` (`30401a3` = `0.13.0`), sin submódulos | **tag `0.13.0`** (2026-11-15) en el PKGBUILD; el repo aún sirve `0.12.4` |
| `omarchy/` | `basecamp/omarchy` (= `omacom/omarchy`) | detached en el tag **`v4.5.0`** (`ac2690cd7`); rama por defecto `quattro` | paquetes `omarchy`/`omarchy-settings` 4.5.0-2, compilados desde `a948d8a68` (hermano del tag; solo difiere en interfaz) |
| `omarchy-iso/` | `omacom/omarchy-iso` | detached en `origin/v4-5-0` (`2f22117aa`; no tiene tags) | la ISO de Omarchy, que **orquesta la instalación** (imagen raíz + comandos de Omarchy en chroot) |
| `omarchy-pkgs/` | `omacom/omarchy-pkgs` | `master` (`d727707b`) | PKGBUILDs del repo `[omarchy]`. Ojo: **no coinciden** con lo publicado en `pkgs.omarchy.org`; comprobar siempre contra su base de datos |

## Notas

### Cambio de CachyOS 26.11 (2026-11-15)

La ISO de upstream pasa a `cachyos-calamares-staging` (rama
`cachyos-staging`, que parte de junio y no tiene los cambios de
`cachyos-dev` de julio-septiembre: Hyprland con SDDM, sin greetd) y NCI a
`0.13.0`. Todas las auditorías, anexos y la comparación están rehechos
(2026-11-16) contra `cachyos-staging` `42a91ab23` y NCI `0.13.0`; las
versiones `cachyos-dev`/`0.12.4` quedan en git (`635d754`) y resumidas en la
sección de cambios de cada documento. Cuando `cachyos-staging` se reunifique
con `cachyos-dev`, revisar Calamares otra vez. Detalle en
[impacto-upstream-26.11.md](impacto-upstream-26.11.md).

### Calamares

El PKGBUILD `cachyos-calamares-staging` compila la rama `cachyos-staging` con
`-DWITH_CACHYOS_INSTALLER=ON` (módulo `gucc`, que usa las librerías de NCI
`0.13.0` de `cachyos-installer-libs`) y `-DSKIP_MODULES` (excluye dracut,
mkinitfs, fsresizer, services-openrc, contextualprocess, los `*q` QML…);
instala `settings_online.conf`, `settings_offline.conf`,
`src/modules/*/*.conf` → `/etc/calamares/modules/`, `src/scripts` y
`netinstall.yaml` (en ejecución se descarga el de la rama `cachyos`). La ISO de
upstream lo lanza con `archiso/airootfs/usr/local/bin/calamares-online.sh`:
refresca keyrings, activa NTP, `pacman -Sy cachyos-calamares-staging` y copia
`settings_online.conf`. Solo cuentan los módulos compilados y presentes en la
secuencia de `settings_online.conf`. Calamares particiona con KPMcore.
Detalle en [auditoria-calamares-base.md](auditoria-calamares-base.md).

### New-Cli-Installer

Se audita el tag que empaqueta `cachyos-cli-installer-new` (hoy `0.13.0`).
Librerías `gucc/` e `installer-lib/` dentro del repo. Detalle en
[auditoria-new-cli-installer-base.md](auditoria-new-cli-installer-base.md).
Notas de cuando `cachyos-installer` iba en la ISO y `settings.jsonc` seguía
su formato (ya no: se quitó el 2026-11-16; quedan como referencia):

- `--config <ruta>`; por defecto `./settings.json`. Sin config → TUI interactiva.
- Solo lee JSON estricto (rapidjson, sin comas finales); **rechaza claves
  desconocidas** y valores fuera de lista.
- Headless siempre particiona y formatea `device` (`CreateLayout`; en `0.13.0`
  desaparece `EraseAndAuto` y `allow_auto_partition` usa el esquema por
  defecto); no hay modo «usar particiones existentes».
- `size` de partición: bytes con sufijo (`512M`, `2G`) o `100%`; otros
  porcentajes no. Exactamente una `root`; en UEFI exactamente una `boot`.
- `locale` se aplica a `LANG` y todas las `LC_*` (un único locale).
- LUKS2 en headless con `luks_passphrase` (mapper `cryptroot`,
  `rd.luks.name=<uuid>=cryptroot`, sin `crypttab`); `console_keymap` propio.
- `post_install` con el destino **aún montado** (`$1` = raíz).
- Usuario creado después de los paquetes (fatal si falla); contraseñas SHA-512.
- `pacman.conf` del target con repos optimizados; caché de paquetes llena.
- Con `user_shell` zsh/fish instala `cachyos-zsh-config`/`cachyos-fish-config`.
- Snapper: snapshot de instalación si está `cachyos-snapper-support`.

`settings.jsonc` se escribió con los valores de `a257be6` (2026-11-10) y
tenía sus 43 claves; `0.13.0` acepta 45 (añade `luks_passphrase` y
`console_keymap`). Desde 2026-11-16 tiene esquema propio
([decisiones.md §8](decisiones.md#8-configuración-del-instalador-settingsjsonc)).

### Omarchy

Omarchy 4.x no tiene script de instalación: la hace su ISO. Auditoría en
[auditoria-omarchy.md](auditoria-omarchy.md); decisión de qué se toma de él en
[decisiones.md §7](decisiones.md#7-hyprland-y-omarchy).

### `omarchy-on-cachyos` (ya no se usa)

`mroboff/omarchy-on-cachyos`, `master` `23e7565` (2026-06-01); clon borrado
el 2026-11-16. Solo sirvió como lista de conflictos de Omarchy con CachyOS,
comprobada uno a uno contra Omarchy 4.x en
[auditoria-omarchy.md §9](auditoria-omarchy.md#9-conflictos-de-omarchy-on-cachyos-comprobados-en-4x).

- Qué hacía: `fetch-omarchy.sh` clonaba Omarchy dejando elegir la rama por
  defecto o uno de los 5 últimos tags; `install-omarchy-on-cachyos.sh`
  instalaba `yay`, añadía `[omarchy]` a `pacman.conf`, parcheaba Omarchy con
  `sed` (quitaba pasos de pacman, plymouth, limine-snapper,
  alt-bootloaders; `linux` → `linux-cachyos`; iwd frente a
  wpa_supplicant; fijaba `walker` al repo omarchy; mise para fish), lo
  copiaba a `~/.local/share/omarchy` y lo ejecutaba. `nvidia.sh` forzaba los
  drivers 580xx vía `chwd`.
- Solo casa con Omarchy `v3.x` (la última válida, `v3.8.4`, 2026-07-20).
  Omarchy 4.0 (2026-08-14) reorganizó el árbol: de los 11 ficheros que el
  script parcheaba solo existe 1 en `v4.x`, y los `sed` que no casan fallan
  en silencio.
- Requisitos que pedía (sin comprobarlos): CachyOS recién instalado, btrfs +
  Snapper, fish, y ningún escritorio o el Hyprland de CachyOS.
