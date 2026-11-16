# Comparación de la instalación base: diferencias en el sistema resultante

Fase 2, tercera parte. Compara **el sistema instalado** que dejan Calamares y
New-Cli-Installer (NCI) con las opciones fijas de este proyecto. Solo cuenta el
estado final (disco, ficheros, paquetes, servicios, ESP). Si dos instaladores
hacen lo mismo por caminos distintos (otro orden, otra herramienta, `chroot`
frente a `arch-chroot`), se considera **equivalente** y aparece solo en la
[lista de equivalencias](#lo-que-queda-igual-por-caminos-distintos).

Fuentes (lo que se empaqueta desde CachyOS 26.11):

- [auditoria-calamares-base.md](auditoria-calamares-base.md) (Calamares
  `cachyos-staging` `42a91ab23`; en adelante **Cal §N** = su Paso N).
- [auditoria-new-cli-installer-base.md](auditoria-new-cli-installer-base.md)
  (NCI tag `0.13.0` `30401a3`; **NCI §N** = su Paso N).
- Anexos con Hyprland: [anexo-hyprland-calamares.md](anexo-hyprland-calamares.md)
  (**Cal-H**) y [anexo-hyprland-new-cli-installer.md](anexo-hyprland-new-cli-installer.md)
  (**NCI-H**); solo para la [sección 12](#12-con-escritorio-hyprland).
- Comprobaciones en el código, citadas con ruta: `cal:` = `cachyos-calamares`
  `cachyos-staging` `42a91ab23`, `nci:` = New-Cli-Installer `0.13.0`,
  `pkgbuilds:` = `CachyOS-PKGBUILDS` `a7b3058`, `iso:` = este repo `master`
  `b0ebcae`.

Historia del documento: la primera versión (historial de git, `635d754`)
comparaba Calamares `cachyos-dev` con NCI `0.12.4`, que no podía cifrar en
headless. Con las versiones de 26.11 **desaparece esa asimetría** (los dos
instalan con LUKS2) y varias diferencias se cierran porque ambos comparten el
backend gucc. Lo que ha cambiado está en
[Cambios respecto a la primera comparación](#cambios-respecto-a-la-primera-comparación).

## Alcance

Opciones comunes: UEFI, borrar disco, **btrfs dentro de LUKS2** (una
contraseña), subvolúmenes por defecto, ESP de 2 GiB en `/boot`, systemd-boot,
`es_ES.UTF-8`, teclado `es`, `Europe/Madrid`, RTC en UTC, sin swap, sin
escritorio. La [sección 12](#12-con-escritorio-hyprland) recoge aparte lo que
cambia al elegir Hyprland en ambos.

Leyenda de la columna **Impacto**: **alto** = cambia el comportamiento o la
seguridad del sistema; **medio** = se nota en el uso o en el mantenimiento;
**bajo** = cosmético, o sin efecto práctico.

Marcas: **[verificado]** en esta máquina (instalada con Calamares
`cachyos-dev`, sin LUKS); **[deducido]** del código, pendiente de confirmar
en VM.

---

## Resumen

Las diferencias de impacto alto y medio, de un vistazo:

| # | Área | Calamares | NCI `0.13.0` | Impacto |
|---|---|---|---|---|
| R1 | Desbloqueo LUKS | mapper `luks-<UUID>`, `rd.luks.uuid=`, `crypttab` con una línea, `fstab` por `/dev/mapper/…` | mapper `cryptroot`, `rd.luks.name=<UUID>=cryptroot`, sin `crypttab`, `fstab` por UUID del btrfs | medio |
| R2 | `SigLevel` de `[cachyos]` | la global (`Required DatabaseOptional`) | `Optional TrustAll` (heredado del `pacman.conf` del live) | **alto** (seguridad) |
| R3 | Hash de contraseñas | yescrypt (`$y$`) | SHA-512 (`$6$`) | bajo-medio |
| R4 | Kernels | `linux-cachyos` + `linux-cachyos-lts` (+ headers) | solo `linux-cachyos` (+ headers) | medio |
| R5 | Plymouth | hook en el initramfs, tema fijado y `UseSimpledrm=1` | instalado, sin hook ni tema; `splash` en la cmdline igualmente | medio |
| R6 | `loader.conf` | `default @saved`, `timeout 5`, `console-mode keep` | el que deja `bootctl install` | medio |
| R7 | cmdline del kernel | `quiet nowatchdog splash rw rootflags=… rd.luks.uuid=… root=…` (repetida con dos kernels) + `LINUX_OPTIONS` | `splash quiet zswap.enabled=0 nowatchdog rw rootflags=… rd.luks.name=… root=…` + `LINUX_OPTIONS` | medio (duplicados en ambos; `zswap.enabled=0` solo en NCI) |
| R8 | Restos en la ESP | `/boot/<machine-id>/<kver>/` (kernels e initramfs duplicados, cientos de MiB) | ninguno | medio |
| R9 | Permisos de `/root` | 0750 | 0755 [deducido] | medio |
| R10 | Shell del usuario | fish | bash (`user_shell` por defecto) | medio |
| R11 | Paquetes | ver [4](#4-paquetes): `lts`, `os-prober`, `ufw-extras`, `shelly`, `realtime-privileges`, `gst-plugin-dav1d`, `firefox-i18n`, `cachyos-plymouth-theme` | `snapper`, `btrfs-assistant-git`, `paru`, `octopi` | medio |
| R12 | Tipo GPT de la raíz | `0FC63DAF…` (Linux genérico) | `4F68BCE3…` (raíz x86-64, Discoverable Partitions) | medio (para nosotros: es el que hemos decidido) |
| R13 | `subvolid=` en `fstab` | no | sí [deducido] | medio |
| R14 | Servicios | — | además `ModemManager` | bajo-medio |
| R15 | `locale.gen` | `en_US.UTF-8` + `es_ES.UTF-8` | solo `es_ES.UTF-8` | bajo |

Con Hyprland, R5 desaparece en parte (NCI activa plymouth al haber escritorio)
y aparecen las diferencias H1-H6 de la [sección 12](#12-con-escritorio-hyprland).

---

## 1. Disco y particiones

| Elemento | Calamares (Cal §1) | NCI (NCI §2) | Impacto |
|---|---|---|---|
| Tabla | GPT | GPT | = |
| Inicio de la ESP | 2 MiB | 1 MiB (por defecto de sfdisk) | bajo |
| Tamaño de la ESP | 2048 MiB | 2048 MiB (esquema por defecto) o el del JSON | = |
| Tipo / atributos de la ESP | `C12A7328…` | `C12A7328…` + atributo GPT 2 *LegacyBIOSBootable* (`bootable` de sfdisk) | bajo (sin efecto en UEFI) |
| Sistema de ficheros de la ESP | FAT32, sin etiqueta | FAT32, sin etiqueta | = |
| Tipo de la partición raíz | `0FC63DAF…` (Linux genérico), hasta el final alineado a 4 KiB | **`4F68BCE3…`** (`SD_GPT_ROOT_X86_64`), resto del disco | medio: con `4F68BCE3…` `systemd-gpt-auto-generator` puede descubrir la raíz |
| Contenido de la raíz | LUKS2 → btrfs | LUKS2 → btrfs | ver [2](#2-cifrado) |
| `PARTLABEL` | ninguno | ninguno | = |

## 2. Cifrado

| Elemento | Calamares (Cal §1, §17, §20, §26) | NCI (NCI §2, §4g, §5, §18) | Impacto |
|---|---|---|---|
| Formato | LUKS2 | LUKS2 | = |
| Parámetros de `luksFormat` | explícitos: `--use-random --sector-size 4096 --key-size 512 --hash sha512` (KPMcore) | los de cryptsetup por defecto (`-q --type luks2`) | bajo: con cryptsetup 2.8 los valores efectivos deberían coincidir salvo el tamaño de sector (cryptsetup lo elige según el disco) [deducido] |
| PBKDF | argon2id (defecto) | argon2id (defecto) | = |
| Nombre del mapper | `luks-<UUID LUKS>` | `cryptroot` | bajo |
| `/etc/crypttab` | `luks-<U> UUID=<U> none` (sin opciones) | no se escribe (el del paquete `filesystem`, solo comentarios) | bajo (con `sd-encrypt` manda la cmdline) |
| `fstab` (btrfs) | `/dev/mapper/luks-<U>` | `UUID=<uuid btrfs>` (`genfstab -U`) | bajo |
| `HOOKS` | `… block keyboard sd-vconsole plymouth sd-encrypt filesystems` (`keyboard` tras `autodetect`) | `base systemd keyboard autodetect … block sd-vconsole sd-encrypt filesystems` (`keyboard` **antes** de `autodetect`: incluye todos los drivers de teclado) | bajo-medio: con NCI un teclado distinto del de la instalación sirve para escribir la contraseña |
| Parámetro de desbloqueo | `rd.luks.uuid=<U> root=/dev/mapper/luks-<U>` | `rd.luks.name=<U>=cryptroot root=/dev/mapper/cryptroot` | bajo |
| Keyfile | ninguno (`/boot` sin cifrar) | ninguno (`LuksKeyfile` solo con `/boot` cifrado) | = |
| Cierre del mapper al terminar | no (`umount -lv` y nada más) | sí (`cryptsetup close cryptroot`) | — (solo afecta al live) |

## 3. btrfs, montaje y `fstab`

| Elemento | Calamares (Cal §3, §17) | NCI (NCI §2, §5) | Impacto |
|---|---|---|---|
| Subvolúmenes | `@ @home @root @srv @cache @tmp @log` | iguales | = |
| Opciones de montaje efectivas | `noatime,compress=zstd:1` (NVMe) / `compress=zstd` (SATA) | `noatime,compress=zstd:1` en cualquier SSD (no rotacional) / `compress=zstd` en HDD | bajo: un SSD SATA recibe `zstd` en Calamares y `zstd:1` en NCI |
| Permisos de `/root` | **0750**: `chmod` explícito del subvolumen (`cal:src/modules/mount/main.py:298-300`) [verificado] | **0755** [deducido]: NCI no hace `chmod` (ninguna referencia en `nci:gucc/src` ni `nci:installer-lib/src`); el subvolumen nace 0755 y pacman no cambia permisos de un directorio que ya existe | medio |
| Formato de `fstab` | propio: `defaults,noatime,compress=…`, `subvol=/@…`; ESP `defaults,umask=0077`; pass 2/0 | `genfstab -U -p`: las opciones **tal como las muestra el kernel** (`rw,noatime,compress=zstd:1,ssd,discard=async,space_cache=v2,…`); ESP `rw,relatime,fmask=0077,dmask=0077,codepage=…` | bajo (mismo efecto) |
| `subvolid=` en `fstab` | no | **probablemente sí** [deducido]: la limpieza solo actúa si hay otra opción después de `subvol=`, y el kernel la pone al final (NCI §5) | medio si se usa snapper con *rollback* |
| `/tmp` | línea `tmpfs … defaults,noatime,mode=1777` si el disco no es rotacional | sin línea → `tmp.mount` de systemd (`mode=1777,strictatime,nosuid,nodev,size=50%,nr_inodes=1m`) | bajo: en Calamares `/tmp` pierde `nosuid,nodev` y el límite de inodos |

`/var/tmp` (subvolumen `@tmp`) nace 0755 en ambos; `systemd-tmpfiles` lo
corrige a 1777 en el primer arranque. Sin diferencia.

## 4. Paquetes

Listas comparadas: Calamares = `cal:src/modules/pacstrap/pacstrap.conf:13-58`
+ grupos preseleccionados de `cal:src/modules/netinstall/netinstall.yaml`
(*CachyOS required*, *CachyOS Packages*, *Base-devel + Common*, *Plymouth*,
*CachyOS shell configuration*, *Firefox*) + `systemd-boot-manager` +
microcódigo. NCI = `nci:net-profiles.toml:1-193` + kernel + `snapper
btrfs-assistant-git` (`nci:gucc/src/package_list.cpp`) + `systemd-boot-manager`
+ microcódigo. `net-profiles.toml` no cambia entre `0.12.4` y `0.13.0`; en
Calamares los kernels y plymouth cambian de sitio pero no de lista, y entra
`gst-plugin-dav1d`. Coinciden **146** nombres. Diferencias:

| Solo en Calamares | Origen | Solo en NCI | Origen |
|---|---|---|---|
| `linux-cachyos-lts`, `linux-cachyos-lts-headers` | `pacstrap.conf:37-38` y *CachyOS required* | `snapper`, `btrfs-assistant-git` | por ser btrfs, aunque no haya bootloader que use snapshots |
| `os-prober` | `pacstrap.conf:49` | `paru` | `net-profiles.toml:105` |
| `cachyos-plymouth-theme` | grupo *Plymouth* (`netinstall.yaml:841`) | `octopi` | `net-profiles.toml:106` |
| `ufw-extras` | `netinstall.yaml:64` | | |
| `shelly` | `netinstall.yaml:82` | | |
| `gst-plugin-dav1d` | `netinstall.yaml:91` (nuevo en `staging`) | | |
| `realtime-privileges` | `netinstall.yaml:138` (crea el grupo `realtime`; el usuario no entra) | | |
| `firefox-i18n-<locale>` | `netinstall.yaml:792` (valor exacto pendiente) | | |

Notas:

- `iptables-nft` (NCI) resuelve al paquete `iptables`, que en Calamares entra
  como dependencia de `ufw`. Mismo resultado.
- Las dos listas vienen de GitHub en tiempo de ejecución (`netinstall.yaml` de
  la rama `cachyos` y `net-profiles.toml` de `master`), así que esta tabla
  puede cambiar sin nueva versión de los instaladores.
- `chwd` se ejecuta una vez en ambos y añade los mismos paquetes para el mismo
  hardware.
- En los dos, "sin escritorio" instala el conjunto de escritorio completo
  (PipeWire, fuentes, Bluetooth, Firefox, alacritty, códecs…).
- En Calamares el grupo *Plymouth* es desmarcable en la interfaz; con los
  valores por defecto se instala.

## 5. Repositorios, llavero y mirrors

| Elemento | Calamares (Cal §5-7) | NCI (NCI §0, §4b-4f) | Impacto |
|---|---|---|---|
| `/etc/pacman.conf` | `iso:archiso/airootfs/etc/pacman-more.conf` + bloque de repos optimizados según la CPU | `iso:archiso/airootfs/etc/pacman.conf` del live + bloque de repos optimizados | = salvo `SigLevel` (los dos ficheros de la ISO solo difieren en esa línea) |
| `SigLevel` de `[cachyos]` | la global: `Required DatabaseOptional` | `Optional TrustAll` | **alto** (seguridad): paquetes de `[cachyos]` sin firma obligatoria |
| Orden dentro del bloque optimizado | `[cachyos-v4] [cachyos-extra-v4] [cachyos-core-v4]` | `[cachyos-v4] [cachyos-core-v4] [cachyos-extra-v4]` | bajo (los repos -v4 no comparten paquetes entre sí) |
| Repos optimizados en VirtualBox | sí (según la CPU) | **no**: si `systemd-detect-virt` contiene `oracle` no añade repos por ISA (NCI §4c) | bajo en hardware real; importa en las pruebas en VM VirtualBox |
| `mirrorlist` (Arch) | ordenado por `cachyos-rate-mirrors` | ordenado (lo copia `pacstrap`) | = |
| `cachyos-*mirrorlist` | ordenados (copiados del live) | ordenados (copiados del live tras el `pacstrap`) | = |
| `.pacnew` | `pacman.conf`, los 4 mirrorlist y `resolv.conf` [verificado] | ninguno [deducido]: se sobrescriben después de instalar | bajo |
| Llavero | copia del del live (recreado: `--init` + `--populate`) | copia del del live (`--init`, keyrings, `--populate`) | = |
| Caché de paquetes | todo lo instalado, en `@cache` (`--sysroot`) [verificado] | todo lo instalado, en `@cache` (`--cachedir` del target primero) [deducido] | = (llena en ambos; varios GiB) |

## 6. initramfs

| Elemento | Calamares (Cal §4, §20, §21) | NCI (NCI §4d, §4g, §16) | Impacto |
|---|---|---|---|
| `HOOKS` | `base systemd autodetect microcode modconf block keyboard sd-vconsole plymouth sd-encrypt filesystems` | `base systemd keyboard autodetect microcode modconf block sd-vconsole sd-encrypt filesystems` | medio (R5 y posición de `keyboard`, ver [2](#2-cifrado)) |
| `kms` | no | no | = |
| `MODULES`/`BINARIES`/`FILES` | `()` | los del paquete (`()`) | = |
| Resto de `mkinitcpio.conf` | el del live, con la sangría quitada (`.strip()`) | el del paquete del target | bajo (cosmético) |
| Imágenes | `initramfs-linux-cachyos{,-lts}.img`, 0600 | `initramfs-linux-cachyos.img` | ver R4 |
| Presets | desde `hook.preset` | desde `hook.preset` | = |

Los dos difieren el initramfs durante la instalación de paquetes **con el
mismo código** (`gucc::initcpio::install_deferral_hook`) y lo generan una vez
antes del bootloader. En Calamares, además, `kernel-install` genera dos
imágenes más que acaban en la ESP (R8).

## 7. Bootloader, ESP y cmdline

| Elemento | Calamares (Cal §26, §29) | NCI (NCI §18) | Impacto |
|---|---|---|---|
| systemd-boot | `bootctl install` **desde el live** (binarios EFI del live) | `bootctl install` en el target (binarios del target) | bajo (solo si difieren las versiones; el hook de `systemd-boot-manager` lo actualiza con el siguiente `systemd`) |
| NVRAM | "Linux Boot Manager" | "Linux Boot Manager" | = |
| `loader.conf` | `default @saved` / `timeout 5` / `console-mode keep` | el que escribe `bootctl install` por defecto [deducido] | medio |
| Entradas | `linux-cachyos.conf` y `linux-cachyos-lts.conf` (`sdboot-manage gen`) | `linux-cachyos.conf` (`sdboot-manage gen`) | ver R4 |
| `/etc/kernel/cmdline` | `quiet nowatchdog splash rw rootflags=subvol=/@ rd.luks.uuid=<U> root=/dev/mapper/luks-<U>` (repetido desde `splash` con dos kernels, Cal hallazgo 1) | `splash quiet zswap.enabled=0 nowatchdog rw rootflags=subvol=/@ rd.luks.name=<U>=cryptroot root=/dev/mapper/cryptroot` | medio |
| `zswap.enabled=0` | no | sí | medio: desactiva zswap (CachyOS usa zram) |
| `LINUX_OPTIONS` en la entrada | `sdboot-manage` 24 añade `nowatchdog quiet splash` (`pkgbuilds:systemd-boot-manager/sdboot-manage:298-307`) | igual | = (duplicados en ambos) |
| Restos de `kernel-install` | `/boot/<machine-id>/<kver>/{linux,initrd}` por cada kernel (Cal hallazgo 2) | no | medio (ocupa una ESP de 2 GiB y nunca se actualiza) |
| Actualizaciones del kernel | `sdboot-manage autogen` relee `/etc/kernel/cmdline` | igual | = |

## 8. Configuración del sistema

| Elemento | Calamares (Cal §9-12, §24) | NCI (NCI §4a, §8) | Impacto |
|---|---|---|---|
| `/etc/hostname`, `/etc/hosts` | idénticos | idénticos | = |
| `/etc/localtime` | → `/usr/share/zoneinfo/Europe/Madrid` | igual | = |
| `/etc/timezone` | `Europe/Madrid` | no existe | bajo (fichero de Debian) |
| `/etc/adjtime` | `UTC` | `UTC` (`hw_clock: utc` por defecto) | = |
| `locale.gen` | bloque añadido al final con `en_US.UTF-8` y `es_ES.UTF-8` | `es_ES.UTF-8` descomentado en su sitio | bajo |
| Locales generados | `en_US.UTF-8`, `es_ES.UTF-8` | `es_ES.UTF-8` | bajo |
| `/etc/locale.conf` | `LANG` + 9 `LC_*`, sin comillas | `LANG` + 10 `LC_*` (añade `LC_MESSAGES`), con comillas | = en efecto (`LC_MESSAGES` hereda de `LANG`) |
| `/etc/default/locale` | copia de `locale.conf` | no existe | bajo |
| `/etc/vconsole.conf` | `KEYMAP=es`, `XKBLAYOUT=es`, `XKBMODEL=pc105` | `KEYMAP=es` | bajo (la consola queda igual; `localectl` muestra más datos en Calamares) |
| `00-keyboard.conf` | cabecera de localed, `XkbLayout "es"`, `XkbVariant ""` | `XkbLayout "es"` | = en efecto |
| `/etc/default/keyboard` | existe | no existe | bajo |
| Sin `FONT=` en `vconsole.conf` | sí | sí | = |
| `machine-id` y enlace dbus | nuevos (`gucc::machine_id::reset` en ambos) | nuevos | = |
| `random-seed` | `/var/lib/systemd/random-seed` (y `/var/lib/urandom/random-seed`, ruta antigua) | no (lo crea systemd en el primer arranque) | bajo |
| `/etc/resolv.conf` | copia del del live (contenido del live) | el del paquete `filesystem` | bajo (NetworkManager lo reescribe) |
| `plymouthd.conf` | con `Theme=` y `UseSimpledrm=1` (dos secciones `[Daemon]`, Cal hallazgo 13) | el del paquete | ver R5 |

## 9. Usuarios y sudo

| Elemento | Calamares (Cal §9, §29) | NCI (NCI §13) | Impacto |
|---|---|---|---|
| Hash | **yescrypt** (`$y$`, `crypt_gensalt`) | **SHA-512** (`$6$`, `openssl passwd -6 -stdin`) | bajo-medio (yescrypt es el valor por defecto de Arch y más resistente; SHA-512 es aceptable) |
| Contraseña de root | por defecto la del usuario (`doReusePassword`) | propia (`root_pass`, obligatoria) | = si se configura igual |
| Shell | `/bin/fish` (`shell-setup`) | `/bin/bash` (`user_shell` configurable) | medio |
| GECOS | nombre completo | vacío | bajo |
| Grupos | `wheel rfkill sys users lp video network storage audio` **+ `nopasswdlogin`** | los mismos sin `nopasswdlogin` | bajo (sin DM no tiene efecto) |
| Grupo `nopasswdlogin` | creado | no existe | bajo |
| Home | 0700 | 0700 (`HOME_MODE 0700` de `login.defs`) | = |
| Contenido del home | `/etc/skel` completo (usuario tras los paquetes; además se recopia al final) | `/etc/skel` completo (usuario tras los paquetes) | = |
| sudo | `/etc/sudoers.d/10-installer`: `%wheel ALL=(ALL) ALL` | idéntico | = |

## 10. Servicios, firewall y red

| Elemento | Calamares (Cal §28, §30, §22) | NCI (NCI §19, §15) | Impacto |
|---|---|---|---|
| Activados por el instalador | `NetworkManager`, `avahi-daemon`, `systemd-timesyncd`, `fstrim.timer`, `bluetooth`, `ufw` | los mismos **+ `ModemManager`** (`nci:net-profiles.toml:215`) | bajo-medio |
| `sshd` | no | no (se quita en modo escritorio) | = |
| VM (`vboxservice`, `vmtoolsd`…) | si `chwd` los instaló | igual | = |
| Unidades activadas por scriptlets (`cachyos-settings`…) | iguales si los paquetes coinciden | | = |
| ufw | `deny incoming`, `allow outgoing`, activo (`gucc::firewall::enable_ufw`) | idéntico (misma función) | = |
| Getty en tty2 | `getty@tty2.service` quitado de `getty.target.wants` y enlace roto `ly@tty2.service` (`dmcheck`, Cal hallazgo 12) [deducido] | intacto | bajo-medio (sin login en tty2) |
| Conexiones de NetworkManager del live | copiadas (todos los ficheros, sin sobrescribir); `permissions=user:liveuser` cambiado al usuario nuevo | copiadas solo las `*.nmconnection`, sobrescribiendo, `chmod 600`; sin reescribir `permissions=` | bajo (solo si se configuró wifi con permisos de usuario en el live) |

## 11. Restos en el sistema instalado

| Calamares | NCI |
|---|---|
| `/usr/local/bin/remove-nvidia` (sin dueño) [verificado] | `/.base_installed` |
| `/boot/<machine-id>/<kver>/…` (ver [7](#7-bootloader-esp-y-cmdline)) | `/cachyos-install.log` (contraseñas enmascaradas) |
| Caché de paquetes completa | Caché de paquetes completa |
| `.pacnew` de `pacman.conf`, mirrorlists y `resolv.conf` | — |
| `/var/lib/urandom/random-seed`, `/etc/default/{keyboard,locale}`, `/etc/timezone` | — |
| Enlace roto `/etc/systemd/system/multi-user.target.wants/ly@tty2.service` [deducido] | — |

---

## 12. Con escritorio Hyprland

Opciones de las secciones anteriores más la elección de Hyprland: en Calamares,
`Hyprland` en el paso *Escritorio*; en NCI, `"desktop": "hyprland"` (con
`autologin: false` y sin `netinstall_groups`). Las diferencias de la base
(R1-R15) se mantienen salvo R5. Aquí solo lo que añade el escritorio.

**Siguen sin ser el mismo escritorio**, aunque desde 26.11 los dos usan
SDDM. El comentario de `nci:net-profiles.toml:533` dice que el perfil debería
ser igual al grupo de Calamares, pero Calamares instala el Hyprland de CachyOS
con la shell Noctalia y sus dotfiles, y NCI el Hyprland "clásico" (wofi), sin
configuración.

| # | Elemento | Calamares (Cal-H) | NCI `0.13.0` (NCI-H) | Impacto |
|---|---|---|---|---|
| H1 | Paquetes explícitos | `hyprland dolphin kitty sddm cachyos-hypr-noctalia` | `hyprland sddm xdg-desktop-portal-hyprland playerctl wofi dolphin kitty uwsm wl-clipboard polkit-kde-agent xorg-xwayland` | **alto** |
| H2 | Shell del escritorio | Noctalia (barra, lanzador, notificaciones), lanzada desde la config de Hyprland | ninguna (`wofi` como lanzador) | **alto** |
| H3 | Configuración del usuario | dotfiles de `cachyos-hypr-noctalia` (config de Hyprland **en Lua**, `uwsm/env`, Noctalia, kitty, GTK/Qt, cursor Bibata), copiados por `useradd -m` (usuario tras los paquetes) | **ninguna**: sin `~/.config/hypr`; lo que genere Hyprland en el primer arranque | **alto** |
| H4 | Configuración de SDDM | `/etc/sddm.conf` con `[Autologin] Session=hyprland` (sin `User=`, sin efecto); enlazado por `dmcheck` | ninguna; `systemctl enable sddm` | bajo |
| H5 | Restos del greeter | `/usr/share/noctalia-greeter/config.toml` y `/var/lib/noctalia-greeter/greeter.toml` (de los dotfiles, sin uso con SDDM) | — | bajo |
| H6 | Extras del sistema | `/etc/profile.d/Hyprland.sh` (variables para NVIDIA sin iGPU); `gnome-keyring`, `qt6ct`, `nwg-look`, `grim`, `slurp`, `hyprpicker`… | `polkit-kde-agent`, `playerctl` | bajo |
| — | Display manager | SDDM, greeter X11 con el tema por defecto, sin autologin | igual | = |
| — | Servidor X | `xorg-server` + `xorg-xauth` (dependencias de `sddm`) | igual | = |
| — | Repos de los paquetes del escritorio | optimizados | optimizados (`pacman.conf` generado) | = |
| — | Plymouth (R5) | hook, tema y `UseSimpledrm=1` | hook y tema (`DesktopConfigure`), sin `UseSimpledrm` | bajo |
| — | Teclado en Hyprland | `us`: nada que lea Hyprland y los dotfiles no fijan `kb_layout` | `us` (sin configuración) | = (mal en ambos) |
| — | Autologin | no (`doAutologin: false`) | no; con `autologin: true` crea `/etc/sddm.conf` con `User=` | = |
| — | `default.target` | `graphical.target` (el de systemd; ningún instalador lo toca) | igual | = |

Diferencia de robustez del proceso que afecta al resultado: en **NCI**, si
falla el `pacstrap` del escritorio solo hay un aviso y queda un sistema sin
escritorio (NCI-H, *Resumen*). En Calamares el grupo Hyprland es crítico: un
fallo aborta.

## Lo que queda igual por caminos distintos

No son diferencias en el resultado:

- Limpieza previa del disco (`ClearMountsJob` + `sfdisk --wipe` frente a
  `dd` + `wipefs` + `sgdisk -Zo`): GPT nueva y vacía en ambos.
- `mkfs.fat -F32 -I` + `fatlabel -r` + `fsck` frente a `mkfs.vfat -F32`: FAT32
  sin etiqueta.
- `chroot` plano con montajes de API persistentes frente a `arch-chroot` por
  orden (Calamares también usa `arch-chroot` en los pasos portados a gucc).
- `pacman --sysroot` + `pacman -Su` + netinstall frente a un solo `pacstrap`:
  las versiones finales son las más recientes en ambos (salvo los paquetes y
  repos de [4](#4-paquetes) y [5](#5-repositorios-llavero-y-mirrors)).
- `genfstab` frente a una escritura propia: solo cuenta el formato
  ([3](#3-btrfs-montaje-y-fstab)).
- Escritura de `vconsole.conf` antes (NCI) o después (Calamares) de los
  paquetes: el initramfs se genera después en ambos.
- `ufw enable` dentro del chroot: mismo estado en el target. En los dos afecta
  también al live (corta conexiones entrantes, incluido SSH).
- Orden de `machine-id`, locale, zona y reloj.
- **Mismo código** desde 26.11 (Calamares llama a las librerías de NCI):
  diferimiento y restauración del hook de `mkinitcpio`, `machine-id`, reloj,
  ufw y snapshot de instalación.

## Cambios respecto a la primera comparación

Primera versión: Calamares `cachyos-dev` frente a NCI `0.12.4`.

| Tema | Antes | Ahora |
|---|---|---|
| Asimetría del cifrado | Calamares con LUKS2, NCI headless sin cifrar | **los dos con LUKS2**; quedan diferencias de nombres y parámetros (R1) |
| `pacman.conf` de NCI | sin repos optimizados | con repos optimizados; solo queda el `SigLevel` de `[cachyos]` (R2) |
| Hash en NCI | MD5-crypt | SHA-512 (R3 baja de alto a bajo-medio) |
| cmdline de NCI | generada por `sdboot-manage` con `findmnt`, limpia | `/etc/kernel/cmdline` propio + `LINUX_OPTIONS`: duplicados también en NCI (R7) |
| Caché de paquetes | llena en Calamares, vacía en NCI | llena en ambos (deja de ser diferencia) |
| ESP | 2 GiB frente a 4 GiB | 2 GiB en ambos |
| Tipo de la raíz | `0FC63DAF…` en ambos | NCI pasa a `4F68BCE3…` (R12, nueva) |
| `kms` | en ambos | en ninguno |
| initramfs | Calamares una vez; NCI varias | una vez en ambos, con el mismo mecanismo |
| Usuario | Calamares antes de los paquetes (con recopia del skel); NCI antes del sistema | los dos después de los paquetes |
| Plymouth en Calamares | hook y tema | además `UseSimpledrm=1` |
| Hyprland de Calamares | greetd + noctalia-greeter (`allow_empty_password = true`) | SDDM; el greeter queda como resto inerte |
| Hyprland de NCI | paquetes de repos genéricos; autologin roto | repos optimizados; autologin arreglado |

## Pendiente de verificar en VM

Además de lo que ya recoge cada auditoría:

- `stat -c %a /root` en una instalación de NCI (R9).
- `subvolid=` en el `fstab` de NCI (R13).
- `loader.conf` que deja `bootctl install` en NCI (R6) y si crea un directorio
  `<entry-token>` o `/etc/kernel/entry-token` (en Calamares, con el machine-id
  del live).
- `cryptsetup luksDump` en ambos (tamaño de sector, cifrado, PBKDF).
- Que no aparecen `.pacnew` en NCI.
- Permisos de los initramfs en NCI (Calamares fuerza 0600).
- Arranque gráfico en NCI con `splash` sin hook de plymouth (R5) y en
  Calamares con `UseSimpledrm=1` sin `kms`.
- Repos optimizados de NCI en VirtualBox (se omiten).
- Con Hyprland: lista final de paquetes en ambos (H1), qué genera Hyprland 0.57
  sin `~/.config/hypr` en NCI (H3), sesión preseleccionada por SDDM, teclado
  efectivo en el greeter y en Hyprland, y el enlace roto `ly@tty2.service` de
  Calamares (también sin escritorio).

## Puntos de decisión para el instalador propio

La referencia ya está decidida (`CLAUDE.md`, *Decisiones tomadas*): replicar
el **sistema resultante de Calamares** con la **forma de NCI**. Esta
comparación actualizada no cambia esa decisión; refuerza varias de las
desviaciones elegidas (tipo GPT `4F68BCE3…`, initramfs generado una vez,
usuario tras los paquetes). Puntos a revisar con los datos nuevos:

1. Cifrado: nombre del mapper (`luks-<UUID>` o `cryptroot`; con la raíz
   descubierta por gpt-auto será `root`), posición de `keyboard` en `HOOKS`
   (antes de `autodetect`, como NCI, es más robusto para escribir la
   contraseña) y parámetros de `luksFormat`.
2. Plymouth: Calamares añade `UseSimpledrm=1` y quita `kms`; decidir si se
   replica (y escribirlo en un drop-in de `plymouthd.conf.d`, sin tocar el
   fichero del paquete).
3. `zswap.enabled=0` (NCI): CachyOS usa zram, así que es coherente; decidir si
   se añade a la cmdline.
4. Caché de paquetes: los dos la dejan llena; la decisión de vaciarla es una
   desviación respecto a ambos.
5. Kernels: uno (R4, ya decidido).
6. `loader.conf`, `/etc/kernel/cmdline` limpia, sin restos en la ESP (R6-R8).
7. `fstab` (R13): no se genera (montajes de systemd, ya decidido).
8. `ModemManager`: activarlo o no (pendiente).
9. Hyprland ([12](#12-con-escritorio-hyprland)): ninguno de los dos oficiales
   es la referencia final (se adaptará Omarchy 4.x, Fase 3). Los tres usan
   SDDM; de Calamares se toma la técnica de instalar el escritorio antes de
   crear el usuario (dotfiles por `useradd -m`), y hay que fijar `kb_layout`.
