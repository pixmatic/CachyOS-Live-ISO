# Auditoría de Omarchy 4.5 (instalación y paquetes)

Qué hace Omarchy 4.x al instalarse, qué deja en el sistema y qué choca con
CachyOS y con las decisiones de nuestro instalador (ver
[decisiones.md](decisiones.md)). Sustituye como referencia al script
`omarchy-on-cachyos`, que solo funciona con Omarchy `v3.x` (clon borrado el
2026-11-16; su lista de conflictos se comprueba aquí uno a uno, en la
[sección 9](#9-conflictos-de-omarchy-on-cachyos-comprobados-en-4x)).

Las consecuencias para el sistema que dejaría nuestro instalador están en
[sistema-resultante-hyprland.md](sistema-resultante-hyprland.md).

## Versiones auditadas

| Componente | Repo | Rama/tag | Commit | Nota |
|---|---|---|---|---|
| Omarchy | `basecamp/omarchy` (= `omacom/omarchy`) | tag **`v4.5.0`** | `ac2690cd7` (2026-11-04) | Último estable (publicado el 2026-11-05). La rama por defecto `quattro` va 569 commits por delante. |
| Paquetes `omarchy` y `omarchy-settings` 4.5.0-2 | `omacom/omarchy-pkgs` | `master` | `d727707b` (2026-11-15) | Se compilan desde `a948d8a68`, **no desde el tag**: es un commit hermano (rama de la release) con 1 commit propio; el tag tiene 10 más. Lo que difiere es interfaz (QML, i18n, menú) y `install/user/first-run/wifi.sh`, nada de lo que audita este documento. |
| ISO de Omarchy | `omacom/omarchy-iso` | rama **`v4-5-0`** (no tiene tags) | `2f22117aa` (2026-11-04) | La ISO con la que se publica 4.5.0. |
| Paquetes de CachyOS que se citan | repos de CachyOS (2026-11-16) | — | — | `limine-mkinitcpio-hook` 1.40.0-1, inspeccionado del paquete binario. |

Clones en `pixmatic_autoinstall/upstream-src/` (ignorados por git):
`omarchy/` (detached en `v4.5.0`), `omarchy-iso/` (detached en
`origin/v4-5-0`) y `omarchy-pkgs/` (`master`), todos blobless.

Prefijos de las rutas citadas: sin prefijo = `omarchy/`; `iso:` =
`omarchy-iso/`; `pkgs:` = `omarchy-pkgs/`; `orq:` =
`iso:configs/airootfs/usr/share/omarchy-iso/orchestrator/`.

## Resumen

1. **Omarchy 4.x ya no es un script que se ejecuta sobre un Arch instalado.**
   La única instalación soportada es su ISO (`iso:README.md:5`), que escribe
   con `dd` una **imagen raíz btrfs ya construida** (≈900 paquetes,
   `iso:builder/build-root-image.sh:3-14`) y después ejecuta en chroot los
   comandos del paquete `omarchy`. El repo `omarchy` solo trae «comandos del
   lado del destino y piezas reutilizables»
   (`agents/skills/install-scripts.md:5-7`). No hay `install.sh`: lo que
   adaptaba `omarchy-on-cachyos` ya no existe.
2. Lo reutilizable sobre otro sistema es: los paquetes del repo `[omarchy]`
   (`omarchy`, `omarchy-settings`, el escritorio Quickshell y 32 aplicaciones
   propias), las listas `install/omarchy-*.packages`, y tres
   comandos idempotentes: `omarchy-apply-system` (root),
   `omarchy-provision-user` (usuario) y `omarchy-provision-first-run` (primer
   inicio de sesión).
3. **Conflicto principal: el arranque.** En x86_64 el paquete `omarchy`
   **depende** de `limine`, `limine-mkinitcpio-hook`,
   `limine-snapper-sync` y `snapper` (`pkgs:pkgbuilds/omarchy/PKGBUILD:73-78`).
   `limine-mkinitcpio-hook` sustituye el hook de pacman de mkinitcpio,
   pone un envoltorio en `/usr/local/bin/mkinitcpio` y, al instalarse,
   **despliega Limine en la ESP** (ver [sección 4](#4-arranque-limine-y-mkinitcpio)).
   No puede convivir con systemd-boot.
4. **`omarchy-settings` impone el initramfs**: un drop-in
   `/etc/mkinitcpio.conf.d/00-omarchy-hooks.conf` con `HOOKS` **busybox**
   (`udev … encrypt … btrfs-overlayfs`). Rompe el diseño de nuestro
   instalador (initramfs con systemd, `sd-encrypt`, gpt-auto sin `root=`).
5. **`pacman.conf`**: `omarchy-apply-system` **sustituye** `/etc/pacman.conf`
   y el mirrorlist por los de Omarchy (`[omarchy]` + Arch con su mirror
   congelado), lo que elimina los repos de CachyOS.
6. Otros choques: `/etc/os-release` pasa a `ID=omarchy`; `plymouthd.conf`,
   `nsswitch.conf`, `faillock.conf` y `/etc/skel/.bashrc` se sobrescriben en
   cada actualización de `omarchy-settings`; NVIDIA se instala con
   `nvidia-open-dkms` de Arch/Omarchy en vez de `chwd`; kernel
   `linux-omarchy`.
7. Lo que encaja sin esfuerzo: NetworkManager (Omarchy 4.x **no usa iwd**),
   SDDM con autologin solo si hay LUKS, snapper, ufw, PipeWire, btrfs con ESP
   en `/boot`, zram, y el teclado (la config de Hyprland de Omarchy lee `XKBLAYOUT` de
   `/etc/vconsole.conf`). **Omarchy 4.x no exige fish**: su shell es bash, y
   fish es opcional (paquete `omarchy-fish`).

## 1. Cómo se instala Omarchy 4.5 (ISO de Omarchy)

Entrada: `iso:configs/airootfs/usr/local/bin/omarchy-iso-install`
(tras el asistente) → `python -m orchestrator.main`. Fases en orden
(`orq:main.py:50-72`); cada una aborta la instalación si falla
(`orq:phases.py:45-63`):

| # | Fase | Qué hace (función en `orq:phases_impl.py`) |
|---|---|---|
| 1 | Preparing live environment | `prepare_live` (`:268`). |
| 2 | Preparing install target | `prepare_install_target` (`:308`): verifica el medio y el disco. |
| 3 | Installing Arch + Omarchy | `arch_install_system` (`:604-743`), con archinstall como librería: particiona, formatea y cifra (LUKS opcional); monta `@`, `@home`, `@log`, `@pkg` y la ESP (`:752`); **escribe la imagen raíz encima** (`_install_root_image`); instala el «delta por máquina» (firmware de audio, cabeceras de otro kernel, paquetes de la plataforma) con los hooks de mkinitcpio **enmascarados** (`_mask_mkinitcpio_pacman_hooks`, `:1819`); teclado con `systemd-firstboot --keymap` (`orq:keyboard.py`); mirrors; zram; `_configure_limine_boot`; **crea el usuario después de los paquetes** (`:705`, `useradd -m` copia `/etc/skel` de `omarchy-settings`); zona horaria, NTP, contraseña de root y `genfstab` (`:743`). |
| 4 | Configuring hibernation | `configure_hibernation` (`:2141`): `omarchy-hibernation-setup --force --no-rebuild` (swapfile en `/swap/swapfile`, `resume=` en un drop-in de **limine-entry-tool**). |
| 5 | Configuring system | `run_system_finalizer` (`:2406`): `omarchy-apply-system --install-user <u> --first-install` en chroot ([sección 2](#2-omarchy-apply-system-root)). |
| 6 | Staging provisioning | Solo para «instalar para otro dueño» (usuario creado en el primer arranque). |
| 7 | Finalizing boot and user | En paralelo: `finalize_limine_boot` (`:2686`: `limine-install`, UKI, entrada EFI) y `omarchy-provision-user --force --first-install` como el usuario (`:2923`). |
| 8 | Configuring login | `configure_login` (`:2994-3040`): `/etc/sddm.conf.d/99-omarchy-login.conf` (`Current=omarchy`, recordar usuario y sesión); **autologin solo si el disco está cifrado** (`autologin.conf` con `User=<u>`, `Session=omarchy.desktop`; la frase de LUKS es la frontera de autenticación); `/var/lib/sddm/state.conf`; borra el autologin de `getty@tty1`; `systemctl enable sddm`. |
| 9-10 | SSH / Tailscale | Solo si la unidad de autoinstalación trae claves. Por defecto `sshd` queda desactivado. |
| 11 | Configuring DNS resolver | `configure_dns_resolver` (`:2964`): `/etc/resolv.conf` → stub de `systemd-resolved`. |
| 12 | Validating boot setup | Comprueba entradas de Limine, cabeceras del kernel, firmas. |
| 13 | Creating factory snapshot | `create_factory_snapshot` (`:3735`): snapshot de snapper para «restablecer de fábrica». |

Contenido de la imagen raíz (`iso:builder/build-iso.sh:840-878`):
`archinstall.packages` (base, `linux-omarchy` + headers, microcódigos,
limine, snapper, openssh, pipewire…) + `image.packages` (base-devel, git,
efibootmgr, `omarchy-keyring`, lua…) + **`install/omarchy-base.packages`**
+ `omarchy`, `omarchy-settings`, `omarchy-nvim`. La imagen trae un UKI ya
construido con `/etc/kernel/cmdline` de reserva; la cmdline real la pone
Limine (`orq:uki_cmdline.py:1-15`).

Conclusión para nosotros: **no hay nada que «ejecutar» de la ISO**; hay que
replicar en nuestro instalador lo que hace el orquestador alrededor de los
comandos de Omarchy (fases 3, 5, 7, 8 y 11), igual que replicamos Calamares.

## 2. `omarchy-apply-system` (root)

`bin/omarchy-apply-system` exige root y un usuario existente
(`:61-78`), y ejecuta en este orden (`:88-102`), con registro en
`/var/log/omarchy-install.log`:

**`install/config/all.sh`**

| Script | Efecto en el sistema |
|---|---|
| `theme-system.sh` | Enlaces de iconos Yaru; `/usr/lib/chromium/initial_preferences`. |
| `browser-policy.sh` | Políticas gestionadas de Chromium en `/etc/chromium/policies/managed`. |
| `increase-lockout-limit.sh` | `sed` sobre `/etc/pam.d/system-auth` (faillock `deny=10 unlock_time=120`) y `/etc/pam.d/sddm-autologin`. **Edita ficheros de `pambase`/`sddm`** → `.pacnew` en futuras actualizaciones. |
| `lockscreen-pam.sh` | `omarchy-apply-lock` (PAM del bloqueo de pantalla). |
| `ssh-command-path.sh` | Añade `PATH` a `/etc/security/pam_env.conf` (de `pam`). |
| `ssh-keepalive.sh` | `/etc/ssh/ssh_config.d/20-omarchy-keepalive.conf`. |
| `docker.sh` | Nada (documenta que el usuario **no** entra en el grupo `docker`). |
| `locale.sh` | Solo si `LANG` está vacío o es `C`/`POSIX`: pone `en_US.UTF-8`. Con `es_ES.UTF-8` no toca nada (`:19-25`). |
| `language.sh` | Idioma del escritorio por usuario si existe `/etc/omarchy/language` (lo escribe la ISO). |
| `snapper.sh` | Crea la config `root` si no existe, la sustituye por la plantilla de Omarchy (`default/snapper/root`: `NUMBER_LIMIT=5`, `TIMELINE_CREATE=no`), `SNAPPER_CONFIGS="root"`, desactiva `snapper-timeline.timer`, activa `snapper-cleanup.timer` y **`limine-snapper-sync.service`** (`:23-24`). |
| `enable-services.sh` | `enable`: `cups`, `avahi-daemon`, `linux-modules-cleanup`, `docker.socket`, `systemd-resolved`, `NetworkManager`, `power-profiles-daemon`, **`sddm`**, `systemd-oomd`; **`mask NetworkManager-wait-online`**. |
| `firewall.sh` | ufw: deny entrante, allow saliente, LocalSend (53317), DNS de Docker; reglas `ufw-docker`; `ENABLED=yes` y `enable ufw`. |

**`omarchy-apply-hardware`** (`install/hardware/all.sh`): ~50 scripts
condicionados al hardware. Los que actúan en un PC genérico x86:

| Script | Efecto |
|---|---|
| `network.sh` | `disable iwd`, desactiva `systemd-networkd*`, `mask systemd-networkd-wait-online`, retira los `.network` de archinstall. |
| `set-wireless-regdom.sh`, `fix-fkeys.sh`, `bluetooth.sh` | Dominio wifi, teclas Fn, `enable bluetooth`. |
| `nvidia.sh` | Con GPU NVIDIA: `omarchy-pkg-add nvidia-open-dkms nvidia-utils lib32-nvidia-utils libva-nvidia-driver` (o la rama `580xx` sin GSP), `/etc/modprobe.d/nvidia.conf` (`modeset=1`) y `/etc/mkinitcpio.conf.d/nvidia.conf` (carga temprana). |
| `intel/*`, `vulkan.sh` | Drivers de vídeo/Vulkan, `thermald`, `intel-lpmd`, `sof-firmware` según CPU/GPU. |
| `pacman.sh` | Solo en Mac T2: añade el repo `[arch-mact2]`. |

**`install/login/all.sh`** → `sddm.sh`: quita `pam_gnome_keyring` de
`/etc/pam.d/sddm`. El autologin lo decide la ISO (fase 8), no este script.

**`install/post-install/all.sh`**

| Script | Efecto |
|---|---|
| `pacman.sh` | **`omarchy-apply-pacman <canal>`**: copia `default/pacman/pacman-stable.conf` sobre **`/etc/pacman.conf`** y `mirrorlist-stable` sobre **`/etc/pacman.d/mirrorlist`** (guarda `.bak`), ver [sección 5](#5-repositorios-y-pacmanconf). Instala `cups-files.conf` endurecido. |
| `udev.sh` | `udevadm control --reload`. |
| `localdb.sh` | `updatedb` (excluye `/.snapshots`). |

## 3. Usuario: `/etc/skel`, `omarchy-provision-user` y primer inicio

Tres capas (`docs/file-layout.md:33-48`):

1. **Semilla**: `omarchy-settings` instala todo `config/**` en
   `/etc/skel/.config/` y `useradd -m` lo copia. Por eso la ISO crea el
   usuario **después** de los paquetes; es lo mismo que decidimos para
   nuestro instalador (un único `pacstrap` y usuario después).
2. **Finalización** (`omarchy-provision-user --force --first-install`, como
   el usuario, en chroot): enlaces de *skills* de agentes,
   `xdg-user-dirs-update`, navegador por defecto Chromium, lanzadores
   `.desktop`, y `install/user/all.sh` (tema, Chromium, XCompose, idioma,
   método de entrada, `mise reshim`, llavero por defecto sin contraseña,
   arreglos por hardware) (`docs/file-layout.md:264-290`).
3. **Primer inicio de sesión** (`omarchy-provision-first-run`): activa las
   unidades de usuario (`bt-agent`, `omarchy-sleep-lock`, …), ajustes
   GNOME/GTK, avisos de bienvenida y wifi (`docs/file-layout.md:326-357`).

Teclado: la config de Hyprland de Omarchy lee `XKBLAYOUT`/`XKBVARIANT` de
`/etc/vconsole.conf` (`default/hypr/input.lua:12-15`, con `us` si falta;
`docs/file-layout.md:273-274`); la ISO lo escribe con
`systemd-firstboot --keymap` (`orq:keyboard.py`). Con `KEYMAP=es` y
`XKBLAYOUT=es` en `vconsole.conf`, Hyprland queda en `es` sin tocar
`hyprland.lua`: se evita el fallo de ambos instaladores oficiales
(Hyprland en `us`).

Shell: `omarchy-settings` copia su `default/bashrc` sobre
`/etc/skel/.bashrc` en **cada** instalación/actualización
(`pkgs:pkgbuilds/omarchy-settings/omarchy-settings.install:70-120`), y el
entorno (`OMARCHY_PATH`, `PATH` con mise) llega por
`/etc/profile.d/omarchy.sh`, `.bashrc` y `uwsm/env.d`
(`docs/file-layout.md:225-247`). En `bin/`, `install/`, `etc/` y `config/`
no hay ninguna referencia a fish. Existe un paquete opcional
`omarchy-fish` 1.5.0 (`pkgs:pkgbuilds/omarchy-fish/`, depende de `fish eza
mise zoxide starship fzf fd bat`).

## 4. Arranque: Limine y mkinitcpio

### Dependencias

`pkgs:pkgbuilds/omarchy/PKGBUILD`:

- `depends` (`:27-64`): `omarchy-keyring`, `omarchy-themes-intros`,
  `omarchy-settings=4.5.0`, `hyprland`, `quickshell`, `uwsm`, `sddm`,
  `xdg-desktop-portal-hyprland`, `wireplumber`, `pipewire`,
  `gnome-keyring`, `gum`, `jq`, `git`, `perl`, `omarchy-speedtest`,
  `fakeroot`, `pacman-contrib`, `ttf-jetbrains-mono-nerd-basic`.
- **`depends_x86_64` (`:73-78`): `limine`, `limine-mkinitcpio-hook`,
  `limine-snapper-sync`, `snapper`.** No es opcional: instalar `omarchy`
  en x86_64 instala la pila de Limine.
- `omarchy-settings` deja Limine como `optdepends`
  (`pkgs:pkgbuilds/omarchy-settings/PKGBUILD:110-116`) porque también se
  instala en el live de la ISO, pero sus drop-ins están pensados para Limine.

### Qué hace `limine-mkinitcpio-hook` al instalarse

Inspeccionado en el paquete de CachyOS 1.40.0-1 (el de Omarchy es 1.41.0
del mismo autor, `gitlab.com/Zesko/limine-entry-tool`):

- `/etc/pacman.d/hooks/90-mkinitcpio-install.hook`: mismo nombre que el
  hook de `mkinitcpio`, así que **lo sustituye** (pacman da prioridad a
  `/etc/pacman.d/hooks`). Ejecuta `limine-mkinitcpio-install`, que genera
  initramfs/UKI y entradas **de Limine**.
- `/usr/local/bin/mkinitcpio`: envoltorio que va antes en el `PATH`. Tras
  `mkinitcpio -P` avisa de que «no actualiza las entradas de Limine» y
  **pregunta** si ejecutar `limine-mkinitcpio` (interactivo: rompe scripts
  que llamen a `mkinitcpio -P`).
- `/usr/share/libalpm/hooks/80-limine-efi-deploy.hook`: al instalar o
  actualizar `limine`/`limine-mkinitcpio-hook` ejecuta `limine-install`
  (copia Limine a la ESP y crea su entrada EFI).
- Hooks de initcpio `btrfs-overlayfs` (busybox) y `sd-btrfs-overlayfs`
  (systemd) para arrancar snapshots de solo lectura.

La ISO de Omarchy enmascara justo esos hooks mientras instala
(`iso:builder/build-root-image.sh:72-83`, `orq:phases_impl.py:1819`), lo
que confirma su efecto.

### Drop-ins de mkinitcpio de `omarchy-settings`

`etc/mkinitcpio.conf.d/` (se instalan en `/etc/mkinitcpio.conf.d/`):

| Fichero | Contenido |
|---|---|
| `00-omarchy-hooks.conf` | **Fija `HOOKS`** para x86: `base udev plymouth keyboard autodetect microcode modconf kms keymap consolefont block encrypt filesystems fsck btrfs-overlayfs` (`:34`). Busybox: desbloqueo con `encrypt` + `cryptdevice=` en la cmdline. |
| `omarchy_hooks.conf` | Quita `kms` si solo hay GPU NVIDIA con `nvidia_drm` cargado pronto. |
| `omarchy_vconsole.conf` | Mete `/etc/vconsole.conf` en el initramfs salvo distribuciones no latinas. |
| `thunderbolt_module.conf`, `i2c_hid_of_module.conf` | Módulos tempranos según kernel/plataforma. |

`mkinitcpio` lee los drop-ins por orden de nombre: `00-…` < `9…` < `o…` <
`t…`. Un drop-in nuestro que deba ganar tiene que ordenarse **después de
todos** (p. ej. `zz-pixmatic.conf`), no `90-…`.

### Limine y cmdline

- `/etc/default/limine` lo genera la ISO desde
  `default/limine/default.conf` (`ESP_PATH="/boot"`, `@@CMDLINE@@` → cmdline
  resuelta) (`docs/file-layout.md:115-117`).
- `etc/limine-entry-tool.d/omarchy-defaults.conf`: `quiet splash loglevel=0
  systemd.show_status=false rd.udev.log_level=0 vt.global_cursor_default=0
  initramfs_async=0 systemd.tty.term.console=dumb`, UKI `omarchy`, entrada
  *fallback*, hasta 6 snapshots en el menú; `omarchy-uki.conf`:
  `ENABLE_UKI=yes`.
- Comandos del runtime que asumen Limine: `omarchy-refresh-limine`,
  `omarchy-kernel`, `omarchy-plymouth-set`, `omarchy-snapshot`,
  `omarchy-hibernation-setup`/`-remove`, `omarchy-system-factory-reset`,
  `omarchy-reinstall-configs`.

## 5. Repositorios y `pacman.conf`

- Plantilla (`default/pacman/pacman-stable.conf`): `SigLevel = Required
  DatabaseOptional`, `[omarchy]` (`https://pkgs.omarchy.org/stable/$arch`)
  **primero**, luego `[core]`, `[extra]`, `[multilib]`; mirrorlist único
  `https://stable-mirror.omarchy.org/$repo/os/$arch` (copia congelada de
  Arch por canal).
- La escriben `install/post-install/pacman.sh` (en `omarchy-apply-system`),
  `omarchy-refresh-pacman` (lo llama `omarchy-reinstall-pkgs`) y
  `omarchy-channel-set` (menú *Update → Channel*). Las tres **eliminan los
  repos de CachyOS**.
- `omarchy update` hace `pacman -Syu --overwrite '/usr/share/omarchy/*'`
  (`bin/omarchy-update-system-pkgs:13,26`), sin tocar `pacman.conf`.

Paquetes de `install/omarchy-base.packages` (162) que **sirve de verdad** el
repo `[omarchy]` estable para x86_64 (base de datos
`https://pkgs.omarchy.org/stable/x86_64/omarchy.db` descargada el
2026-11-16, 258 paquetes) (32): `aether asdcontrol cliamp disktree-bin gliff
herdr hype hyprland-preview-share-picker localsend mise-bin monologue omacalc
omacut omarchy-hyprland-titlebars omarchy-nvim omarchy-power-profiles-daemon
omasnap omawrite owe quickshell signed superwhisper-bin tobi-try
ttf-ia-writer ttf-jetbrains-mono-nerd-basic ttfx tzupdate ufw-docker vi
yaru-icon-theme yay yt-dlp`. El resto se resuelve con los repos de CachyOS +
Arch (`pacman -Si` en el host), salvo **`nvim`**, que no existe con ese
nombre en ningún repo comprobado (Arch lo llama `neovim`; probablemente lo
resuelve el mirror congelado de Omarchy). 

**Corrección (2026-11-16):** una primera versión de esta sección se sacó de
los PKGBUILDs de `omarchy-pkgs`, que no coinciden con lo publicado: en el
repo estable x86_64 **no están** `hyprland`, `ffmpeg`, `obsidian`, `pinta`,
`nvidia-utils` ni `nvidia-open-dkms` (de NVIDIA solo la rama `580xx`), aunque
haya PKGBUILD. Hyprland, ffmpeg, Obsidian y Pinta llegan de Arch (en
Omarchy, por su mirror congelado).

Paquetes que están **en los dos lados** (x86_64, 2026-11-16), relevantes
para el orden de repos:

| Paquete | `[omarchy]` | CachyOS / otros | Nota |
|---|---|---|---|
| `quickshell` | 0.3.2.r7.g2b4501a-1 | 0.3.2-1.1 (`cachyos-extra-v3`) | El escritorio de Omarchy es Quickshell. |
| `omarchy-hyprland-titlebars` | 0.2.2-2, depende de **`hyprland=0.56.2`** | — (CachyOS tiene `hyprland` 0.57.2-1.1) | **Hoy no se puede instalar con el Hyprland de CachyOS** (versión exacta distinta). El PKGBUILD de `master` ya pide `0.57.2` (`pkgs:pkgbuilds/omarchy-hyprland-titlebars/PKGBUILD:14`), pero no está publicado en estable. |
| `limine-mkinitcpio-hook`, `limine-snapper-sync` | 1.40.0-2, 1.32.1-2 | 1.40.0-1, 1.32.1-1 (`cachyos`) | Misma versión; solo cambia `pkgrel`. |
| `nvidia-580xx-dkms`, `nvidia-580xx-utils`, `lib32-nvidia-580xx-utils` | 580.178.04-1.1 | — | Rama para GPU sin GSP. |
| `yay`, `localsend`, `walker`, `yt-dlp` | sí | sí (`cachyos`, `extra`) | Sin riesgo conocido. |
| `yaru-icon-theme` | sí | solo `chaotic-aur` | No está en CachyOS ni Arch. |

## Claves de firma (verificadas 2026-11-16)

| Repo | Clave primaria (`--recv-keys`/`--lsign-key`) | Quién firma | Comprobación |
|---|---|---|---|
| `[omarchy]` | `40DFB630FF42BCFFB047046CF0134EE680CAC571` (`Omarchy <pkgs@omarchy.org>`) | la propia clave primaria | Firmas `.sig` de `omarchy-keyring-20251027-1-any`, `omarchy-4.5.0-3-x86_64` y `quickshell-0.3.2.r7…-x86_64`; es la única clave de `omarchy-trusted` del paquete `omarchy-keyring` e igual a `iso:builder/omarchy.gpg` y a la que firma la ISO (`iso:README.md`). La base de datos no va firmada (`omarchy.db.sig` da 404; la plantilla usa `SigLevel = Required DatabaseOptional`). |
| `[chaotic-aur]` | `EF925EA60F33D0CB85C44AD13056513887B78AEB` (`3056513887B78AEB`, Pedro Henrique Lara Campos) **y** `67BF8CA6DA181643C9723B4ED6C9442437365605` (`D6C9442437365605`, TNE) | subclaves de firma: `chaotic-keyring` la firma `BFB13EA5…3A40CB5E7E5CBC30` (de `3056513887B78AEB`); `chaotic-mirrorlist` y los paquetes normales (p. ej. `yaru-icon-theme`), `42FE8BA5…349BC7808577C592` (de `D6C9442437365605`, caduca 2028-06-14) | Firmas `.sig` en `cdn-mirror.chaotic.cx`; las dos primarias son las de `chaotic-trusted` del paquete `chaotic-keyring` 20251028-1. Con solo `3056513887B78AEB` (lo que dicen las instrucciones oficiales, que luego instalan `chaotic-keyring`) **no** se verificarían el resto de paquetes en un `pacstrap` que no instale antes el llavero: hay que firmar las dos. |

Las tres claves se descargan con subclaves de `hkps://keyserver.ubuntu.com`
(probado con un `GNUPGHOME` temporal). `/etc/pacman.d/gnupg/gpg.conf` no fija
servidor de claves, así que conviene pasar `--keyserver` explícito a
`pacman-key --recv-keys`.

## 6. Ficheros de `/etc` que impone `omarchy-settings`

Drop-ins propios (sin conflicto con paquetes): `etc/` del repo →
`/etc/` (`docs/file-layout.md:105-113`): `sddm.conf.d/10-theme.conf`
(`Current=omarchy`) y `10-wayland.conf` (greeter en Wayland con
`start-hyprland`), `NetworkManager/conf.d/` (comprobación de conectividad
contra `ping.omacom.io`, ahorro de energía wifi), `systemd/logind.conf.d`
(ignora el botón de encendido), `resolved.conf.d` (sin multicast; DNS de
Docker), `system.conf.d` (apagado rápido, `nofile`), `oomd.conf.d`,
`sysctl.d`, `udev/rules.d` (planificador de E/S, perfil de energía),
`sudoers.d`, `mise/conf.d`, `xkb/`, `limine-entry-tool.d/`,
`mkinitcpio.conf.d/`, y por `default/`: `zram-generator.conf.d/90-omarchy.conf`,
`timesyncd.conf.d`, unidades de usuario, sesión
`/usr/local/share/wayland-sessions/omarchy.desktop`, temas de Plymouth y
SDDM.

Ficheros **de otros paquetes** que el scriptlet sobrescribe con `cp -f` en
cada instalación y actualización
(`pkgs:pkgbuilds/omarchy-settings/omarchy-settings.install:70-120`):

| Fichero | Contenido de Omarchy | Choque con CachyOS / nuestro instalador |
|---|---|---|
| `/etc/os-release` | `NAME="Omarchy"`, `ID=omarchy`, `ID_LIKE=arch` (`pkgs:pkgbuilds/omarchy-settings/PKGBUILD:364-375`) | El sistema deja de identificarse como CachyOS. Herramientas que miren `ID=cachyos` (fastfetch, `cachyos-hello`, scripts) cambian de comportamiento; **a verificar** con `chwd` y los kernels. |
| `/etc/plymouth/plymouthd.conf` | `[Daemon] Theme=omarchy` | Sustituye el tema y el `UseSimpledrm=1` de Calamares. |
| `/etc/nsswitch.conf` | con `mdns` | — |
| `/etc/security/faillock.conf` | límites propios | — |
| `/etc/skel/.bashrc` | bashrc de Omarchy | Solo afecta a usuarios nuevos. |
| `/etc/cups/cups-browsed.conf`, `cups-files.conf` | endurecidos | — |

## 7. Red, sesión y servicios

- **Red**: NetworkManager (`enable-services.sh`), `iwd` y
  `systemd-networkd` desactivados (`network.sh`), resolved en modo stub. Es
  lo mismo que CachyOS: el conflicto iwd/wpa_supplicant de
  `omarchy-on-cachyos` ya no existe.
- **Sesión**: `omarchy.desktop` vía `uwsm`; greeter SDDM con tema
  `omarchy`; autologin solo con LUKS (fase 8).
- **Snapper**: config `root` de Omarchy, sin timeline, limpieza por número
  (5); `limine-snapper-sync` crea entradas de arranque para snapshots.
  Subvolúmenes de la ISO: `@`, `@home`, `@log`, `@pkg` (+ `/swap` para
  hibernación).
- **Docker** activo por socket, usuario fuera del grupo `docker`.
- **ufw** activo (deny entrante), como el `enable_ufw` de Calamares.
- **systemd-oomd** activo; `NetworkManager-wait-online` enmascarado.

## 8. Kernel y NVIDIA

- Kernel por defecto: `linux-omarchy` (+ headers) de `[omarchy]`
  (`iso:builder/build-iso.sh:17`, `install/omarchy-other.packages:24-25`).
  Los scripts genéricos no lo exigen (salvo plataformas ARM concretas y
  `BOOT_ORDER` de Limine), así que `linux-cachyos` vale.
- NVIDIA: `install/hardware/nvidia.sh` instala `nvidia-open-dkms` (o
  `nvidia-580xx-dkms`) con `omarchy-pkg-add` y escribe
  `/etc/mkinitcpio.conf.d/nvidia.conf`. En CachyOS lo hace `chwd` con
  módulos precompilados (`linux-cachyos-nvidia-open`). Si `chwd` ya instaló
  el driver, `omarchy-pkg-add` instalaría además los paquetes DKMS (DKMS
  para un módulo ya presente: duplicado, conflicto de ficheros posible).

## 9. Conflictos de `omarchy-on-cachyos` comprobados en 4.x

| Conflicto anotado (script para v3.x) | En Omarchy 4.5 |
|---|---|
| Pasos de pacman (repo `[omarchy]`, `pacman.conf`) | **Sigue y es peor**: `omarchy-apply-pacman` sustituye `pacman.conf` entero ([sección 5](#5-repositorios-y-pacmanconf)). |
| Plymouth | Ya no hay script: tema y `plymouthd.conf` vienen en `omarchy-settings` (`cp -f` en cada actualización). El hook `plymouth` va en `00-omarchy-hooks.conf`. |
| limine-snapper / alt-bootloaders | **Sigue y es peor**: Limine es dependencia dura del paquete `omarchy` en x86_64 ([sección 4](#4-arranque-limine-y-mkinitcpio)). |
| `linux` → `linux-cachyos` | Kernel `linux-omarchy`, pero solo lo pone la ISO; los scripts no dependen de él. |
| iwd vs wpa_supplicant | **Desaparece**: 4.x usa NetworkManager y desactiva iwd. |
| `walker` fijado al repo omarchy | **Desaparece**: 4.x usa Quickshell; `walker` no está en `omarchy-base.packages`. Lo que hay que fijar ahora es `hyprland` y `quickshell` ([sección 5](#5-repositorios-y-pacmanconf)). |
| mise para fish | El entorno de mise llega por `profile.d`/`.bashrc`/`uwsm`; para fish, `omarchy-fish`. |
| NVIDIA 580xx vía `chwd` | Omarchy elige solo `nvidia-open-dkms` o `nvidia-580xx-dkms` por GSP; choca con `chwd` ([sección 8](#8-kernel-y-nvidia)). |
| SDDM + autologin siempre | En 4.x el autologin **solo con LUKS**, y lo escribe la ISO, no un script del paquete. |
| Requisito fish | **No existe** en 4.x (era requisito del script, no de Omarchy). |
| Requisito btrfs + snapper | Sigue: snapper es dependencia del paquete, `snapper.sh` asume btrfs. |

## 10. Aplicaciones que instala

Fuentes: `install/omarchy-base.packages` (167 paquetes, la lista de la
imagen raíz de la ISO) y las dependencias del paquete `omarchy`
(`pkgs:pkgbuilds/omarchy/PKGBUILD:27-78`). Lo que dependa del hardware
(`install/omarchy-x86_64-only.packages`, `install/omarchy-other.packages`,
`install/hardware/`) queda fuera; el arranque y el kernel están en las
secciones [4](#4-arranque-limine-y-mkinitcpio) y [8](#8-kernel-y-nvidia).
Las descripciones de los paquetes propios de `[omarchy]` vienen del
`pkgdesc` de su PKGBUILD en `pkgs:pkgbuilds/<paquete>/`.

### Gráficas

| Área | Paquetes |
|---|---|
| Escritorio | `hyprland`, `hyprland-guiutils`, `quickshell` (barra, menús y notificaciones del escritorio de Omarchy; sustituye a waybar, mako y walker de 3.x), `uwsm`, `sddm` (tema `omarchy`), `hyprpicker`, `hyprsunset`, `hyprland-preview-share-picker`, `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk`, `omarchy-hyprland-titlebars` |
| Terminal | `foot` (`install/omarchy-base.packages:47`) es el único que se instala. `config/` trae también configuración de `alacritty`, `ghostty` y `kitty`, que no se instalan. |
| Navegador | `chromium` (`:17`), navegador por defecto (`bin/omarchy-provision-user:128`) |
| Web apps | Lanzadores `.desktop` de `applications/` copiados a `~/.local/share/applications` (`bin/omarchy-refresh-applications:5-7`): Basecamp, HEY (también `mailto`, `bin/omarchy-provision-user:129`), WhatsApp, Discord, X, YouTube, Zoom, Google Maps/Photos/Messages/Contacts |
| Archivos y discos | `nautilus` (+ `nautilus-python`, `sushi` para la vista previa, `gvfs-mtp/-nfs/-smb`), `gnome-disk-utility`, `disktree-bin` (mapa del uso del disco) |
| Multimedia | `mpv` (+ `mpv-mpris`), `imv` (visor de imágenes), `gpu-screen-recorder`, `monologue` (grabar la webcam), `omacut` (recortar vídeo), `moonlight-qt` (streaming de juegos) |
| Oficina | `libreoffice-fresh`, `evince` (PDF), `signed` (firmar PDF), `obsidian`, `omawrite` (Markdown), `hype` (presentaciones en Markdown), `omacalc` (calculadora), `pinta` (dibujo) |
| Otras | `localsend`, `aether` (temas a partir del fondo de pantalla), `owe` (fondos animados), `omasnap` (capturas con anotaciones), `superwhisper-bin` (dictado por voz), `system-config-printer`, `fcitx5` con métodos de entrada CJK (`-chewing`, `-chinese-addons`, `-hangul`, `-mozc`, `-table-extra`), `gnome-keyring` |

### De terminal

| Área | Paquetes |
|---|---|
| Shell y utilidades | bash (+ `bash-completion`) con `starship`; `eza`, `bat`, `fzf`, `fd`, `ripgrep`, `zoxide`, `tldr`, `plocate`, `tmux`, `gum`, `jq`, `btop`, `fastfetch`, `inxi`, `whois`, `expac`, `ttfx` (efectos de texto) |
| Desarrollo | `nvim` + `omarchy-nvim` (LazyVim con plugins en caché), `git`, `lazygit`, `mise-bin` (versiones de lenguajes), `docker` (+ `docker-buildx`, `docker-compose`), `ruby`, `lua51`/`luarocks`, `dotnet-runtime`, `tree-sitter-cli`, `python-poetry-core`, `yay`, `herdr` (espacios de trabajo para agentes de IA), `tobi-try` (directorios temporales), `gliff` (escritorio remoto de Hyprland por SSH) |
| Sistema | `ufw` (+ `ufw-docker`), `cups` (+ `cups-filters`, `cups-pk-helper`), `avahi`, `nss-mdns`, `bluez` (+ `bluez-tools`, `bluez-utils`), `bolt`, `brightnessctl`, `ddcutil`, `pamixer`, `udiskie`, `tzupdate`, `kernel-modules-hook`, `pacman-contrib`, `plymouth`, `snapper` (dependencia en x86_64) |
| Wayland | `grim`, `slurp`, `wl-clipboard`, `wtype`, `xdg-terminal-exec`, `xorg-xsetroot`, `socat`, `inotify-tools` |
| Multimedia y otras | `ffmpeg`, `ffmpegthumbnailer`, `imagemagick`, `libvips`, `yt-dlp`, `tesseract` (+ `-data-eng`, OCR), `zbar` y `qrencode` (QR), `cliamp` (reproductor de música) |
| Fuentes y tema | `ttf-jetbrains-mono-nerd-basic` (fuente del sistema, dependencia de `omarchy`), `noto-fonts` (+ `-cjk`, `-emoji`), `ttf-ia-writer`, `woff2-font-awesome`, `yaru-icon-theme`, `gnome-themes-extra` |

### Configuración de las aplicaciones

- `config/**` llega a `~/.config` del usuario vía `/etc/skel/.config`
  (`pkgs:pkgbuilds/omarchy-settings/PKGBUILD:183-186`): Hyprland, foot,
  alacritty, ghostty, kitty, btop, chromium, fcitx5, git, herdr, imv,
  lazygit, obsidian, starship, tmux, wireplumber, portales,
  `hyprland-mimeapps.list` y la configuración de `quickshell`
  (`config/omarchy/`). Detalle de las capas en la
  [sección 3](#3-usuario-etcskel-omarchy-provision-user-y-primer-inicio).
- 23 temas en `themes/` (tokyo-night, catppuccin, gruvbox, nord,
  rose-pine, everforest, kanagawa, matte-black…); el tema elegido se aplica
  a la vez a Hyprland, Quickshell, terminales, btop, nvim, GTK y Chromium.
- Lo que se puede aprovechar sin conflictos para la Fase 3 son las
  aplicaciones, `config/` y `themes/`; lo que choca con nuestro instalador es
  `omarchy-settings` y `omarchy-apply-system` (arranque, `pacman.conf`,
  `os-release`; secciones [4](#4-arranque-limine-y-mkinitcpio) a
  [6](#6-ficheros-de-etc-que-impone-omarchy-settings)).

## Pendiente de verificar en VM

- Si `chwd` o los kernels de CachyOS usan `ID` de `/etc/os-release`.
- Qué hace `omarchy-provision-user` con un usuario cuyo shell es fish (sin
  `.bashrc` en uso).
- Si `omarchy-apply-system` termina bien sin Limine en la ESP (lo único que
  toca de Limine es `limine-snapper-sync.service`, con `|| true`).
- Si Limine exporta `LoaderDevicePartUUID` (necesario para gpt-auto) en
  caso de adoptar Limine.
