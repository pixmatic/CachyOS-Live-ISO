# Anexo: New-Cli-Installer con escritorio Hyprland

Anexo de [auditoria-new-cli-installer-base.md](auditoria-new-cli-installer-base.md).
Recoge **solo lo que cambia** respecto a la instalación base cuando la
configuración headless lleva `"desktop": "hyprland"` en lugar de
`"desktop": ""`. El resto de pasos (particionado, LUKS2, `pacstrap` base,
ajustes del sistema, usuarios, initramfs, bootloader, ufw…) es idéntico y no
se repite.

## Versiones auditadas

| Componente | Repo / origen | Rama/tag/versión | Commit | Nota |
|---|---|---|---|---|
| NCI | `CachyOS/New-Cli-Installer` | **tag `0.13.0`** | `30401a3` (2026-11-15) | Igual que el informe base. |
| `net-profiles.toml` remoto | `raw.githubusercontent.com/…/master/net-profiles.toml` | — | — | Sin cambios entre `0.12.4` y `0.13.0` (`git diff` vacío). |
| Paquetes binarios | repos de CachyOS/Arch (2026-11-16) | ver [Paso Desktop](#paso-desktop) | — | Solo `pacman -Si` (dependencias). |

Historia del documento: la primera versión auditó el tag `0.12.4`
(historial de git, `635d754`). Las diferencias están en
[Cambios respecto a `0.12.4`](#cambios-respecto-a-0124).

Rutas citadas: como en el informe base (sin prefijo = NCI en `0.13.0`;
`iso:` = este repo).

## Configuración headless

Única diferencia con la del informe base:

```json
"desktop": "hyprland"
```

`hyprland` está en la lista de escritorios válidos
(`installer-lib/include/cachyos/installer_data.hpp:35`). Con `autologin` en
`false` (valor de nuestro `settings.jsonc`) y `netinstall_groups` vacío.

## Resumen: pasos que cambian

Nombres de paso del informe base (orden de
`installer-lib/src/orchestrator.cpp:140-180`). Los no listados se comportan
igual que sin escritorio.

| Paso | Sin escritorio | Con Hyprland | Fallo |
|---|---|---|---|
| `Desktop` | no-op | **`pacstrap`** del perfil `[desktop.hyprland]` | aviso |
| `DesktopConfigure` | no-op | **plymouth**: tema `cachyos-bootanimation` y `HOOKS` con `plymouth` (sin generar initramfs) | aviso |
| `Users` | `useradd -m` | igual (el skel no trae nada de Hyprland) | fatal |
| `Autologin` | no-op | no-op (`autologin: false`); ver delta | aviso |
| `Initramfs` | `mkinitcpio -P` | igual, pero ya con el hook `plymouth` | fatal |
| `EnableServices` | sin DM | **`systemctl enable sddm`** | aviso |

`Desktop` y `DesktopConfigure` no están en la lista de pasos fatales
(`installer-lib/src/orchestrator.cpp:32-53`): **si el `pacstrap` del
escritorio falla, NCI termina "bien" con un sistema sin escritorio** (igual
que en `0.12.4`).

Sin cambios con Hyprland (comprobado): `Base` (el `pacstrap` base ya incluye
`[base-packages.desktop]`, con plymouth y firefox, aunque no haya escritorio),
`SystemSettings`, `Chwd`, `Bootloader`, la lista de servicios de
`net-profiles.toml` (no depende del escritorio) y ufw.

---

## Paso `Desktop`

`installer-lib/src/steps/desktop.cpp` → `install_desktop_packages`
(`installer-lib/src/packages.cpp:174-188`) → `get_pkglist_desktop`
(`gucc/src/package_list.cpp:182-213`).

Selección del perfil: recorre `kDesktopMatches`
(`gucc/src/package_list.cpp:31-48`) y añade el perfil de cada palabra clave
que aparezca **como subcadena** en `desktop`. Con `"hyprland"` solo casa
`hyprland` (ninguna otra clave es subcadena), con `needs_xorg = false`, así que
**no se añade `[desktop.xorg]`**. Después se añaden los `netinstall_groups`
(vacío).

`[desktop.hyprland]` (`net-profiles.toml:532-546`):

```toml
[desktop.hyprland]
# should be equal to netinstall hyprland section group in GUI installer
packages = [
  "hyprland", "sddm", "xdg-desktop-portal-hyprland", "playerctl", "wofi",
  "dolphin", "kitty", "uwsm", "wl-clipboard", "polkit-kde-agent", "xorg-xwayland"
]
```

Comando (`installer-lib/src/packages.cpp:221-234`,
`gucc/src/io_utils.cpp:224-242`):

```bash
pacstrap -c -C /mnt/etc/pacman.conf /mnt \
    hyprland sddm xdg-desktop-portal-hyprland playerctl wofi dolphin kitty \
    uwsm wl-clipboard polkit-kde-agent xorg-xwayland \
    --cachedir /mnt/var/cache/pacman/pkg [--cachedir /var/cache/pacman/pkg] \
    --hookdir /mnt/etc/pacman.d/hooks
```

- **`-C /mnt/etc/pacman.conf`**: en `0.13.0` es el `pacman.conf` generado en
  `Base` con los **repos optimizados** (v3/v4/znver4) delante de `[cachyos]`
  (informe base, `Base`). Los paquetes del escritorio salen, por tanto, de los
  mismos repos que los de la base. En `0.12.4` salían de los genéricos.
- Descarga en la caché del target (queda llena, como en la base); la del live
  solo con `hostcache`.
- `--hookdir` del target: sigue activo el hook que aplaza el initramfs, así
  que instalar `hyprland`/`sddm` no regenera nada.

Dependencias relevantes (`pacman -Si`, 2026-11-16; con los repos -v3):

| Paquete | Versión | Nota |
|---|---|---|
| `hyprland` | 0.57.2-1.1 (`cachyos-extra-v3`) | `/usr/bin/Hyprland`, `start-hyprland`; sesiones `hyprland.desktop` y `hyprland-uwsm.desktop` |
| `sddm` | 0.21.0-8 (`cachyos-v3`) | Depende de **`xorg-server`** y `xorg-xauth`: el servidor X entra por aquí aunque el perfil no pida `[desktop.xorg]` |
| `polkit-kde-agent` | — | Agente polkit (Qt/KDE) |
| `dolphin` | — | Arrastra buena parte de KDE Frameworks |
| `uwsm`, `wofi`, `kitty`, `playerctl`, `wl-clipboard`, `xdg-desktop-portal-hyprland`, `xorg-xwayland` | — | — |

Lo que **no** instala este perfil (y sí el de Calamares): ni dotfiles de
CachyOS (`cachyos-hypr-noctalia`), ni shell (Noctalia/waybar). El usuario
queda **sin `~/.config/hypr`**: aunque `Users` va después y `useradd -m`
copia `/etc/skel`, ningún paquete del perfil pone nada de Hyprland en el
skel, y NCI no tiene ninguna referencia a `skel` en su código.

## Paso `DesktopConfigure`

`installer-lib/src/steps/desktop_configure.cpp` → `configure_desktop_extras`
(`installer-lib/src/packages.cpp:191-211`). Como `plymouth` está instalado
(viene de `[base-packages.desktop]`):

```bash
# gucc/src/plymouth.cpp:54-60 (fallo → solo error en el log)
arch-chroot /mnt /usr/bin/plymouth-set-default-theme cachyos-bootanimation

# gucc/src/initcpio.cpp:216-300: reescribe HOOKS (no conserva los anteriores),
# use_systemd_hook=true, LUKS, btrfs de un solo dispositivo, has_plymouth=true
#   HOOKS=(base systemd keyboard autodetect microcode modconf block sd-vconsole plymouth sd-encrypt filesystems)
```

En `0.13.0` este paso **ya no ejecuta `mkinitcpio -P`** (comentario «the
Initramfs step builds the images», `packages.cpp:202`): el initramfs se
genera una sola vez en el paso `Initramfs`, ya con el hook `plymouth`. Si
falla la reescritura de `HOOKS`, el paso devuelve error (aviso).

Diferencia con la base: allí plymouth queda instalado pero sin tema ni hook;
con escritorio se activa el splash. Sin `kms` (como en la base) y **sin
`UseSimpledrm=1`** (Calamares sí lo pone). La cmdline ya llevaba `splash
quiet` (`/etc/kernel/cmdline` del paso `Bootloader`).

Sin LUKS: `base systemd autodetect microcode modconf block keyboard
sd-vconsole plymouth filesystems` (`gucc/src/initcpio.cpp:241-253`).

## Paso `Autologin`

Con `autologin: false` sale sin hacer nada
(`installer-lib/src/steps/autologin.cpp`).

Delta con `autologin: true`: detecta `sddm` (ver `EnableServices`) y escribe
con un editor de INI que **crea el fichero si no existe**
(`gucc/src/autologin.cpp:19-27,51-52`):

```ini
# /mnt/etc/sddm.conf
[Autologin]
User=<usuario>
```

Arregla el autologin roto de `0.12.4` (`sed` sobre un fichero que no
existía). Sigue sin fijar `Session=`: SDDM usaría la sesión por defecto.

## Paso `EnableServices`

Tras aplicar las listas de servicios (iguales que en la base),
`installer-lib/src/packages.cpp:263-276`:

```bash
# detect_installed (gucc/src/display_manager.cpp:70-72): primera unidad existente en
#   plasmalogin, lightdm, sddm, gdm, lxdm, ly, cosmic-greeter  (kPreferred, :26-34)
#   → sddm (/mnt/usr/lib/systemd/system/sddm.service)
arch-chroot /mnt /usr/bin/systemctl enable sddm      # enable (:74-84) → display-manager.service
# configure_lightdm_greeter: solo para lightdm → no aplica
```

No se escribe ninguna configuración de SDDM: ni tema, ni sesión por defecto,
ni `DisplayServer`. SDDM arranca con sus valores por defecto (greeter en X11,
tema integrado) y ofrece las dos sesiones de Hyprland.

---

## Estado final: diferencias con la instalación base

| Elemento | Sin escritorio | Con Hyprland |
|---|---|---|
| Paquetes explícitos añadidos | — | `hyprland sddm xdg-desktop-portal-hyprland playerctl wofi dolphin kitty uwsm wl-clipboard polkit-kde-agent xorg-xwayland` (+ `xorg-server`, KDE Frameworks de `dolphin`…) |
| Origen de esos paquetes | — | repos optimizados (el `pacman.conf` generado, copiado al target) |
| Display manager | ninguno | **SDDM** (`systemctl enable sddm`), sin configurar; sin autologin |
| Sesiones disponibles | — | `Hyprland` (`start-hyprland`) y `Hyprland (uwsm-managed)` |
| Plymouth | instalado, sin tema ni hook | tema `cachyos-bootanimation`, hook `plymouth` tras `sd-vconsole` |
| `mkinitcpio.conf` HOOKS (LUKS) | `… block sd-vconsole sd-encrypt filesystems` | `… block sd-vconsole plymouth sd-encrypt filesystems` |
| Generaciones de initramfs | una | una |
| `$HOME` del usuario | skel de la base | igual: **sin configuración de Hyprland** |

## Hallazgos y peculiaridades

1. **El perfil Hyprland de NCI no coincide con el de Calamares**, aunque su
   comentario dice que debería (`net-profiles.toml:533`). Ambos ponen SDDM
   desde 26.11, pero NCI instala el Hyprland "clásico" (wofi +
   polkit-kde-agent, sin dotfiles) y Calamares `cachyos-hypr-noctalia` (shell
   Noctalia y dotfiles en `/etc/skel`). Siguen siendo dos escritorios
   distintos.
2. **Sin dotfiles**: el usuario arranca Hyprland sin `~/.config/hypr`. Los
   paquetes del perfil (`kitty`, `dolphin`, `wofi`) coinciden con las
   aplicaciones de la configuración de ejemplo de Hyprland, lo que sugiere que
   se cuenta con ella (a verificar en VM qué genera Hyprland 0.57 en el primer
   arranque).
3. **Fallos silenciosos**: si falla el `pacstrap` del escritorio o la
   reescritura de `HOOKS`, solo hay un aviso.
4. **Teclado**: el greeter de SDDM (X11) sí lee
   `/etc/X11/xorg.conf.d/00-keyboard.conf` (`XkbLayout es`), pero Hyprland no:
   sin configuración propia, arranca con distribución `us`.
5. Sin `[desktop.xorg]`, el servidor X entra igualmente como dependencia de
   `sddm`.

## Cambios respecto a `0.12.4`

| Tema | `0.12.4` | `0.13.0` |
|---|---|---|
| Repos de los paquetes del escritorio | genéricos (`pacman.conf` del live copiado) | **optimizados** (`pacman.conf` generado) |
| Caché | la del live (`-c`) | la del target (queda llena) |
| Initramfs con plymouth | `DesktopConfigure` ejecutaba `mkinitcpio -P` (segunda generación) | solo reescribe `HOOKS`; una única generación en `Initramfs` |
| `kms` en `HOOKS` | sí | no |
| Fallo al poner el hook de plymouth | solo log | error del paso (aviso) |
| Usuario | antes del escritorio | después (fatal); sin efecto en el `$HOME` porque no hay dotfiles |
| Autologin SDDM | roto (`sed` sobre fichero inexistente) | crea `/etc/sddm.conf` con `[Autologin] User=` |
| Perfil `[desktop.hyprland]` y detección de DM | — | sin cambios |

## Pendiente de verificar en VM

- Lista final de paquetes y repo de origen de cada uno.
- Qué configuración crea Hyprland 0.57 sin `~/.config/hypr` y si la sesión es
  usable (lanzador, agente polkit, portal).
- Que SDDM arranca (X11) y lista las dos sesiones; sesión preseleccionada.
- HOOKS finales y splash de plymouth sin `kms` ni `UseSimpledrm`.
- Distribución de teclado efectiva en SDDM y en Hyprland.
