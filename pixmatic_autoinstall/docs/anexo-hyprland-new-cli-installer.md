# Anexo: New-Cli-Installer con escritorio Hyprland

Anexo de [auditoria-new-cli-installer-base.md](auditoria-new-cli-installer-base.md).
Recoge **solo lo que cambia** respecto a la instalación base cuando la
configuración headless lleva `"desktop": "hyprland"` en lugar de
`"desktop": ""`. El resto de pasos (particionado, `pacstrap` base, ajustes del
sistema, usuarios, bootloader, ufw…) es idéntico y no se repite.

## Versiones auditadas

| Componente | Repo / origen | Rama/tag/versión | Commit | Nota |
|---|---|---|---|---|
| NCI | `CachyOS/New-Cli-Installer` | **tag `0.12.4`** | `bb3eccb` (2026-08-05) | Igual que el informe base. |
| NCI (referencia) | `CachyOS/New-Cli-Installer` | `master` | `47730e4` (2026-11-12) | Solo para [Diferencias con `master`](#diferencias-relevantes-con-master). |
| `net-profiles.toml` remoto | `raw.githubusercontent.com/…/master/net-profiles.toml` | descargado 2026-11-15 | — | **Idéntico** al del tag `0.12.4` (`diff` vacío). Es el que se usa en ejecución. |
| Paquetes binarios | repos de CachyOS/Arch (2026-11-15) | ver [Paso 9](#paso-9-desktop) | — | Solo `pacman -Si` (dependencias). |

Rutas citadas: como en el informe base (sin prefijo = NCI en `0.12.4`;
`master:` = NCI en `master`; `iso:` = este repo).

## Configuración headless

Única diferencia con la del informe base:

```json
"desktop": "hyprland"
```

`hyprland` está en la lista de escritorios válidos
(`installer-lib/include/cachyos/installer_data.hpp:20-37`). Con `autologin`
en `false` (valor de nuestro `settings.jsonc`) y `netinstall_groups` vacío.

## Resumen: pasos que cambian

Numeración del informe base. Los no listados se comportan igual que sin
escritorio.

| # | Paso | Sin escritorio | Con Hyprland | Fallo |
|---|---|---|---|---|
| 9 | `Desktop` | no-op | **`pacstrap`** del perfil `[desktop.hyprland]` | aviso |
| 10 | `DesktopConfigure` | no-op | **plymouth**: tema `cachyos-bootanimation`, hook `plymouth`, `mkinitcpio -P` | aviso |
| 11 | `Autologin` | no-op | no-op (`autologin: false`); ver delta | aviso |
| 16 | `EnableServices` | sin DM | **`systemctl enable sddm`** | aviso |

Los fallos de los pasos 9 y 10 solo se registran como avisos y la instalación
sigue (`installer-lib/src/orchestrator.cpp:305-321`): **si el `pacstrap` del
escritorio falla, NCI termina "bien" con un sistema sin escritorio**.

Sin cambios con Hyprland (comprobado): `Base` (el `pacstrap` base ya incluye
`[base-packages.desktop]`, con plymouth y firefox, aunque no haya escritorio),
`SystemSettings`, `Users`, `Chwd`, `Bootloader`, la lista de servicios de
`net-profiles.toml` (no depende del escritorio) y ufw.

---

## Paso 9: `Desktop`

`installer-lib/src/steps/desktop.cpp:9-18` →
`install_desktop_packages` (`installer-lib/src/packages.cpp:166-185`) →
`get_pkglist_desktop` (`gucc/src/package_list.cpp:172-208`).

Selección del perfil: recorre `kDesktopMatches`
(`gucc/src/package_list.cpp:29-46`) y añade el perfil de cada palabra clave
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

Comando (`installer-lib/src/packages.cpp:230-243`, `gucc/src/io_utils.cpp:59-69`):

```bash
pacstrap -c -C /mnt/etc/pacman.conf /mnt \
    hyprland sddm xdg-desktop-portal-hyprland playerctl wofi dolphin kitty \
    uwsm wl-clipboard polkit-kde-agent xorg-xwayland
```

- **`-C /mnt/etc/pacman.conf`**, no el `pacman.conf` temporal del `pacstrap`
  base (informe base, 3c-3e). El del target es la copia del live: solo
  `[cachyos]` genérico más los repos de Arch, **sin `cachyos-v3`/`-v4`**. Por
  tanto los paquetes del escritorio se instalan desde los repos **genéricos
  x86_64** (`extra`, `cachyos`), mientras que los de la base vinieron de los
  optimizados. Es coherente con las actualizaciones posteriores (que también
  usan el `pacman.conf` del target), pero es una diferencia con Calamares.
- `-c` (caché del live) y el resto del comportamiento de `pacstrap`, como en
  el informe base (3d).

Dependencias relevantes (`pacman -Si`, 2026-11-15):

| Paquete | Versión | Nota |
|---|---|---|
| `hyprland` | 0.57.2-1 (`extra`) | `/usr/bin/Hyprland`, `start-hyprland`; sesiones `hyprland.desktop` y `hyprland-uwsm.desktop` |
| `sddm` | 0.21.0-6 (`cachyos`) | Depende de **`xorg-server`** y `xorg-xauth`: el servidor X entra por aquí aunque el perfil no pida `[desktop.xorg]` |
| `polkit-kde-agent` | 6.8.2-1 | Agente polkit (Qt/KDE) |
| `dolphin` | 26.08.3-1 | Arrastra buena parte de KDE Frameworks |
| `uwsm`, `wofi`, `kitty`, `playerctl`, `wl-clipboard`, `xdg-desktop-portal-hyprland`, `xorg-xwayland` | — | — |

Como `[cachyos]` va antes que `[extra]` en el `pacman.conf` del live
(`iso:archiso/airootfs/etc/pacman.conf:73,90`), `sddm` sale de `cachyos`
(0.21.0-6) y el resto, que no está en `cachyos`, de `extra`.

Lo que **no** instala este perfil (y sí el de Calamares): ni dotfiles de
CachyOS (`cachyos-hypr-noctalia`/`cachyos-hyprland-settings`), ni shell
(Noctalia/waybar), ni greetd. El usuario queda **sin `~/.config/hypr`**.
Tampoco habría copia posterior del skel: el usuario se creó en el Paso 7 y NCI
no vuelve a copiar `/etc/skel` (no hay ninguna referencia a `skel` en el
código de `0.12.4`).

## Paso 10: `DesktopConfigure`

`installer-lib/src/steps/desktop_configure.cpp:9-18` →
`configure_desktop_extras` (`installer-lib/src/packages.cpp:187-220`). Como
`plymouth` está instalado (`/mnt/usr/bin/plymouth`, `gucc/src/plymouth.cpp:20-23`;
viene de `[base-packages.desktop]`):

```bash
# gucc/src/plymouth.cpp:51-58 (fallo → solo error en el log)
arch-chroot /mnt plymouth-set-default-theme cachyos-bootanimation

# gucc/src/initcpio.cpp:103-191: reescribe HOOKS (no conserva los anteriores),
# use_systemd_hook=true, sin LUKS/LVM, btrfs de un solo dispositivo
#   HOOKS=(base systemd autodetect microcode kms modconf block keyboard sd-vconsole plymouth filesystems)

# fallo → la función devuelve error → aviso
arch-chroot /mnt mkinitcpio -P
```

Diferencia con la base: allí plymouth queda instalado pero sin tema ni hook;
con escritorio se activa el splash. El initramfs se genera **dos veces** (3f
del `Base` y aquí). La cmdline ya llevaba `quiet splash` (la añade
`sdboot-manage` en el Paso 14, que va después).

Con LUKS (modo avanzado, delta del informe base) los HOOKS serían
`base systemd keyboard autodetect microcode kms modconf block sd-vconsole plymouth sd-encrypt filesystems`
(`gucc/src/initcpio.cpp:127-153`).

## Paso 11: `Autologin`

Con `autologin: false` sale sin hacer nada
(`installer-lib/src/steps/autologin.cpp:15-17`).

Delta con `autologin: true`: detecta `sddm` (ver Paso 16) y ejecuta
(`gucc/src/autologin.cpp:39-40`):

```bash
sed -i 's/^User=/User=<usuario>/g' /mnt/etc/sddm.conf
```

El paquete `sddm` de Arch **no instala `/etc/sddm.conf`** (su configuración
por defecto está en `/usr/lib/sddm/sddm.conf.d/`) y NCI no lo crea, así que el
`sed` falla, el error se ignora (`exec_checked` sin comprobar) y **el autologin
no se configura**. Tampoco fija la sesión (`Session=`).

## Paso 16: `EnableServices`

Tras aplicar las listas de servicios (iguales que en la base),
`installer-lib/src/packages.cpp:282-295`:

```bash
# detect_installed (gucc/src/display_manager.cpp:71-79): primera unidad existente en
#   plasmalogin, lightdm, sddm, gdm, lxdm, ly, cosmic-greeter  (:23-31)
#   → sddm (/mnt/usr/lib/systemd/system/sddm.service)
arch-chroot /mnt systemctl enable sddm      # enable (:81-91) → display-manager.service
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
| Origen de esos paquetes | — | repos genéricos x86_64 (el `pacman.conf` del target) |
| Display manager | ninguno | **SDDM** (`systemctl enable sddm`), sin configurar; sin autologin |
| Sesiones disponibles | — | `Hyprland` (`start-hyprland`) y `Hyprland (uwsm-managed)` |
| Plymouth | instalado, sin tema ni hook | tema `cachyos-bootanimation`, hook `plymouth` tras `sd-vconsole` |
| `mkinitcpio.conf` HOOKS | `… keyboard sd-vconsole filesystems` | `… keyboard sd-vconsole plymouth filesystems` |
| `$HOME` del usuario | skel de la base | igual: **sin configuración de Hyprland** |

## Hallazgos y peculiaridades

1. **El perfil Hyprland de NCI no coincide con el de Calamares**, aunque su
   comentario dice que debería (`net-profiles.toml:533`). NCI instala el
   Hyprland "clásico" (SDDM + wofi + polkit-kde-agent, sin dotfiles); Calamares
   instala el actual (greetd + noctalia-greeter + `cachyos-hypr-noctalia` con
   la shell Noctalia y dotfiles en `/etc/skel`). Son dos escritorios distintos.
2. **Sin dotfiles**: el usuario arranca Hyprland sin `~/.config/hypr`. Los
   paquetes del perfil (`kitty`, `dolphin`, `wofi`) coinciden con las
   aplicaciones de la configuración de ejemplo de Hyprland, lo que sugiere que
   se cuenta con ella (a verificar en VM qué genera Hyprland 0.57 en el primer
   arranque).
3. **Fallos silenciosos**: si falla el `pacstrap` del escritorio o el
   `mkinitcpio` con plymouth, solo hay un aviso.
4. **Paquetes del escritorio desde repos genéricos**, no los optimizados
   (`-C /mnt/etc/pacman.conf`).
5. **Autologin con SDDM roto en `0.12.4`** (`sed` sobre un fichero que no
   existe).
6. **Teclado**: el greeter de SDDM (X11) sí lee
   `/etc/X11/xorg.conf.d/00-keyboard.conf` (`XkbLayout es`), pero Hyprland no:
   sin configuración propia, arranca con distribución `us`.
7. Sin `[desktop.xorg]`, el servidor X entra igualmente como dependencia de
   `sddm`.

## Diferencias relevantes con `master`

- `master:gucc/src/autologin.cpp`: el autologin escribe con un editor de INI
  (`set_config_values`) y crea `/etc/sddm.conf` si no existe con
  `[Autologin] User=<usuario>`. Arregla el hallazgo 5 (sigue sin fijar
  `Session=`).
- `master:installer-lib/src/packages.cpp`: el fallo al añadir el hook de
  plymouth pasa a devolverse como error (antes solo se registraba).
- Mismas palabras clave de escritorio y mismo perfil `[desktop.hyprland]`
  (`net-profiles.toml` idéntico).

## Pendiente de verificar en VM

- Lista final de paquetes y repo de origen de cada uno.
- Qué configuración crea Hyprland 0.57 sin `~/.config/hypr` y si la sesión es
  usable (lanzador, agente polkit, portal).
- Que SDDM arranca (X11) y lista las dos sesiones; sesión preseleccionada.
- HOOKS finales y splash de plymouth.
- Distribución de teclado efectiva en SDDM y en Hyprland.
