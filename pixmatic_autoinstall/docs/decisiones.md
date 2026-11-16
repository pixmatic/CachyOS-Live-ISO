# Decisiones del proyecto

Registro de las decisiones tomadas para la ISO y el instalador propio, con su
fecha y su motivo. Las auditorías y comparaciones de las que salen están en
este mismo directorio (ver [README.md](README.md)). El estado de cada fase
está en [fases.md](fases.md).

Regla general: el sistema instalado debe ser **lo más fiel posible al que
dejan los instaladores oficiales de CachyOS**; toda desviación es deliberada
y se anota aquí.

## 1. Generales

- **Base de la rama de trabajo**: `master` (al día con upstream; el resto de
  ramas están fusionadas, obsoletas o tienen otro objetivo). Trabajo en
  `pixmatic_iso`.
- **Instalación estrictamente online** (2026-11-15): paquetes siempre desde
  los repos, nunca copiando el squashfs del live. En auditorías se ignora
  todo lo exclusivo del modo offline de los instaladores oficiales (en
  Calamares, `settings_offline.conf` y sus módulos, como `unpackfs` o
  `shellprocess@before` con `remove-nvidia`/`removeun`).
- **Instalador propio, de bajo nivel** (2026-11-15), en vez de
  `cachyos-installer` headless. Calamares y `cachyos-installer` (paquete
  `cachyos-cli-installer-new`) son solo **referencia**. Calamares no va en la
  ISO; `cachyos-installer` sigue en ella de momento para pruebas e
  instalaciones de referencia.
- **Referencia de implementación** de la integración en la ISO: rama
  `wip/quicktest-cli-intagration`.

## 2. ISO live

- **Solo `linux-cachyos`** (2026-11-16), sin `-lts` ni ZFS (`remove.list`
  quita `mkinitcpio.d/linux.preset`, que apunta al `-lts`, y
  `modules-load.d/zfs.conf`). Solo herramientas de disco del instalador
  propio (btrfs, vfat, LUKS2, gptfdisk; sin lvm2/xfsprogs/f2fs-tools/parted/zfs:
  con `cachyos-installer` solo se puede probar btrfs/ext4) + `nvme-cli` para
  el borrado seguro del disco al empezar la instalación. Editor: solo `nano`.
- **Paquetes compilados para x86-64-v3** (2026-11-16): el `archiso/pacman.conf`
  del overlay añade `[cachyos-v3]`, `[cachyos-extra-v3]`, `[cachyos-core-v3]`
  (`mirror.cachyos.org/repo/$arch_v3`) delante de `[cachyos]`. La ISO no
  arranca en CPUs sin -v3; `build.sh` aborta si el host no soporta -v3
  (mkarchiso ejecuta los scriptlets en el host). El `pacman.conf` del propio
  live (`airootfs/etc/pacman.conf`) sigue siendo el genérico de upstream.
- **Exclusivamente UEFI con systemd-boot** (2026-11-16), sin GRUB ni syslinux:
  `bootmodes=('uefi.systemd-boot')` en `profiledef.append.sh`; `remove.list`
  quita `grub/`, `syslinux/` y `efiboot/loader/entries`; el overlay trae
  `efiboot/loader/loader.conf` (`timeout 0`, sin auto-entries ni firmware) y
  una única entrada (`linux-cachyos`, mismos parámetros que la entrada por
  defecto de GRUB). Arranca directo; manteniendo pulsado espacio aparece el
  menú. `prepare_profile.sh` no llama a `change_grub_version`; `grub` y
  `syslinux` fuera del live. `mkarchiso` genera la ESP como partición GPT
  (sirve para `dd` a USB).
- `packages.x86_64` propio (~50 paquetes), sin Plasma, Calamares, herramientas
  de VM ni de rescate; sin `cachyos-hooks` ni `cachyos-settings` (verificar en
  la prueba que no hacían falta). `default.target` → `multi-user.target`.

## 3. Referencia del sistema instalado

