# Anexo: Calamares con escritorio Hyprland

Anexo de [auditoria-calamares-base.md](auditoria-calamares-base.md). Recoge
**solo lo que cambia** respecto a la instalación base cuando en el paso
*Escritorio* se elige **Hyprland** en lugar de *No Desktop*. Todo lo demás
(particionado, LUKS, `pacstrap`, usuarios, locale, initramfs, bootloader,
servicios, ufw…) es idéntico y no se repite.

## Versiones auditadas

| Componente | Repo / origen | Rama/tag/versión | Commit | Nota |
|---|---|---|---|---|
| Calamares | `CachyOS/cachyos-calamares` | `cachyos-dev` | `199d71543` (2026-09-26) | Igual que el informe base. |
| `netinstall.yaml` remoto | `raw.githubusercontent.com/…/cachyos-dev/…/netinstall.yaml` | descargado 2026-11-15 | — | **Idéntico** a la copia de `199d71543` (`diff` vacío). Es el que se usa en ejecución. |
| PKGBUILDs | `CachyOS/CachyOS-PKGBUILDS` | `master` | `6c6dc36` (2026-11-15) | `cachyos-hypr-noctalia/` (pkgver 1.2.6, **pkgrel 2**). |
| `cachyos-hypr-noctalia` | `cachyos/cachyos-hypr-noctalia` | tag `1.2.6` | — | Tarball de GitHub (el que usa el PKGBUILD). El repo `cachyos` sirve aún **1.2.6-1**. |
| Paquetes binarios | repos de CachyOS (2026-11-15) | ver tabla del [Paso 14](#paso-14-packagesonline-grupo-hyprland) | — | Contenido inspeccionado de `greetd` y `noctalia-greeter` (`cachyos-extra-v3`). |

Rutas citadas: como en el informe base (sin prefijo = `cachyos-calamares/`;
`pkgbuilds:` = `CachyOS-PKGBUILDS/`). Nuevos prefijos:

- `hypr-noctalia:` = árbol del tag `1.2.6` de `cachyos-hypr-noctalia`.
- `pkg:<nombre>:` = contenido del paquete binario `<nombre>` del repo.

## Cómo llega la elección a la instalación

1. `packagechooser@desktop` (`settings_online.conf:38-40`, vista en `:66`) usa
   `packagechooser_desktop.conf` con `method: netinstall-select`
   (`src/modules/packagechooser/packagechooser_desktop.conf:8`). La entrada
   elegida es `id: Hyprland` (`:185-197`).
2. Con `netinstall-select`, el id elegido se añade a la clave
   `netinstallSelect` de GlobalStorage (`src/modules/packagechooser/Config.cpp:169-199`).
3. `netinstall` marca el grupo cuyo **nombre** coincide (`"Hyprland"`,
   `src/modules/netinstall/NetInstallPage.cpp:70-72`). No hay otra forma de
   que la elección de escritorio llegue a los módulos de `exec`: **ningún módulo
   de instalación lee `packagechooser_desktop`**. Todo lo que cambia después se
   deriva de los paquetes instalados.
4. La UI de netinstall impide avanzar si quedan seleccionados dos paquetes de
   dotfiles de escritorio (`src/modules/netinstall/PackageModel.cpp:236-268`,
   lista que incluye `cachyos-hypr-noctalia`).

## Resumen: pasos de `exec` que cambian

Numeración del informe base. Los no listados se comportan igual que sin
escritorio.

| # | Módulo | Sin escritorio | Con Hyprland |
|---|---|---|---|
| 14 | `packages@online` | grupos preseleccionados | + grupo **Hyprland** (crítico) en la misma transacción |
| 23 | `displaymanager` | no-op | **actúa**: configura `greetd` (`environments`, `config.toml`) |
| 29 | `shellprocess` | `dmcheck` sin efecto útil; recopia skel | `dmcheck` enlaza `display-manager.service` → `greetd`; la recopia de skel trae los **dotfiles de Hyprland** |
| 31 | `shellprocess@greetd` | no-op | **actúa**: sustituye `config.toml` por el de noctalia-greeter y ajusta el usuario `greeter` |

Sin cambios con Hyprland (comprobado): `plymouthcfg`, `initcpiocfg` e
`initcpio` (plymouth ya va en la base), `services-systemd` (ninguna unidad de
escritorio en su lista), `chwd`, `keyboard` (no escribe nada para Wayland ni
Hyprland), `bootloader`.

---

## Paso 14: `packages@online` (grupo Hyprland)

`src/modules/netinstall/netinstall.yaml:605-625`:

```yaml
- name: "Hyprland"
  platform: "desktop"
  critical: true
  packages:
    - hyprland
    - dolphin
    - kitty
    - noctalia-greeter
    - cachyos-hypr-noctalia
```

Al ser `critical: true`, sus paquetes se suman a la **única transacción de
grupos críticos** del informe base (Paso 14); un fallo aborta la instalación:

```bash
chroot "$ROOT" pacman -S --noconfirm --noprogressbar --needed --disable-download-timeout \
    <lista crítica de la base> hyprland dolphin kitty noctalia-greeter cachyos-hypr-noctalia
```

Dependencias relevantes que arrastra (versiones del repo el 2026-11-15):

| Paquete | Versión (repo) | Qué aporta / dependencias clave |
|---|---|---|
| `hyprland` | 0.57.2-1.1 (`cachyos-extra-v3`) | `/usr/bin/Hyprland`, `/usr/bin/start-hyprland`; sesiones `hyprland.desktop` (`Exec=…/start-hyprland`) y `hyprland-uwsm.desktop`; depende de `xorg-xwayland` |
| `cachyos-hypr-noctalia` | 1.2.6-1 (`cachyos`) | Dotfiles en `/etc/skel` (ver abajo). Depende de `adw-gtk-theme awesome-terminal-fonts brightnessctl cachyos-alacritty-config ddcutil curl dolphin gnome-calculator gnome-keyring gnome-text-editor grim hyprland hyprpicker kde-cli-tools kitty noctalia noto-fonts noto-fonts-emoji nwg-look python3 qt6ct qview slurp swash uwsm wl-clipboard xdg-desktop-portal-hyprland xorg-xhost`. `provides/conflicts: cachyos-desktop-settings` |
| `noctalia` | 5.5.0-1.1 (`cachyos-extra-v3`) | La shell (barra, lanzador, notificaciones…); lanzada desde la config de Hyprland |
| `noctalia-greeter` | 1.7.0-1.1 (`cachyos-extra-v3`) | Greeter para greetd; `provides: greetd-greeter`; depende de `greetd`, `wlroots0.20` |
| `greetd` | 0.10.3-2.1 (`cachyos-extra-v3`) | Demonio; depende de `greetd-agreety` y `greetd-greeter` (lo satisface `noctalia-greeter`) |
| `uwsm` | 0.27.2-1 (`extra`) | Gestor de sesión: la sesión por defecto del greeter es la de uwsm |

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
| `/usr/share/noctalia-greeter/config.toml` | `config.toml` de greetd para noctalia-greeter (lo usa el Paso 31) |
| `/var/lib/noctalia-greeter/greeter.toml` (`backup`) | `scheme = "Synced"`, **`allow_empty_password = true`**, `session.default = "Hyprland (uwsm-managed)"` |

Autostart de la sesión (`hypr-noctalia:etc/skel/.config/hypr/config/autostart.lua:4-8`):
`dbus-update-activation-environment --systemd --all`, `noctalia`,
`xhost +SI:localuser:root`. Aplicaciones por defecto
(`config/variables.lua:3-7`): `kitty`, `dolphin`, `firefox`,
`gnome-text-editor`, `gnome-calculator`.

Otros efectos de los scriptlets de los paquetes (no de Calamares):

- `greetd` instala `/usr/lib/sysusers.d/greetd.conf`: crea el usuario de
  sistema **`greeter`** (shell `/bin/bash`) y lo añade a `video`.
- `noctalia-greeter` instala `/usr/lib/tmpfiles.d/noctalia-greeter.conf`:
  `d /var/lib/noctalia-greeter 0750 greeter greeter`.
- `greetd.service` (`pkg:greetd:usr/lib/systemd/system/greetd.service`):
  `Conflicts=getty@tty1.service`, `[Install] Alias=display-manager.service`.

## Paso 23: `displaymanager` (greetd)

`displaymanager.conf:11-17` lista `plasmalogin sddm lightdm gdm cosmic-greeter
lxdm greetd`; solo se configuran los que tienen ejecutable en el target
(`src/modules/displaymanager/main.py:1065-1090`, `have_dm()` `:230-241`).
Con Hyprland el único es **greetd** (`/usr/bin/greetd`); no entra `sddm`.

Escritorio por defecto: `displaymanager.conf` no define
`defaultDesktopEnvironment`, así que se busca en la lista fija
(`main.py:163-201`, `find_desktop_environment` `:204-217`). Ninguna entrada
anterior está instalada; casa la última:
`DesktopEnvironment('/usr/bin/Hyprland', 'hyprland')` (existen
`/usr/share/wayland-sessions/hyprland.desktop` y `/usr/bin/Hyprland`).

Secuencia para greetd (`main.py:1123-1141`, `DMgreetd` `:882-972`), con
`basicSetup` ausente (→ falso, `:1106-1109`) y sin autologin
(`users.conf:36` `doAutologin: false` → `do_autologin = False`, `:1111-1116`):

```bash
# basic_setup: NO se ejecuta (no hace groupadd/useradd; el usuario greeter lo crea sysusers)

# desktop_environment_setup (:941-944)
printf '/usr/bin/Hyprland\n' > "$ROOT/etc/greetd/environments"

# greeter_setup: nada

# set_autologin (:949-974): carga /etc/greetd/config.toml del paquete (toml),
#   pone terminal.vt = "next", default_session.user = "greeter" (de displaymanager.conf:32),
#   y como no hay gtkgreet+cage, tuigreet ni ddlm:
#   default_session.command = "agreety --cmd /usr/bin/Hyprland"
#   sin initial_session (no autologin). Reescribe el fichero con toml.dump (pierde comentarios).
```

`$ROOT/etc/greetd/config.toml` tras este paso:

```toml
[terminal]
vt = "next"

[default_session]
command = "agreety --cmd /usr/bin/Hyprland"
user = "greeter"
```

Este `config.toml` **es transitorio**: el Paso 31 lo sustituye. Lo que sí
queda es `/etc/greetd/environments` (`/usr/bin/Hyprland`, que lanza Hyprland
sin `start-hyprland` ni uwsm); noctalia-greeter no lo usa (lee las sesiones de
`/usr/share/wayland-sessions/`), así que es un resto inocuo.

## Paso 29: `shellprocess` (principal)

Mismos comandos que en la base (`src/modules/shellprocess/shellprocess.conf:96-101`);
cambian los efectos de dos:

### `dmcheck`

`src/scripts/dmcheck` comprueba paquetes con `pacman -Qs <nombre>` en orden y
cada coincidencia **sobrescribe** el enlace; gana la última. La última comprobación es:

```bash
# src/scripts/dmcheck:44-47
pacman -Qs noctalia-greeter > /dev/null &&
  ln -sf /usr/lib/systemd/system/greetd.service /etc/systemd/system/display-manager.service
```

Resultado: **`display-manager.service` → `greetd.service`**. Equivale a
`systemctl enable greetd` (la unidad declara `Alias=display-manager.service`).
Antes, la línea `:96` borra cualquier `display-manager.service` previo.

> **Hallazgo (afecta también a la base)**: `pacman -Qs` busca la expresión
> regular en nombres **y descripciones**. `pacman -Qs ly` (`dmcheck:14-18`)
> coincide con casi cualquier sistema (en esta máquina, 36 paquetes), así que
> **siempre** se ejecuta:
>
> ```bash
> rm -f /etc/systemd/system/getty.target.wants/getty@tty2.service
> ln -sf /usr/lib/systemd/system/ly@.service /etc/systemd/system/multi-user.target.wants/ly@tty2.service
> ```
>
> Sin `ly` instalado queda un **enlace roto** `ly@tty2.service` en
> `multi-user.target.wants`. El informe base dice "sin DM → no hace nada"; es
> inexacto. Lo mismo vale para los demás `pacman -Qs` (`sddm`, `gdm`,
> `lightdm`…): pueden casar por descripción, pero con Hyprland da igual porque
> `noctalia-greeter` es la última comprobación.

### Recopia de `/etc/skel`

```bash
runuser $USER -c "cp -rf /etc/skel/. /home/$USER/."      # shellprocess.conf:101
```

El usuario se crea en el Paso 9 (antes de instalar el escritorio), así que el
`useradd -m` solo copió el skel de la base. **Esta línea es la que lleva los
dotfiles de `cachyos-hypr-noctalia` al `$HOME` del usuario** (`.config/hypr`,
`.config/uwsm/env`, `.config/noctalia`, cursor…). Sin ella, el usuario
arrancaría Hyprland sin la configuración de CachyOS.

## Paso 31: `shellprocess@greetd`

`settings_online.conf:46-48` y `:101`;
`src/modules/shellprocess/shellprocess_greetd.conf:8-16`, en el target:

```bash
if pacman -Qs noctalia-greeter >/dev/null 2>&1; then
  cp -f /usr/share/noctalia-greeter/config.toml /etc/greetd/config.toml
  usermod -d /var/lib/noctalia-greeter -s /usr/bin/nologin greeter
  chown -R root: /etc/greetd
  chmod 644 /etc/greetd/config.toml
fi
```

- La fuente `/usr/share/noctalia-greeter/config.toml` **no es de
  `noctalia-greeter`** (el paquete 1.7.0 no la trae) sino de
  `cachyos-hypr-noctalia` (`hypr-noctalia:usr/share/noctalia-greeter/config.toml`).
  Si faltara, el `cp` fallaría en silencio (el código de salida del script es
  el del último `chmod`) y quedaría el `config.toml` de `agreety` del Paso 23.
- Usuario `greeter`: home `/var/lib/noctalia-greeter`, shell `/usr/bin/nologin`
  (sysusers lo creó con `/bin/bash`).

`/etc/greetd/config.toml` final:

```toml
[terminal]
vt = 1

[default_session]
command = "/usr/bin/noctalia-greeter-session"
user = "greeter"
```

---

## Estado final: diferencias con la instalación base

| Elemento | Sin escritorio | Con Hyprland |
|---|---|---|
| Paquetes explícitos añadidos | — | `hyprland dolphin kitty noctalia-greeter cachyos-hypr-noctalia` (+ dependencias: `noctalia`, `greetd`, `greetd-agreety`, `uwsm`, `xdg-desktop-portal-hyprland`, `gnome-keyring`, `qt6ct`, `nwg-look`, `grim`, `slurp`, `wl-clipboard`, `xorg-xwayland`, `xorg-xhost`…) |
| Display manager | ninguno (`multi-user` + getty) | **greetd** (`display-manager.service` → `greetd.service`) en **tty1** con **noctalia-greeter**; sin autologin |
| `default.target` | `graphical.target` (el de systemd por defecto; no se toca en ningún caso) | igual |
| Sesión por defecto del greeter | — | `Hyprland (uwsm-managed)` (`greeter.toml`) |
| Usuario de sistema | — | `greeter` (grupo `greeter`, en `video`; home `/var/lib/noctalia-greeter`, shell `nologin`) |
| `/etc/greetd/` | — | `config.toml` (noctalia), `environments` (`/usr/bin/Hyprland`, resto), `root:root` |
| `/var/lib/noctalia-greeter/greeter.toml` | — | `allow_empty_password = true`, `scheme = "Synced"` |
| `$HOME` del usuario | skel de la base | + dotfiles Hyprland/Noctalia/uwsm/cursor/GTK/Qt |
| `/etc/profile.d/Hyprland.sh` | — | variables para NVIDIA sin iGPU |
| Enlace roto `ly@tty2.service` | **sí** | sí |

## Hallazgos y peculiaridades

1. **La elección de escritorio solo es una lista de paquetes.** Calamares no
   tiene lógica propia de Hyprland: todo sale de los 5 paquetes del grupo, de
   sus scriptlets, de `displaymanager` (genérico), de `dmcheck` y de
   `shellprocess@greetd` (ambos condicionados a que esté instalado
   `noctalia-greeter`).
2. **El "Hyprland de CachyOS" ya no lleva SDDM.** Usa greetd + noctalia-greeter
   y la shell Noctalia. Lo que dice `CLAUDE.md` / el README de
   `omarchy-on-cachyos` sobre que deja `/etc/sddm.conf` corresponde a la
   versión anterior (`cachyos-hyprland-settings`, que sigue en
   `CachyOS-PKGBUILDS` pero ya no la instala Calamares).
3. **La configuración del usuario depende de la recopia del skel** del Paso 29
   (el usuario existe antes de instalar el escritorio).
4. **Teclado**: el módulo `keyboard` solo escribe `vconsole.conf`,
   `00-keyboard.conf` (X11) y `/etc/default/keyboard`. Hyprland no lee
   ninguno, y `config/inputs.lua` de `cachyos-hypr-noctalia` no define
   `kb_layout`, así que **Hyprland arranca con distribución `us`** aunque se
   haya elegido `es`. `greeter.toml` tampoco tiene sección `[keyboard]`.
5. **`allow_empty_password = true`** en el greeter (habilita autenticación PAM
   sin contraseña, p. ej. huella). Con contraseña de usuario no cambia nada,
   pero es una desviación de seguridad a tener presente.
6. `/etc/greetd/environments` queda con `/usr/bin/Hyprland` (sin uwsm ni
   `start-hyprland`): resto inocuo del módulo genérico.
7. `xhost +SI:localuser:root` en el autostart permite a root abrir ventanas
   en la sesión (para herramientas gráficas con privilegios).
8. El `config.toml` del greeter depende de un fichero de los dotfiles, no del
   greeter: si `cachyos-hypr-noctalia` dejara de traerlo, el fallo sería
   silencioso y el sistema arrancaría con `agreety` (texto).

## Pendiente de verificar en VM

- Que la transacción crítica resuelve igual con Hyprland (sin conflictos con
  los paquetes de la base, p. ej. `cachyos-alacritty-config`).
- Paquetes realmente instalados (`pacman -Qe`, `pacman -Qd`) y unidades
  activas (`systemctl list-unit-files --state=enabled`), incluidas las que
  activen los scriptlets de las dependencias nuevas.
- Contenido final de `/etc/greetd/` y del home de `greeter`;
  permisos de `/var/lib/noctalia-greeter` (paquete vs tmpfiles).
- Distribución de teclado efectiva en noctalia-greeter y en Hyprland.
- Que `ly@tty2.service` roto aparece también en la instalación base.
- Comportamiento con NVIDIA (`chwd` + `/etc/profile.d/Hyprland.sh`).
