# Anexo: Calamares con escritorio Hyprland

Anexo de [auditoria-calamares-base.md](auditoria-calamares-base.md). Recoge
**solo lo que cambia** respecto a la instalación base cuando en el paso
*Escritorio* se elige **Hyprland** en lugar de *No Desktop*. Todo lo demás
(particionado, LUKS, `pacstrap`, usuarios, locale, initramfs, bootloader,
servicios, ufw…) es idéntico y no se repite.

## Versiones auditadas

| Componente | Repo / origen | Rama/tag/versión | Commit | Nota |
|---|---|---|---|---|
| Calamares | `CachyOS/cachyos-calamares` | **`cachyos-staging`** | `42a91ab23` (2026-11-15) | Igual que el informe base (paquete `cachyos-calamares-staging`). |
| `netinstall.yaml` remoto | `raw.githubusercontent.com/…/cachyos/…/netinstall.yaml` | rama `cachyos` (`1f939ebed`) | — | Idéntico a la copia de `cachyos-staging` (`git diff` vacío). Es el que se usa en ejecución. |
| ISO | `CachyOS/CachyOS-Live-ISO` | `master` | `b0ebcae` (2026-11-15) | `archiso/airootfs/usr/local/bin/dmcheck` (lo copia y ejecuta Calamares). |
| PKGBUILDs | `CachyOS/CachyOS-PKGBUILDS` | `master` | `a7b3058` (2026-11-15) | `cachyos-hypr-noctalia/` (pkgver 1.2.6, **pkgrel 2**). |
| `cachyos-hypr-noctalia` | `cachyos/cachyos-hypr-noctalia` | tag `1.2.6` | — | Tarball de GitHub (el que usa el PKGBUILD). El repo `cachyos` sirve aún **1.2.6-1** (2026-11-16). |
| Paquetes binarios | repos de CachyOS (2026-11-15/16) | ver tabla del [Paso 14](#paso-14-packagesonline-grupo-hyprland) | — | |

Historia del documento: la primera versión auditó `cachyos-dev`
(`199d71543`), cuyo grupo Hyprland usaba **greetd + noctalia-greeter** con un
paso propio `shellprocess@greetd`. `cachyos-staging` no tiene esos cambios
(es anterior a ellos, ver
[impacto-upstream-26.11.md](impacto-upstream-26.11.md)) y vuelve a **SDDM**.
La versión greetd está en el historial de git (`635d754`) y resumida en
[Diferencias con `cachyos-dev`](#diferencias-con-cachyos-dev-greetd).

Rutas citadas: como en el informe base (sin prefijo = `cachyos-calamares/`
en `cachyos-staging`; `pkgbuilds:` = `CachyOS-PKGBUILDS/`; `iso:` = este
repo). Nuevos prefijos:

- `hypr-noctalia:` = árbol del tag `1.2.6` de `cachyos-hypr-noctalia`.
- `pkg:<nombre>:` = contenido del paquete binario `<nombre>` del repo.

## Cómo llega la elección a la instalación

1. `packagechooser@desktop` (`settings_online.conf:38-40`, vista en `:86`) usa
   `packagechooser_desktop.conf` con `method: netinstall-select`
   (`src/modules/packagechooser/packagechooser_desktop.conf:8`). La entrada
   elegida es `id: Hyprland` (`:176`).
2. Con `netinstall-select`, el id elegido se añade a la clave
   `netinstallSelect` de GlobalStorage (`src/modules/packagechooser/Config.cpp`).
3. `netinstall` marca el grupo cuyo **nombre** coincide (`"Hyprland"`,
   `src/modules/netinstall/NetInstallPage.cpp:70-72`). No hay otra forma de
   que la elección de escritorio llegue a los módulos de `exec`: **ningún módulo
   de instalación lee `packagechooser_desktop`**. Todo lo que cambia después se
   deriva de los paquetes instalados.
4. La UI de netinstall impide avanzar si quedan seleccionados dos paquetes de
   dotfiles de escritorio (`src/modules/netinstall/PackageModel.cpp:238-268`,
   lista `kDotfilePackages` de `:240`, que incluye `cachyos-hypr-noctalia`).

## Resumen: pasos de `exec` que cambian

Numeración de pasos del informe base. Los no listados se comportan igual que
sin escritorio.

| Paso | Módulo | Sin escritorio | Con Hyprland |
|---|---|---|---|
| 14 | `packages@online` | grupos preseleccionados | + grupo **Hyprland** (crítico) en la misma transacción |
| 9 | `users` | `useradd -m` con el skel de la base | `useradd -m` copia ya los **dotfiles de Hyprland** (el usuario se crea tras los paquetes) |
| 23 | `displaymanager` | no-op | **actúa**: escribe `[Autologin] Session=hyprland` en `/etc/sddm.conf` |
| 29 | `shellprocess` | `dmcheck`: solo el enlace roto de `ly`; recopia del skel redundante | `dmcheck` enlaza `display-manager.service` → **`sddm.service`** |

Sin cambios con Hyprland (comprobado): `plymouthcfg`, `initcpiocfg` e
`initcpio` (plymouth va en la base), `services-systemd` (ninguna unidad de
escritorio en su lista), `chwd`, `keyboard` (no escribe nada para Wayland ni
Hyprland), `bootloader`. Ya no existe `shellprocess@greetd`.

---

## Paso 14: `packages@online` (grupo Hyprland)

`src/modules/netinstall/netinstall.yaml:565-584`:

```yaml
- name: "Hyprland"
  selected: false
  critical: true
  packages:
    - hyprland
    - dolphin
    - kitty
    - sddm
    - cachyos-hypr-noctalia
```

Al ser `critical: true`, sus paquetes se suman a la **única transacción de
grupos críticos** del informe base (Paso 14); un fallo aborta la instalación:

```bash
chroot "$ROOT" pacman -S --noconfirm --noprogressbar --needed --disable-download-timeout \
    <lista crítica de la base> hyprland dolphin kitty sddm cachyos-hypr-noctalia
```

Dependencias relevantes que arrastra (versiones del repo el 2026-11-16):

| Paquete | Versión (repo) | Qué aporta / dependencias clave |
|---|---|---|
| `hyprland` | 0.57.2-1.1 (`cachyos-extra-v3`) | `/usr/bin/Hyprland`, `/usr/bin/start-hyprland`; sesiones `hyprland.desktop` (`Exec=…/start-hyprland`) y `hyprland-uwsm.desktop`; depende de `xorg-xwayland` |
| `sddm` | 0.21.0-8 (`cachyos-v3`) | Display manager (X11 como greeter); `sddm.service` con `Alias=display-manager.service`; depende de `xorg-server`, `qt6-declarative`, `ttf-font` |
| `cachyos-hypr-noctalia` | 1.2.6-1 (`cachyos`) | Dotfiles en `/etc/skel` (ver abajo). Depende de `adw-gtk-theme awesome-terminal-fonts brightnessctl cachyos-alacritty-config ddcutil curl dolphin gnome-calculator gnome-keyring gnome-text-editor grim hyprland hyprpicker kde-cli-tools kitty noctalia noto-fonts noto-fonts-emoji nwg-look python3 qt6ct qview slurp swash uwsm wl-clipboard xdg-desktop-portal-hyprland xorg-xhost`. `conflicts: cachyos-desktop-settings` |
| `noctalia` | 5.5.0-1.1 (`cachyos-extra-v3`) | La shell (barra, lanzador, notificaciones…); lanzada desde la config de Hyprland |
| `uwsm` | 0.27.2-1 (`extra`) | Gestor de sesión (sesión `hyprland-uwsm.desktop`) |

> Discrepancia: el PKGBUILD de `master` (pkgrel 2, `pkgbuilds:cachyos-hypr-noctalia/PKGBUILD:14-43`)
> sustituye `gnome-keyring` por la dependencia virtual `org.freedesktop.secrets`.
> Cuando se publique, con `--noconfirm` pacman elegirá el primer proveedor;
> habrá que comprobar que sigue siendo `gnome-keyring`.

Ficheros que instala `cachyos-hypr-noctalia` (148 ficheros,
`pkgbuilds:cachyos-hypr-noctalia/PKGBUILD:48-51` copia `etc/`, `usr/`, `var/`):

| Ruta | Contenido |
|---|---|
| `/etc/profile.d/Hyprland.sh` | Con módulo `nvidia` cargado y sin `i915`/`amdgpu`: `GBM_BACKEND=nvidia-drm`, `EGL_PLATFORM=wayland` |
| `/etc/skel/.config/hypr/hyprland.lua` + `config/*.lua` | Configuración de Hyprland **en Lua** (animaciones, autostart, binds, colores, decoraciones, entorno, inputs, misc, monitores, reglas, workspaces) |
| `/etc/skel/.config/uwsm/env` | `BROWSER=firefox`, `TERM=xterm-kitty`, `QT_QPA_PLATFORM="wayland;xcb"`, `QT_QPA_PLATFORMTHEME=qt6ct`, `ELECTRON_OZONE_PLATFORM_HINT=auto`, cursor `Bibata-Modern-Ice` 24 |
| `/etc/skel/.config/{kitty,noctalia,qt6ct,gtk-3.0,gtk-4.0,btop,swash,xsettingsd,menus}/…`, `kdeglobals`, `dolphinrc`, `mimeapps.list` | Tema y aplicaciones |
| `/etc/skel/.local/share/icons/Bibata-Modern-Ice/`, `/etc/skel/.icons/default/index.theme` | Cursor (hyprcursor + Xcursor) |
| `/usr/share/noctalia-greeter/config.toml` | `config.toml` de greetd para noctalia-greeter. **Resto**: con SDDM nadie lo usa |
| `/var/lib/noctalia-greeter/greeter.toml` (`backup`) | `allow_empty_password = true`, `session.default = "Hyprland (uwsm-managed)"`. **Resto inerte**: no hay greeter que lo lea |

Los dotfiles 1.2.6 están pensados para el greeter de `cachyos-dev`; con
`staging` se instalan igual y los dos ficheros del greeter quedan sin uso.

Autostart de la sesión (`hypr-noctalia:etc/skel/.config/hypr/config/autostart.lua:4-8`):
`dbus-update-activation-environment --systemd --all`, `noctalia`,
`xhost +SI:localuser:root`. Aplicaciones por defecto
(`config/variables.lua:3-7`): `kitty`, `dolphin`, `firefox`,
`gnome-text-editor`, `gnome-calculator`.

## Paso 9: `users` (consecuencia del orden)

En `staging` `users` va tras `initcpio`, es decir, **después** de la
transacción de netinstall (informe base, Paso 9). `useradd -m` copia
`/etc/skel` con los dotfiles de `cachyos-hypr-noctalia` ya instalados, así
que el usuario tiene la configuración de Hyprland sin depender de la recopia
del Paso 29 (que en `cachyos-dev` era imprescindible porque el usuario se
creaba antes que el escritorio).

## Paso 23: `displaymanager` (SDDM)

`displaymanager.conf:11-16` lista `plasmalogin sddm lightdm gdm cosmic-greeter
lxdm` (`greetd` comentado en `:17`); solo se configuran los que tienen
ejecutable en el target (`src/modules/displaymanager/main.py:1052-1068`,
`have_dm()` `:230-241`). Con Hyprland el único es **sddm**.

Escritorio por defecto: `displaymanager.conf` no define
`defaultDesktopEnvironment`, así que se busca en la lista fija
(`main.py:165-202`, `find_desktop_environment` `:205-217`). Ninguna entrada
anterior está instalada; casa la última:
`DesktopEnvironment('/usr/bin/Hyprland', 'hyprland')`.

Secuencia para SDDM (`main.py:1110-1127`, `DMsddm` `:747-792`), con
`basicSetup` ausente (→ falso) y sin autologin (`users.conf:36`
`doAutologin: false`): `desktop_environment_setup` y `greeter_setup` no hacen
nada; `set_autologin` (`:753-782`) lee `/etc/sddm.conf` si existe (el paquete
no lo trae: su configuración por defecto está en
`/usr/lib/sddm/sddm.conf.d/`), y escribe:

```ini
# $ROOT/etc/sddm.conf
[Autologin]
Session=hyprland
```

Sin `User=` no hay autologin; `Session=` solo se usa en el autologin, así que
el efecto práctico es nulo y SDDM recuerda la última sesión elegida. El
greeter queda con el tema por defecto del paquete (no hay paquete de tema de
CachyOS en el grupo). Este `/etc/sddm.conf` es el que `omarchy-on-cachyos`
borra antes de instalar Omarchy (ver [codigo-referencia.md](codigo-referencia.md#omarchy-on-cachyos-ya-no-se-usa)).

## Paso 29: `shellprocess` (principal)

Mismos comandos que en la base (`src/modules/shellprocess/shellprocess.conf:94-106`);
cambia el efecto de `dmcheck`.

### `dmcheck`

`iso:archiso/airootfs/usr/local/bin/dmcheck:18-54` comprueba paquetes con
`pacman -Qs <nombre>` en orden y cada coincidencia **sobrescribe** el enlace;
gana la última:

```bash
# :27-30
pacman -Qs sddm > /dev/null &&
  ln -sf /usr/lib/systemd/system/sddm.service /etc/systemd/system/display-manager.service
```

Resultado: **`display-manager.service` → `sddm.service`** (equivale a
`systemctl enable sddm`), salvo que alguna comprobación posterior case por
descripción (`plasma-login-manager`, `gdm`, `cosmic-greeter`, `lxdm`,
`lightdm`, `noctalia-greeter`, `:31-54`). Ningún paquete del grupo ni de sus
dependencias directas lleva esos nombres en la descripción (`noctalia`: «A
sleek, customizable desktop shell crafted for Wayland»;
`cachyos-hypr-noctalia`: «CachyOS Hyprland Noctalia settings»); a confirmar
en VM con todas las dependencias.

Igual que en la base, `pacman -Qs ly` (`:18-22`) casa por descripción y deja
el enlace roto `ly@tty2.service` (informe base, hallazgo 12).

### Recopia de `/etc/skel`

```bash
runuser $USER -c "cp -rf /etc/skel/. /home/$USER/."      # shellprocess.conf:100
```

Con `users` después de los paquetes es **redundante**: copia otra vez lo que
`useradd -m` ya copió.

---

## Estado final: diferencias con la instalación base

| Elemento | Sin escritorio | Con Hyprland |
|---|---|---|
| Paquetes explícitos añadidos | — | `hyprland dolphin kitty sddm cachyos-hypr-noctalia` (+ dependencias: `noctalia`, `uwsm`, `xdg-desktop-portal-hyprland`, `gnome-keyring`, `qt6ct`, `nwg-look`, `grim`, `slurp`, `wl-clipboard`, `xorg-xwayland`, `xorg-server`, `xorg-xhost`…) |
| Display manager | ninguno (`multi-user` + getty) | **SDDM** (`display-manager.service` → `sddm.service`), tema por defecto, sin autologin |
| `default.target` | `graphical.target` (el de systemd por defecto; no se toca en ningún caso) | igual |
| `/etc/sddm.conf` | — | `[Autologin]` con solo `Session=hyprland` |
| `$HOME` del usuario | skel de la base | + dotfiles Hyprland/Noctalia/uwsm/cursor/GTK/Qt |
| `/etc/profile.d/Hyprland.sh` | — | variables para NVIDIA sin iGPU |
| Restos del greeter | — | `/usr/share/noctalia-greeter/config.toml`, `/var/lib/noctalia-greeter/greeter.toml` (sin usar) |
| Enlace roto `ly@tty2.service` | **sí** | sí |

## Hallazgos y peculiaridades

1. **La elección de escritorio solo es una lista de paquetes.** Calamares no
   tiene lógica propia de Hyprland: todo sale de los 5 paquetes del grupo, de
   sus scriptlets, de `displaymanager` (genérico) y de `dmcheck`.
2. **El "Hyprland de CachyOS" empaquetado vuelve a llevar SDDM** (como el de
   NCI y como Omarchy). El de `cachyos-dev` (greetd + noctalia-greeter) no ha
   llegado a la ISO; es previsible que vuelva cuando se reunifiquen las
   ramas.
3. **Dotfiles y greeter desalineados**: `cachyos-hypr-noctalia` 1.2.6 trae la
   configuración de noctalia-greeter, que con SDDM queda sin uso. El
   `allow_empty_password = true` del `greeter.toml` deja de tener efecto.
4. **Teclado**: el módulo `keyboard` solo escribe `vconsole.conf`,
   `00-keyboard.conf` (X11) y `/etc/default/keyboard`. Hyprland no lee
   ninguno, y `config/inputs.lua` de `cachyos-hypr-noctalia` no define
   `kb_layout`, así que **Hyprland arranca con distribución `us`** aunque se
   haya elegido `es`. El greeter de SDDM (X11) sí debería tomar `es` de
   `00-keyboard.conf` (a confirmar).
5. `/etc/sddm.conf` con `[Autologin] Session=` sin `User=`: inocuo.
6. `xhost +SI:localuser:root` en el autostart permite a root abrir ventanas
   en la sesión (para herramientas gráficas con privilegios).
7. Con `users` tras los paquetes, la recopia del skel del Paso 29 ya no hace
   falta; sigue en `shellprocess.conf`.

## Diferencias con `cachyos-dev` (greetd)

Lo que hacía la rama auditada primero y `staging` no hace:

| Tema | `cachyos-dev` | `cachyos-staging` |
|---|---|---|
| DM del grupo Hyprland | `noctalia-greeter` (→ `greetd`, `greetd-agreety`) | `sddm` |
| `displaymanager` | configuraba greetd (`/etc/greetd/environments`, `config.toml` con `agreety`) | escribe `/etc/sddm.conf` |
| `shellprocess@greetd` | copiaba `/usr/share/noctalia-greeter/config.toml` a `/etc/greetd/` y ajustaba el usuario `greeter` | no existe |
| `dmcheck` | `display-manager.service` → `greetd.service` | → `sddm.service` |
| Usuario de sistema | `greeter` (sysusers de `greetd`) | ninguno nuevo (SDDM usa el suyo, `sddm`) |
| Seguridad | `allow_empty_password = true` activo en el greeter | inerte |
| Orden de `users` | antes del escritorio → los dotfiles llegaban solo por la recopia del skel | después → los copia `useradd -m` |

## Pendiente de verificar en VM

- Que la transacción crítica resuelve igual con Hyprland (sin conflictos con
  los paquetes de la base, p. ej. `cachyos-alacritty-config`).
- Paquetes realmente instalados (`pacman -Qe`, `pacman -Qd`) y unidades
  activas (`systemctl list-unit-files --state=enabled`), incluidas las que
  activen los scriptlets de las dependencias nuevas.
- Destino final de `display-manager.service` (que ninguna comprobación
  posterior de `dmcheck` case por descripción).
- Distribución de teclado efectiva en el greeter de SDDM y en Hyprland.
- Comportamiento con NVIDIA (`chwd` + `/etc/profile.d/Hyprland.sh`).
