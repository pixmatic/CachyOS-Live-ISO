# Comparación de la instalación base: diferencias en el sistema resultante

Fase 2, tercera parte. Compara **el sistema instalado** que dejan Calamares y
New-Cli-Installer (NCI) con las opciones fijas de este proyecto. Solo cuenta el
estado final (disco, ficheros, paquetes, servicios, ESP). Si dos instaladores
hacen lo mismo por caminos distintos (otro orden, otra herramienta, `chroot`
frente a `arch-chroot`), se considera **equivalente** y aparece solo en la
[lista de equivalencias](#lo-que-queda-igual-por-caminos-distintos).

Fuentes:

- [auditoria-calamares-base.md](auditoria-calamares-base.md) (Calamares
  `cachyos-dev` `199d71543`; en adelante **Cal §N** = su Paso N).
- [auditoria-new-cli-installer-base.md](auditoria-new-cli-installer-base.md)
  (NCI tag `0.12.4` `bb3eccb`; **NCI §N** = su Paso N).
- Anexos con Hyprland: [anexo-hyprland-calamares.md](anexo-hyprland-calamares.md)
  (**Cal-H §N**) y [anexo-hyprland-new-cli-installer.md](anexo-hyprland-new-cli-installer.md)
  (**NCI-H §N**); solo para la [sección 12](#12-con-escritorio-hyprland).
- Comprobaciones nuevas en el código, citadas con ruta: `cal:` =
  `cachyos-calamares` `199d71543`, `nci:` = New-Cli-Installer `0.12.4`,
  `pkgbuilds:` = `CachyOS-PKGBUILDS` `6c6dc36`, `iso:` = este repo `master`
  `3215497`.

## Alcance y asimetría de partida

Opciones comunes: UEFI, borrar disco, btrfs con subvolúmenes por defecto,
systemd-boot, `es_ES.UTF-8`, teclado `es`, `Europe/Madrid`, RTC en UTC, sin
swap, sin escritorio. La [sección 12](#12-con-escritorio-hyprland) recoge
aparte lo que cambia al elegir Hyprland en ambos.

Hay una asimetría que no se puede evitar:

- **Calamares** se auditó **con LUKS2** ("Cifrar sistema").
- **NCI `0.12.4` no puede cifrar en headless** (NCI, *El cifrado no es
  posible…*).

Por eso las diferencias se separan en dos grupos:

1. **Por el cifrado** ([sección 2](#2-cifrado)): solo existen porque un lado
   cifra y el otro no. Al final de esa sección se compara también con el
   cifrado del modo avanzado de NCI.
2. **Con las mismas opciones** (el resto del documento): seguirían existiendo
   aunque Calamares instalara sin cifrar. Cuando el código de Calamares sin LUKS
   da otro resultado, se indica. La instalación de esta máquina (Calamares, sin
   LUKS) sirve de contraste.

Leyenda de la columna **Impacto**: **alto** = cambia el comportamiento o la
seguridad del sistema; **medio** = se nota en el uso o en el mantenimiento;
**bajo** = cosmético, o sin efecto práctico.

Marcas: **[verificado]** en esta máquina; **[deducido]** del código, pendiente
de confirmar en VM.

---

## Resumen

Las diferencias de impacto alto y medio, de un vistazo:

| # | Área | Calamares | NCI `0.12.4` | Impacto |
|---|---|---|---|---|
| R1 | Cifrado | LUKS2 + `sd-encrypt` | sin cifrar | alto (por las opciones) |
| R2 | `pacman.conf` | `pacman-more.conf` + repos optimizados (`-v3`/`-v4`/`-znver4`); `[cachyos]` con la `SigLevel` global (firma obligatoria) | `pacman.conf` del live: **sin repos optimizados** y `[cachyos]` con `SigLevel = Optional TrustAll` | alto |
| R3 | Hash de contraseñas | yescrypt (`$y$`) | MD5-crypt (`$1$`) | alto |
| R4 | Kernels | `linux-cachyos` + `linux-cachyos-lts` (+ headers) | solo `linux-cachyos` (+ headers) | medio |
| R5 | Plymouth | hook en el initramfs y tema fijado | instalado, sin hook ni tema; `splash` en la cmdline igualmente | medio |
| R6 | `loader.conf` | `default @saved`, `timeout 5`, `console-mode keep` | el que deja `bootctl install` | medio |
| R7 | cmdline del kernel | desde `/etc/kernel/cmdline` (con parámetros duplicados) | generada por `sdboot-manage` con `findmnt`, limpia | medio |
| R8 | Restos en la ESP | `/boot/<machine-id>/<kver>/` (kernels e initramfs duplicados, cientos de MiB) | ninguno | medio |
| R9 | Permisos de `/root` | 0750 | 0755 [deducido] | medio |
| R10 | Shell del usuario | fish | bash (`user_shell` por defecto) | medio |
| R11 | Paquetes | ver [4](#4-paquetes): `lts`, `os-prober`, `ufw-extras`, `shelly`, `realtime-privileges`, `firefox-i18n`, `cachyos-plymouth-theme` | `snapper`, `btrfs-assistant-git`, `paru`, `octopi` | medio |
| R12 | Caché de paquetes | toda la instalación en `/var/cache/pacman/pkg` | vacía (salvo lo que instale `chwd`) | medio |
| R13 | Servicios | — | además `ModemManager` | bajo-medio |
| R14 | Tamaño de la ESP | 2 GiB | 4 GiB (auto) o lo que diga `partitions` | bajo (configurable) |
| R15 | `locale.gen` | `en_US.UTF-8` + `es_ES.UTF-8` | solo `es_ES.UTF-8` | bajo |

Con Hyprland, R5 desaparece (NCI activa plymouth al haber escritorio) y
aparecen las diferencias H1-H9 de la [sección 12](#12-con-escritorio-hyprland).

---

## 1. Disco y particiones

| Elemento | Calamares (Cal §1) | NCI (NCI §2) | Impacto |
|---|---|---|---|
| Tabla | GPT | GPT | = |
| Inicio de la ESP | 2 MiB | 1 MiB (por defecto de sfdisk) | bajo |
| Tamaño de la ESP | 2048 MiB | 4 GiB con `EraseAndAuto`; con `CreateLayout` el del JSON (`settings.jsonc`: `2G`) | bajo (configurable) |
| Tipo / atributos de la ESP | `C12A7328…` | `C12A7328…` + atributo GPT 2 *LegacyBIOSBootable* (`bootable` de sfdisk) | bajo (sin efecto en UEFI) |
| Sistema de ficheros de la ESP | FAT32, sin etiqueta | FAT32, sin etiqueta | = |
| Partición raíz | `0FC63DAF…`, hasta el final alineado a 4 KiB | `0FC63DAF…`, resto del disco | = |
| Contenido de la raíz | LUKS2 → btrfs | btrfs | ver [2](#2-cifrado) |
| `PARTLABEL` | ninguno | ninguno | = |

## 2. Cifrado

### 2.1 Calamares (LUKS2) frente a NCI headless (sin cifrar)

Todo lo de esta tabla es consecuencia directa de cifrar o no:

| Elemento | Calamares (Cal §1, §17, §20, §26) | NCI headless |
|---|---|---|
| Contenedor | LUKS2, argon2id, sha512, clave de 512 bits, sector 4096, 1 keyslot | — |
| Nombre del mapper | `luks-<UUID LUKS>` | — |
| `/etc/crypttab` | `luks-<U> UUID=<U> none` (sin opciones) | el del paquete `filesystem` (solo comentarios) |
| `fstab` (btrfs) | `/dev/mapper/luks-<U>` | `UUID=<uuid btrfs>` |
| `HOOKS` | `… plymouth sd-encrypt filesystems` | sin `sd-encrypt` |
| cmdline | `rd.luks.uuid=<U> root=/dev/mapper/luks-<U>` | `root=UUID=<uuid btrfs>` |
| Keyfile | ninguno (`/boot` sin cifrar) | — |

### 2.2 Calamares frente al cifrado del modo avanzado de NCI

Para referencia, si se cifrara con NCI `0.12.4` (interactivo, NCI *Cifrado en
`0.12.4`*):

| Elemento | Calamares | NCI modo avanzado | Impacto |
|---|---|---|---|
| Formato | **LUKS2**, argon2id, sector 4096 | **LUKS1** (PBKDF2), valores por defecto de cryptsetup | alto |
| Mapper | `luks-<UUID>` | el que escriba el usuario | bajo |
| `crypttab` | línea sin opciones | no se escribe | bajo (con `sd-encrypt` manda la cmdline) |
| Parámetro de desbloqueo | `rd.luks.uuid=<U>` | `rd.luks.name=<U>=<mapper>` | bajo |
| `fstab` | `/dev/mapper/…` | `UUID=<uuid btrfs>` | bajo |
| `HOOKS` | `base systemd autodetect microcode kms modconf block keyboard sd-vconsole plymouth sd-encrypt filesystems` | `base systemd keyboard autodetect microcode kms modconf block sd-vconsole sd-encrypt filesystems` (`keyboard` antes de `autodetect`: incluye todos los drivers de teclado) | bajo |

NCI `master` (sin publicar) ya cifra en headless con LUKS2 y `rd.luks.uuid`,
lo que lo acerca a Calamares.

## 3. btrfs, montaje y `fstab`

| Elemento | Calamares (Cal §3, §17) | NCI (NCI §2, §3g, §4) | Impacto |
|---|---|---|---|
| Subvolúmenes | `@ @home @root @srv @cache @tmp @log` | iguales | = |
| Opciones de montaje efectivas | `noatime,compress=zstd:1` (NVMe) / `compress=zstd` (SATA) | `noatime,compress=zstd:1` en cualquier SSD (no rotacional) / `compress=zstd` en HDD | bajo: un SSD SATA recibe `zstd` en Calamares y `zstd:1` en NCI |
| Permisos de `/root` | **0750**: `chmod` explícito del subvolumen (`cal:src/modules/mount/main.py:298-300`) [verificado] | **0755** [deducido]: NCI no hace `chmod` (`nci:gucc/src/btrfs.cpp`); el subvolumen nace 0755 y pacman no cambia permisos de un directorio que ya existe (solo avisa) | medio |
| Formato de `fstab` | propio: `defaults,noatime,compress=…`, `subvol=/@…`; ESP `defaults,umask=0077`; pass 2/0 | `genfstab -U -p`: las opciones **tal como las muestra el kernel** (`rw,noatime,compress=zstd:1,ssd,discard=async,space_cache=v2,…`); ESP `rw,relatime,fmask=0077,dmask=0077,codepage=…` | bajo (mismo efecto) |
| `subvolid=` en `fstab` | no | **probablemente sí** [deducido]: el `sed` que lo quita exige una coma después de `subvol=/…` (`nci:gucc/src/fstab.cpp:148`), y el kernel muestra `subvol=` como última opción | medio si se usa snapper con *rollback* (un `subvolid` fijo impide montar el subvolumen restaurado) |
| `/tmp` | línea `tmpfs … defaults,noatime,mode=1777` si el disco no es rotacional | sin línea → `tmp.mount` de systemd (`mode=1777,strictatime,nosuid,nodev,size=50%,nr_inodes=1m`) | bajo: en Calamares `/tmp` pierde `nosuid,nodev` y el límite de inodos |

`/var/tmp` (subvolumen `@tmp`) nace 0755 en ambos; `systemd-tmpfiles` lo
corrige a 1777 en el primer arranque. Sin diferencia.

## 4. Paquetes

Listas comparadas: Calamares = `cal:src/modules/pacstrap/pacstrap.conf:13-57`
+ grupos preseleccionados de `cal:src/modules/netinstall/netinstall.yaml`
(`:1-24`, `:34-199`, `:833-840`) + `systemd-boot-manager` + microcódigo. NCI =
`nci:net-profiles.toml:1-193` + kernel + `snapper btrfs-assistant-git`
(`nci:gucc/src/package_list.cpp:151`) + `systemd-boot-manager` + microcódigo.
Coinciden **146** nombres. Diferencias:

| Solo en Calamares | Origen | Solo en NCI | Origen |
|---|---|---|---|
| `linux-cachyos-lts`, `linux-cachyos-lts-headers` | grupo oculto *CachyOS kernels* | `snapper`, `btrfs-assistant-git` | por ser btrfs, aunque no haya bootloader que use snapshots |
| `os-prober` | `pacstrap.conf:45` | `paru` | `net-profiles.toml:105` |
| `cachyos-plymouth-theme` | `pacstrap.conf:57` | `octopi` | `net-profiles.toml:106` |
| `ufw-extras` | `netinstall.yaml:81` | | |
| `shelly` | `netinstall.yaml:99` | | |
| `realtime-privileges` | `netinstall.yaml:154` (crea el grupo `realtime`; el usuario no entra) | | |
| `firefox-i18n-<locale>` | `netinstall.yaml:840` (valor exacto pendiente) | | |

Notas:

- `iptables-nft` (NCI) resuelve al paquete `iptables`, que en Calamares entra
  como dependencia de `ufw`. Mismo resultado.
- Las dos listas vienen de GitHub en tiempo de ejecución (`netinstall.yaml` de
  `cachyos-dev` y `net-profiles.toml` de `master`), así que esta tabla puede
  cambiar sin nueva versión de los instaladores.
- `chwd` añade los mismos paquetes en ambos para el mismo hardware. NCI lo
  ejecuta dos veces con `-f` (reinstalar), sin efecto en el resultado.
- En los dos, "sin escritorio" instala el conjunto de escritorio completo
  (PipeWire, fuentes, Bluetooth, Firefox, alacritty, códecs…).

## 5. Repositorios, llavero y mirrors

| Elemento | Calamares (Cal §5-7) | NCI (NCI §0, §3b-3e) | Impacto |
|---|---|---|---|
| `/etc/pacman.conf` | `iso:archiso/airootfs/etc/pacman-more.conf` + bloque de repos optimizados según la CPU | `iso:archiso/airootfs/etc/pacman.conf` del live, sin repos optimizados [deducido] | **alto**: con NCI las actualizaciones salen de los repos genéricos, aunque se instaló desde los optimizados |
| `SigLevel` de `[cachyos]` | la global: `Required DatabaseOptional` | `Optional TrustAll` | **alto** (seguridad): paquetes de `[cachyos]` sin firma obligatoria |
| Orden dentro del bloque optimizado | `[cachyos-v4] [cachyos-extra-v4] [cachyos-core-v4]` | (en el `pacman.conf` temporal: `v4, core-v4, extra-v4`; no queda en el target) | — |
| `mirrorlist` (Arch) | ordenado por `cachyos-rate-mirrors` | ordenado (lo copia `pacstrap`) | = |
| `cachyos-*mirrorlist` | ordenados (copiados del live) | los del paquete, sin ordenar | bajo (se reordenan con `cachyos-rate-mirrors` más tarde) |
| `.pacnew` | `pacman.conf`, los 4 mirrorlist y `resolv.conf` [verificado] | ninguno [deducido]: se sobrescriben después de instalar | bajo |
| Llavero | copia del del live (recreado: `--init` + `--populate`) | copia del del live (`pacman-init.service` + clave CachyOS firmada en local) | = (en ambos la clave maestra local es la del live) |
| Caché de paquetes | todo lo instalado, en `@cache` (`--sysroot`) [verificado] | vacía: `pacstrap -c` usa la caché del live; solo quedan los paquetes que instala `chwd` | medio (espacio: varios GiB) |

## 6. initramfs

| Elemento | Calamares (Cal §4, §20, §21) | NCI (NCI §3f) | Impacto |
|---|---|---|---|
| `HOOKS` (sin contar LUKS) | `base systemd autodetect microcode kms modconf block keyboard sd-vconsole plymouth filesystems` | igual **sin `plymouth`** | medio (ver R5) |
| `MODULES`/`BINARIES`/`FILES` | `()` | los del paquete (`()`) | = |
| Resto de `mkinitcpio.conf` | el del live, con la sangría quitada (`.strip()`) | el del paquete del target | bajo (cosmético) |
| Imágenes | `initramfs-linux-cachyos{,-lts}.img`, 0600 | `initramfs-linux-cachyos.img` | ver R4 |
| Presets | desde `hook.preset` | desde `hook.preset` | = |

Que en Calamares el initramfs se genere una vez al final y en NCI durante
`pacstrap` y otra vez en 3f no cambia el resultado: en ambos la última
generación ya ve `vconsole.conf` y los `HOOKS` finales.

## 7. Bootloader, ESP y cmdline

| Elemento | Calamares (Cal §26, §29) | NCI (NCI §14) | Impacto |
|---|---|---|---|
| systemd-boot | `bootctl install` **desde el live** (binarios EFI del live) | `bootctl install` en el target (binarios del target) | bajo (solo si difieren las versiones; el hook de `systemd-boot-manager` lo actualiza con el siguiente `systemd`) |
| NVRAM | "Linux Boot Manager" | "Linux Boot Manager" | = |
| `loader.conf` | `default @saved` / `timeout 5` / `console-mode keep` | el que escribe `bootctl install` por defecto (plantilla con todo comentado → sin menú visible) [deducido] | medio |
| Entradas | `linux-cachyos.conf` y `linux-cachyos-lts.conf` (`sdboot-manage gen`) | `linux-cachyos.conf` | ver R4 |
| `/etc/kernel/cmdline` | existe | no existe | medio: en NCI, para añadir parámetros hay que crearlo |
| cmdline efectiva (sin LUKS) | `quiet nowatchdog splash rw rootflags=subvol=/@ root=UUID=… nowatchdog quiet splash` | `root=UUID=… rw rootflags=subvol=/@ nowatchdog quiet splash` | bajo (mismo efecto) |
| Duplicados | probables: `splash rw rootflags=… root=…` dos veces con dos kernels (Cal, hallazgo 1) [deducido] + `LINUX_OPTIONS` añadidas (`pkgbuilds:systemd-boot-manager/sdboot-manage:298-307`) | ninguno | bajo (el kernel se queda con el último valor) |
| Restos de `kernel-install` | `/boot/<machine-id>/<kver>/{linux,initrd}` por cada kernel (Cal, hallazgo 2) | no | medio (ocupa una ESP de 2 GiB y nunca se actualiza) |
| Actualizaciones del kernel | `sdboot-manage autogen` relee `/etc/kernel/cmdline` | `sdboot-manage autogen` vuelve a calcularla con `findmnt` (`sdboot-manage:181-229`) | = en la práctica |

## 8. Configuración del sistema

| Elemento | Calamares (Cal §9-12, §24) | NCI (NCI §3a, §6) | Impacto |
|---|---|---|---|
| `/etc/hostname`, `/etc/hosts` | idénticos | idénticos | = |
| `/etc/localtime` | → `/usr/share/zoneinfo/Europe/Madrid` | igual | = |
| `/etc/timezone` | `Europe/Madrid` | no existe | bajo (fichero de Debian) |
| `/etc/adjtime` | `UTC` | `UTC` (solo si `hw_clock` está definido) | = |
| `locale.gen` | bloque añadido al final con `en_US.UTF-8` y `es_ES.UTF-8` | `es_ES.UTF-8` descomentado en su sitio | bajo |
| Locales generados | `en_US.UTF-8`, `es_ES.UTF-8` | `es_ES.UTF-8` | bajo |
| `/etc/locale.conf` | `LANG` + 9 `LC_*`, sin comillas | `LANG` + 10 `LC_*` (añade `LC_MESSAGES`), con comillas | = en efecto (`LC_MESSAGES` hereda de `LANG`) |
| `/etc/default/locale` | copia de `locale.conf` | no existe | bajo |
| `/etc/vconsole.conf` | `KEYMAP=es`, `XKBLAYOUT=es`, `XKBMODEL=pc105` | `KEYMAP=es` | bajo (la consola queda igual; `localectl` muestra más datos en Calamares) |
| `00-keyboard.conf` | cabecera de localed, `XkbLayout "es"`, `XkbVariant ""` | `XkbLayout "es"` | = en efecto |
| `/etc/default/keyboard` | existe | no existe | bajo |
| Sin `FONT=` en `vconsole.conf` | sí | sí | = |
| `machine-id` y enlace dbus | nuevos | nuevos | = |
| `random-seed` | `/var/lib/systemd/random-seed` (y `/var/lib/urandom/random-seed`, ruta antigua) | no (lo crea systemd en el primer arranque) | bajo |
| `/etc/resolv.conf` | copia del del live (contenido del live) | el del paquete `filesystem` | bajo (NetworkManager lo reescribe) |

## 9. Usuarios y sudo

| Elemento | Calamares (Cal §9, §29) | NCI (NCI §7) | Impacto |
|---|---|---|---|
| Hash | **yescrypt** (`$y$`, `crypt_gensalt`) | **MD5-crypt** (`$1$`, `openssl passwd`) | **alto** |
| Contraseña de root | por defecto la del usuario (`doReusePassword`) | propia (`root_pass`, obligatoria) | = si se configura igual |
| Shell | `/bin/fish` (`shell-setup`) | `/bin/bash` (`user_shell` configurable) | medio |
| GECOS | nombre completo | vacío | bajo |
| Grupos | `wheel rfkill sys users lp video network storage audio` **+ `nopasswdlogin`** | los mismos sin `nopasswdlogin` | bajo (sin DM no tiene efecto) |
| Grupo `nopasswdlogin` | creado | no existe | bajo |
| Home | 0700 | 0700 (`HOME_MODE 0700` de `login.defs`) | = |
| Contenido del home | `/etc/skel` completo (se recopia al final) | `/etc/skel` completo (todos los paquetes se instalan antes de `useradd`) | = |
| sudo | `/etc/sudoers.d/10-installer`: `%wheel ALL=(ALL) ALL` | idéntico | = |

## 10. Servicios, firewall y red

| Elemento | Calamares (Cal §28, §30, §22) | NCI (NCI §16, §13) | Impacto |
|---|---|---|---|
| Activados por el instalador | `NetworkManager`, `avahi-daemon`, `systemd-timesyncd`, `fstrim.timer`, `bluetooth`, `ufw` | los mismos **+ `ModemManager`** (`nci:net-profiles.toml:215`) | bajo-medio |
| `sshd` | no | no (se quita en modo escritorio) | = |
| VM (`vboxservice`, `vmtoolsd`…) | si `chwd` los instaló | igual | = |
| Unidades activadas por scriptlets (`cachyos-settings`…) | iguales si los paquetes coinciden | | = |
| ufw | `deny incoming`, `allow outgoing`, activo | idéntico | = |
| Conexiones de NetworkManager del live | copiadas (todos los ficheros, sin sobrescribir); `permissions=user:liveuser` cambiado al usuario nuevo | copiadas solo las `*.nmconnection`, sobrescribiendo, `chmod 600`; sin reescribir `permissions=` | bajo (solo si se configuró wifi con permisos de usuario en el live) |

## 11. Restos en el sistema instalado

| Calamares | NCI |
|---|---|
| `/usr/local/bin/remove-nvidia` (sin dueño) [verificado] | `/.base_installed` |
| `/boot/<machine-id>/<kver>/…` (ver [7](#7-bootloader-esp-y-cmdline)) | `/cachyos-install.log` (contraseñas enmascaradas) |
| Caché de paquetes completa | — |
| `.pacnew` de `pacman.conf`, mirrorlists y `resolv.conf` | — |
| `/var/lib/urandom/random-seed`, `/etc/default/{keyboard,locale}`, `/etc/timezone` | — |
| Enlace roto `/etc/systemd/system/multi-user.target.wants/ly@tty2.service` [deducido] (Cal-H §29: `dmcheck` usa `pacman -Qs ly`, que casa por descripción con casi cualquier sistema) | — |

---

## 12. Con escritorio Hyprland

Opciones de las secciones anteriores más la elección de Hyprland: en Calamares,
`Hyprland` en el paso *Escritorio*; en NCI, `"desktop": "hyprland"` (con
`autologin: false` y sin `netinstall_groups`). Las diferencias de la base
(R1-R15) se mantienen salvo R5. Aquí solo lo que añade el escritorio.

**No son el mismo escritorio.** El comentario de `nci:net-profiles.toml:533`
dice que el perfil debería ser igual al grupo de Calamares, pero Calamares
instala el Hyprland actual de CachyOS (Noctalia + greetd) y NCI el antiguo
(SDDM + wofi), sin la configuración de CachyOS.

| # | Elemento | Calamares (Cal-H) | NCI `0.12.4` (NCI-H) | Impacto |
|---|---|---|---|---|
| H1 | Paquetes explícitos | `hyprland dolphin kitty noctalia-greeter cachyos-hypr-noctalia` (§14) | `hyprland sddm xdg-desktop-portal-hyprland playerctl wofi dolphin kitty uwsm wl-clipboard polkit-kde-agent xorg-xwayland` (§9) | **alto** |
| H2 | Display manager | **greetd** + **noctalia-greeter** en tty1 (`display-manager.service` → `greetd.service`, vía `dmcheck`) (§23, §29, §31) | **SDDM** (`systemctl enable sddm`), greeter X11 con el tema integrado, sin configuración (§16) | **alto** |
| H3 | Shell del escritorio | Noctalia (barra, lanzador, notificaciones), lanzada desde la config de Hyprland | ninguna (`wofi` como lanzador) | **alto** |
| H4 | Configuración del usuario | dotfiles de `cachyos-hypr-noctalia` copiados al `$HOME` (config de Hyprland **en Lua**, `uwsm/env`, Noctalia, kitty, GTK/Qt, cursor Bibata) por la recopia de `/etc/skel` (§29) | **ninguna**: sin `~/.config/hypr` ni recopia del skel; lo que genere Hyprland en el primer arranque | **alto** |
| H5 | Sesión por defecto | `Hyprland (uwsm-managed)` (`greeter.toml`) | la que preseleccione SDDM entre `Hyprland` y `Hyprland (uwsm-managed)` | medio |
| H6 | Servidor X | solo `xorg-xwayland` | además `xorg-server` + `xorg-xauth` (dependencias de `sddm`) | bajo |
| H7 | Repos de los paquetes del escritorio | optimizados (`-v3`/`-v4`), como el resto (`pacman` en el target con su `pacman.conf`, R2) | **genéricos** (`pacstrap -C /mnt/etc/pacman.conf`, el del live): `sddm` de `cachyos`, el resto de `extra` | medio (se suma a R2) |
| H8 | Usuario y ficheros del greeter | usuario `greeter` (sysusers; home `/var/lib/noctalia-greeter`, shell `nologin`), `/etc/greetd/{config.toml,environments}`, `/var/lib/noctalia-greeter/greeter.toml` con **`allow_empty_password = true`** | usuario `sddm` (del paquete) | medio (seguridad: el greeter acepta autenticación PAM sin contraseña) |
| H9 | Extras del sistema | `/etc/profile.d/Hyprland.sh` (variables para NVIDIA sin iGPU); `gnome-keyring`, `qt6ct`, `nwg-look`, `grim`, `slurp`, `hyprpicker`… | `polkit-kde-agent`, `playerctl` | bajo |
| — | Plymouth (R5) | igual que en la base: hook y tema | ahora **igual que Calamares**: tema `cachyos-bootanimation`, hook `plymouth` tras `sd-vconsole`, `mkinitcpio -P` (§10) | = |
| — | Teclado en Hyprland | `us`: el módulo `keyboard` no escribe nada que lea Hyprland y los dotfiles no fijan `kb_layout` | `us` (sin configuración); el greeter de SDDM sí usa `XkbLayout es` | = (mal en ambos) |
| — | Autologin | no (`doAutologin: false`) | no; con `autologin: true` tampoco funcionaría en `0.12.4` (`sed` sobre un `/etc/sddm.conf` inexistente; arreglado en `master`) | = |
| — | `default.target` | `graphical.target` (el de systemd; ningún instalador lo toca) | igual | = |

Diferencias de robustez del proceso que afectan al resultado:

- **NCI**: si falla el `pacstrap` del escritorio o el `mkinitcpio` con
  plymouth, solo hay un aviso y queda un sistema sin escritorio (NCI-H,
  *Resumen*). En Calamares el grupo Hyprland es crítico: un fallo aborta.
- **Calamares**: el `config.toml` de greetd se copia de un fichero de
  `cachyos-hypr-noctalia`, no del greeter; si faltara, el fallo sería
  silencioso y quedaría `agreety` (texto) (Cal-H §31).

## Lo que queda igual por caminos distintos

No son diferencias en el resultado:

- Limpieza previa del disco (`ClearMountsJob` + `sfdisk --wipe` frente a
  `dd` + `wipefs` + `sgdisk -Zo`): GPT nueva y vacía en ambos.
- `mkfs.fat -F32 -I` + `fatlabel -r` + `fsck` frente a `mkfs.vfat -F32`: FAT32
  sin etiqueta.
- `chroot` plano con montajes de API persistentes frente a `arch-chroot` por
  orden.
- Desactivar el hook de `mkinitcpio` y generar al final (Calamares) frente a
  generar durante `pacstrap` y regenerar (NCI): mismo initramfs final.
- `pacman --sysroot` + `pacman -Su` + netinstall frente a un solo `pacstrap`:
  las versiones finales son las más recientes en ambos (salvo los paquetes y
  repos de [4](#4-paquetes) y [5](#5-repositorios-llavero-y-mirrors)).
- `chwd --autoconfigure` una vez frente a `chwd -a -f` dos veces.
- `genfstab` dos veces (NCI) frente a una escritura propia: solo cuenta el
  formato ([3](#3-btrfs-montaje-y-fstab)).
- Escritura de `vconsole.conf` antes (NCI) o después (Calamares) de los
  paquetes: el initramfs final la incluye en ambos.
- `ufw enable` dentro del chroot: mismo estado en el target. En los dos afecta
  también al live (corta conexiones entrantes, incluido SSH).
- Orden de usuarios, `machine-id`, locale, zona y reloj.

## Pendiente de verificar en VM

Además de lo que ya recoge cada auditoría:

- `stat -c %a /root` en una instalación de NCI (R9).
- `subvolid=` en el `fstab` de NCI (versión actual de `genfstab`).
- `loader.conf` que deja `bootctl install` en NCI (R6) y si crea un directorio
  `<entry-token>` o `/etc/kernel/entry-token` (en Calamares, con el machine-id
  del live).
- `pacman.conf` final del target en NCI (R2), por si algún paquete o scriptlet
  lo modifica después.
- Que no aparecen `.pacnew` en NCI.
- Permisos de los initramfs en NCI (Calamares fuerza 0600).
- Arranque gráfico en NCI con `splash` sin hook de plymouth (R5).
- Con Hyprland: lista final de paquetes en ambos (H1), qué genera Hyprland 0.57
  sin `~/.config/hypr` en NCI (H4), sesión preseleccionada por SDDM (H5),
  teclado efectivo en los greeters y en Hyprland, y el enlace roto
  `ly@tty2.service` de Calamares (también sin escritorio).

## Puntos de decisión para el instalador propio

No se deciden aquí. Para cada diferencia hay que elegir una referencia o
desviarse de forma documentada:

1. **Referencia por defecto.** Calamares es el instalador gráfico oficial y el
   más probado; NCI tiene fallos claros en R2 (repos y `SigLevel`), R3 (MD5) y
   R9 (`/root`). Propuesta a discutir: tomar Calamares como base y corregir sus
   rarezas (R7 duplicados, R8 restos, `remove-nvidia`, `nopasswdlogin`, caché).
2. Kernels: uno o dos (R4).
3. Plymouth: completo (Calamares) o fuera del todo. A medias (NCI) no tiene
   sentido.
4. Paquetes: el conjunto de escritorio completo que instalan ambos, o un
   subconjunto pensado para Hyprland (depende de la Fase 3). En las diferencias
   de [4](#4-paquetes): `snapper`/`btrfs-assistant` (Omarchy exige Snapper),
   `paru` frente a `shelly`/`octopi`.
5. Shell: fish (Calamares, y lo que exige `omarchy-on-cachyos`) o bash.
6. `loader.conf` y `/etc/kernel/cmdline` propios y limpios.
7. `fstab`: formato de Calamares (sin `subvolid`, apto para *rollback*) y si se
   mantiene la línea tmpfs de `/tmp`.
8. Cifrado: LUKS2 como Calamares (`rd.luks.uuid`, `crypttab` sin opciones),
   base para TPM2 en la Fase 5.
9. `ModemManager`: activarlo o no.
10. Hyprland ([12](#12-con-escritorio-hyprland)): ninguno de los dos oficiales
    es la referencia final (se adaptará Omarchy 4.x, Fase 3), pero hay que
    decidir qué tomar de cada uno: greetd + noctalia-greeter (Calamares) frente
    a SDDM (NCI; Omarchy también usa SDDM), recopia del skel tras instalar el
    escritorio, `kb_layout` en la configuración de Hyprland, y no heredar
    `allow_empty_password = true`.