- **Replicar el sistema resultante de Calamares, con la forma de NCI**
  (2026-11-15, tras [comparacion-base-resultante.md](comparacion-base-resultante.md)):
  secuencia lineal de pasos con nombre, `pacstrap` + `arch-chroot`, fácil de
  pasar a bash. De Calamares, sobre todo: `pacman.conf` con repos optimizados
  y `SigLevel` global (no el `Optional TrustAll` de NCI), yescrypt (no MD5 ni
  SHA-512), `/root` 0750, Plymouth completo (hook + tema), LUKS2 y **abortar
  si falla un paso crítico** (NCI solo avisa).
- **Qué se toma de NCI** (desviaciones deliberadas respecto a Calamares):
  - cmdline limpia, sin parámetros duplicados (Calamares repite
    `nowatchdog quiet splash`);
  - ESP sin restos (nada de `/boot/<machine-id>/<kver>/`);
  - target sin restos: caché de paquetes vacía (NCI `0.13.0` ya la deja
    llena; la decisión se mantiene, pero ya no es «como NCI»), sin `.pacnew`,
    sin `remove-nvidia`, sin `/etc/default/*` ni el enlace roto
    `ly@tty2.service`;
  - `snapper` + `btrfs-assistant`, y snapshot de instalación si está
    `cachyos-snapper-support`;
  - `ModemManager` **no se activa** (Calamares sí), 2026-11-16.
- **Kernel único**: `linux-cachyos` (+ headers), sin `-lts` (como NCI;
  Calamares instala los dos).
- **Shell del usuario: fish** (como Calamares). Omarchy 4.x no lo exige (su
  shell es bash). Pendiente de confirmar al cerrar la Fase 3.
- Valores provisionales (en `settings.jsonc`): ESP de 2 GiB en `/boot` sin
  cifrar, `es_ES.UTF-8`, teclado `es`, `Europe/Madrid`.

### Decisiones de detalle (2026-11-16)

Cierran los puntos de decisión de
[comparacion-base-resultante.md](comparacion-base-resultante.md#decisiones-tomadas-2026-11-16):

- `HOOKS` con `keyboard` **antes de `autodetect`** (como NCI): módulos de todos
  los teclados para escribir la frase de LUKS con cualquiera.
- Plymouth **como Calamares**: `UseSimpledrm=1` en un drop-in de
  `/etc/plymouth/plymouthd.conf.d/` (sin tocar el fichero del paquete) y
  `HOOKS` **sin `kms`**. Resultado previsto: `base systemd keyboard autodetect
  microcode modconf block sd-vconsole plymouth sd-encrypt filesystems` (orden
  exacto a confirmar al escribir el drop-in).
- `zswap.enabled=0` en `/etc/kernel/cmdline` (como NCI; coherente con zram).
- Mapper LUKS: `root` (lo fija gpt-auto).
- `luksFormat`: valores por defecto de `cryptsetup` para LUKS2 (argon2id).

## 4. Disco, cifrado y montajes

- **LUKS2 al particionar** (`cryptsetup luksFormat`); la raíz se desbloquea en
  el initrd por gpt-auto (`gpt-auto-root-luks` → `/dev/mapper/root`,
  initramfs con systemd y `sd-encrypt`). El TPM2 es la Fase 5.
- **Sin `/etc/fstab`**: montajes «a la manera moderna» de systemd
  (Discoverable Partitions Specification + `systemd-gpt-auto-generator`, que
  systemd-boot habilita al exportar `LoaderDevicePartUUID`). Implica:
  - tipos GPT correctos: ESP `C12A7328-F81F-11D2-BA4B-00A0C93EC93B` (se monta
    sola en `/boot` con automount) y raíz x86-64
    `4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709` (no el `0FC63DAF…` genérico que
    usan los dos oficiales); con LUKS, gpt-auto también la desbloquea;
  - `/tmp` como tmpfs por `tmp.mount` de systemd;
  - **raíz**: `btrfs subvolume set-default` de `@`; la cmdline
    (`/etc/kernel/cmdline`) **no lleva `root=` ni `subvol=`**, solo
    `rootflags=noatime,compress=zstd:1` (en btrfs casi todas las opciones son
    del sistema de ficheros entero y las fija el primer montaje). Así
    `snapper rollback` (que cambia el subvolumen por defecto) funciona sin
    tocar el bootloader, y la cmdline es estable y sin UUID;
  - **resto de subvolúmenes**: layout **plano** en el nivel superior del btrfs
    (hermanos de `@`) y **una unidad `.mount` por montaje** en
    `/etc/systemd/system/` (`What=/dev/gpt-auto-root`, `Type=btrfs`,
    `Options=subvol=@x`, `WantedBy=local-fs.target`; nombre con
    `systemd-escape -p --suffix=mount <ruta>`). En el instalador, una función
    tipo `add_subvol <subvol> <ruta>` que crea el subvolumen y su unidad.
    Montajes futuros (subvolúmenes, discos de datos, `.automount`) siguen el
    mismo patrón y quedan en `/etc` (versionados con etckeeper);
  - `What=/dev/gpt-auto-root` sin UUID: comprobado en systemd 262 (man
    `systemd-gpt-auto-generator`, reglas udev `13-dm-disk.rules:46` y
    `90-image-dissect.rules:21-30`): udev crea el enlace para la raíz
    descubierta vía `LoaderDevicePartUUID`; con LUKS apunta al mapper abierto
    `/dev/mapper/root`; `rootflags=` se respeta. Confirmar en VM que existe
    tras salir del initrd.
  - Descartados: `systemd.mount-extra=` (montajes en la cmdline, que crece y
    obliga a regenerar entradas) y subvolúmenes anidados en `@` (no necesitan
    montaje, pero un rollback deja fuera `/home`, `/var/log`…).
  - **Pendiente**: quitar `root=` de las entradas de systemd-boot
    (`sdboot-manage gen` añade `root=UUID=…`; alternativa: `kernel-install` +
    `/etc/kernel/cmdline`, el camino nativo de `bootctl`).

## 5. Paquetes: un único `pacstrap`

- **Un único `pacstrap` principal** con todos los paquetes de repositorio:
  base, kernel, conjunto oficial, escritorio, aplicaciones de Omarchy
  elegidas y programas adicionales de la configuración. Nunca transacciones
  aparte (salvo las de `chwd`). Motivos: una sola resolución de dependencias
  (falla pronto y entero), initramfs generado una vez y ya correcto (sin
  desactivar el hook como Calamares ni regenerar como NCI), hooks de pacman
  una sola vez, y al crear el usuario **después** de los paquetes,
  `useradd -m` ya copia el skel del escritorio (sin la recopia de Calamares).
  Reintentos ante fallos de red: repetir el mismo `pacstrap` (la caché
  conserva lo descargado; Calamares reintenta hasta 6). Solo valen paquetes
  de los repos del `pacman.conf` del `pacstrap` (el AUR no cabe); validar la
  lista antes de empezar.
- **Antes del `pacstrap`**, escribir en el target solo ficheros **sin dueño**
  (si un paquete trae el fichero, pacman aborta por conflicto; de ahí los
  `.pacnew` de Calamares): `pacman.conf` (con `-C` y copiado al final),
  `/etc/vconsole.conf`, `HOOKS` en un drop-in de `/etc/mkinitcpio.conf.d/`
  (no se edita `mkinitcpio.conf`, que es del paquete; desviación deliberada
  respecto a ambos oficiales), `/etc/kernel/cmdline` y, si hace falta,
  `/etc/crypttab.initramfs`.
- **Pasos aparte**, solo donde hay dependencia real: `chwd -a` (detecta el
  hardware desde el target y usa su propio pacman; puede añadir NVIDIA y
  regenerar el initramfs); bootloader (`bootctl install`, entradas y, si se
  usa, `systemd-boot-manager`, cuyos hooks esperan systemd-boot ya en la ESP;
  NCI también lo separa); tema visual de Hyprland (ficheros en el `$HOME` del
  usuario, o en chezmoi en la Fase 6).
- **Orden**: preparar configuración → llaveros de los repos extra en el live
  → `pacstrap` único → ajustes del sistema → crear usuario → ajustes del
  usuario (`kb_layout` en la config de Hyprland, tema) → `chwd` →
  bootloader.
- Verificar en VM: que el hook de `mkinitcpio` corre al final de la
  transacción (con `plymouth` ya instalado) y que el drop-in de
  `mkinitcpio.conf.d/` sustituye a los `HOOKS` de `mkinitcpio.conf`.

## 6. Repositorios y llaveros

Desviación deliberada (2026-11-16): ningún instalador oficial de CachyOS
añade estos repos.

- **Orden de prioridad** en el `pacman.conf` del `pacstrap` y del sistema
  instalado: repos de CachyOS (optimizados y `[cachyos]`) → `[core]`,
  `[extra]`, `[multilib]` → **`[omarchy]`**
  (`https://pkgs.omarchy.org/stable/$arch`, con `omarchy-keyring`) →
  **`[chaotic-aur]`** (última prioridad; `Include =
  /etc/pacman.d/chaotic-mirrorlist`, con `chaotic-keyring` y
  `chaotic-mirrorlist`).
- `[omarchy]` **solo con la personalización «omarchy» activada**;
  `[chaotic-aur]` siempre.
- `[omarchy]` va **detrás** de CachyOS para que no sustituya `quickshell`,
  `yay`, `walker`, `localsend`, `limine-*`… Su repo estable x86_64 **no
  publica** `hyprland` ni `nvidia-utils`/`nvidia-open-dkms` (comprobado en su
  base de datos real; sus PKGBUILDs no coinciden con lo publicado). De las 162
  aplicaciones de `omarchy-base.packages` sirve 32 y 27 solo existen en él;
  `nvim` no existe en ningún repo comprobado (Arch: `neovim`). Detalle en
  [auditoria-omarchy.md §5](auditoria-omarchy.md#5-repositorios-y-pacmanconf).
- `omarchy-hyprland-titlebars`: el publicado depende de `hyprland=0.56.2`
  exacto y CachyOS tiene 0.57.2 → **hoy no se puede instalar**; cada salto de
  versión de Hyprland en CachyOS lo romperá hasta que Omarchy lo siga.
  Marcarlo con ese aviso en `settings.jsonc`.
- **Llaveros: `pacman-key --recv-keys` + `--lsign-key` en el live, al
  instalar** (decidido 2026-11-16; necesita red y servidor de claves; no se
  meten en la ISO al construirla). `omarchy-keyring`, `chaotic-keyring` y
  `chaotic-mirrorlist` solo existen en sus repos, así que el live tiene que
  confiar en sus claves antes del `pacstrap`. Claves verificadas (detalle en
  [auditoria-omarchy.md](auditoria-omarchy.md#claves-de-firma-verificadas-2026-11-16)):
  - `[omarchy]`: `40DFB630FF42BCFFB047046CF0134EE680CAC571`
    (`Omarchy <pkgs@omarchy.org>`; firma con la primaria, la misma que firma
    su ISO). Su base de datos no va firmada.
  - `[chaotic-aur]`: **dos** claves,
    `EF925EA60F33D0CB85C44AD13056513887B78AEB` (firma `chaotic-keyring`) y
    `67BF8CA6DA181643C9723B4ED6C9442437365605` (su subclave firma
    `chaotic-mirrorlist` y el resto; caduca 2028-06-14). Las instrucciones
    oficiales solo firman la primera porque luego instalan `chaotic-keyring`;
    con un `pacstrap` único hacen falta las dos.
  - Servidor explícito: `pacman-key --recv-keys --keyserver
    hkps://keyserver.ubuntu.com` (probado; el `gpg.conf` de pacman no fija
    servidor). Huellas completas, no ID cortos.
- `chaotic-mirrorlist` no está en el live: para el `pacstrap` usar un
  `Server =` de Chaotic directo (o `pacman -U` del paquete desde su CDN); el
  sistema instalado queda con el `Include` al mirrorlist del paquete.
- Los tres paquetes de llavero van también en el `pacstrap`, para que el
  sistema instalado quede con sus llaveros.

## 7. Hyprland y Omarchy

- **Hyprland** (escenario A de
  [sistema-resultante-hyprland.md](sistema-resultante-hyprland.md)): el grupo
  de Calamares `cachyos-staging` (`hyprland dolphin kitty sddm
  cachyos-hypr-noctalia`) dentro del `pacstrap` único, desde los repos
  optimizados y abortando si falla. SDDM con `systemctl enable sddm`, sin el
  `/etc/sddm.conf` inútil de Calamares ni el `ly@tty2.service` roto de
  `dmcheck`. Los dotfiles llegan por `useradd -m`. Se corrige lo que tienen
  mal ambos oficiales: Hyprland sin `kb_layout` (queda en `us`). Los ficheros
  del greeter noctalia (`allow_empty_password = true`) llegan con el paquete
  pero no se usan con SDDM.
- **Omarchy no se aplica** (2026-11-16). Solo se toman **(a) aplicaciones**
  que se elijan y **(b) el tema visual de Hyprland**. No se instalan
  `omarchy`/`omarchy-settings` ni se ejecutan sus comandos. Así no importan
  sus conflictos con CachyOS (Limine obligatorio, HOOKS busybox,
  `pacman.conf` sustituido, `os-release`, NVIDIA por DKMS, ficheros
  sobrescritos en cada actualización). Referencia: tag `v4.5.0`
  ([auditoria-omarchy.md](auditoria-omarchy.md)).
  - **Aplicaciones**: de `install/omarchy-base.packages`. No trae coreutils
    en Rust (ni `uutils-coreutils` ni `sudo-rs`); trae **sustitutos modernos
    de herramientas de terminal** con alias en `default/bash/aliases`: `eza`
    (`ls`), `bat` (`cat` y `MANPAGER`), `fd` (`find`), `ripgrep` (`grep`),
    `zoxide` (`cd`), `starship` (prompt), todos en Rust, más `fzf` y `btop`.
    Para los alias en fish, `omarchy-fish` como referencia (sin instalarlo).
  - **Tema visual**: por defecto **Tokyo Night** (`install/user/theme.sh`);
    24 temas en `themes/<nombre>/` (`colors.toml`, fondos, iconos…). Las
    configs con colores se generan con `omarchy-theme-set` desde
    `default/themed/*.tpl` (`hyprland.lua.tpl`: bordes con el `accent`;
    también kitty, btop…). La config de Hyprland está en Lua
    (`config/hypr/*.lua`, con `looknfeel.lua` para bordes, huecos,
    animaciones y desenfoque) y el escritorio (barra, lanzador,
    notificaciones) es **Quickshell** (`shell/`), no waybar/walker.

## 8. Configuración del instalador (`settings.jsonc`)

- La configuración del instalador propio va en el **mismo
  `pixmatic_autoinstall/settings.jsonc`** (2026-11-16), con su estilo: todas
  las opciones presentes y comentadas. Nombres de clave por decidir en la
  Fase 4. Tendrá al menos:
  - una clave para **activar/desactivar la personalización «omarchy»**
    (opcional; desactivada = Hyprland de CachyOS tal cual);
  - una clave con **qué aplicaciones y temas de Omarchy se insertan**:
    **todas** las aplicaciones de `install/omarchy-base.packages` del tag
    auditado y **todos** los temas de `themes/` (24 en `v4.5.0`),
    **comentados**; se activan descomentando;
  - una clave con **programas adicionales** (de momento vacía).
- `cachyos-installer` rechaza claves desconocidas: mientras siga en la ISO,
  nuestras claves deben ir separadas (prefijo u objeto propio que `build.sh`
  quite al generar el JSON para `cachyos-installer`). Forma por decidir en la
  Fase 4.
