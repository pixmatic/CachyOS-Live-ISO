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
  `cachyos-cli-installer-new`) son solo **referencia**. Ninguno va en la ISO
  (`cachyos-installer` se quitó el 2026-11-16, al tener instalador propio).
- **Referencia de implementación** de la integración en la ISO: rama
  `wip/quicktest-cli-intagration`.

## 2. ISO live

- **Solo `linux-cachyos`** (2026-11-16), sin `-lts` ni ZFS (`remove.list`
  quita `mkinitcpio.d/linux.preset`, que apunta al `-lts`, y
  `modules-load.d/zfs.conf`). Solo herramientas de disco del instalador
  propio (btrfs, vfat, LUKS2, gptfdisk; sin lvm2/xfsprogs/f2fs-tools/parted/zfs)
  + `nvme-cli` para el borrado seguro del disco (aún no se usa, §9). Editor: solo `nano`.
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
- **Teclado español en la consola del live** (2026-11-16): `vconsole.conf`
  con `KEYMAP=es` en el overlay (upstream no trae ninguno: era `us`). El
  initramfs de archiso no lleva hook de teclado; lo aplica
  `systemd-vconsole-setup` al arrancar el sistema.
- **SSH al live sin contraseña ni claves**, como `root` y `liveuser`
  (2026-11-16), para depurar instalaciones en VM:
  `airootfs/etc/ssh/sshd_config.d/20-pixmatic.conf` con `PermitRootLogin
  yes`, `PasswordAuthentication yes` (ya en `10-archiso.conf` de upstream) y
  `PermitEmptyPasswords yes`. Las dos cuentas ya tienen la contraseña vacía en
  el `shadow` de upstream; sshd usa `UsePAM no`, así que entra sin preguntar
  (comprobado con `sshd -T`). **Riesgo**: cualquiera en la red del live entra
  como root. Solo afecta al live, no al sistema instalado.
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
  `/etc/plymouth/plymouthd.conf.d/` (sin tocar el fichero del paquete; **no
  es posible**, ver §9) y
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
  - Entradas de systemd-boot sin `root=`: las escribe el instalador desde
    `/etc/kernel/cmdline`, porque `systemd-boot-manager` 21 añade
    `root=UUID=…` (§9).

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
  respecto a ambos oficiales), `/etc/kernel/cmdline` y la línea de
  `/etc/crypttab` (el del paquete queda como `.pacnew` y se recupera después,
  §9).
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
  mal ambos oficiales: Hyprland sin `kb_layout` (queda en `us`); tras
  `useradd -m`, `pixmatic-install` añade al final de
  `~/.config/hypr/hyprland.lua` del usuario `hl.config({ input = { kb_layout
  = "<xkbmap>" } })` (2026-11-16). Un `hl.config` posterior solo cambia las
  claves que nombra (así funcionan los overrides de usuario de Omarchy,
  `omarchy:config/hypr/input.lua`); `inputs.lua` de `cachyos-hypr-noctalia`
  `1.2.6` solo fija `accel_profile`. No se toca `/etc/skel` (es del paquete). Los ficheros
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

- La configuración del instalador propio va en
  **`pixmatic_autoinstall/settings.jsonc`** (2026-11-16), con su estilo: todas
  las opciones presentes y las no usadas comentadas con descripción, valores
  y valor por defecto. Tendrá al menos:
  - una clave para **activar/desactivar la personalización «omarchy»**
    (opcional; desactivada = Hyprland de CachyOS tal cual);
  - una clave con **qué aplicaciones y temas de Omarchy se insertan**:
    **todas** las aplicaciones de `install/omarchy-base.packages` del tag
    auditado y **todos** los temas de `themes/` (24 en `v4.5.0`),
    **comentados**; se activan descomentando;
  - una clave con **programas adicionales** (`extra_packages`, vacía).
- **Esquema propio, sin `cachyos-installer`** (2026-11-16): al quitarlo de la
  ISO, el fichero deja de seguir su formato. Se conservan sus nombres para
  `device`, `hostname`, `locale`, `xkbmap`, `timezone`, `user_name`,
  `user_pass` y `root_pass`, y se quitan las claves que no aplican porque el
  script fija esos valores según este documento (modos de instalación,
  particionado y sistema de ficheros, `hw_clock`, `user_shell`,
  `user_groups`, kernel, bootloader, `os_prober`, escritorio y `netinstall`
  con su formato, perfiles de servidor, `post_install`, `chwd`, `hostcache`,
  `carry_network`) y los alias. `device` y `on_finish` (clave nueva hasta
  entonces) se quitaron el 2026-11-17: el disco y qué hacer al terminar se
  eligen en el menú (§10).
- Claves nuevas: `console_keymap` (por defecto, `xkbmap`),
  `firewall` (ufw; `false` por ahora), `user_fullname` (GECOS),
  `extra_packages` y `additional_packages`. La clave `confirm` (pedir
  escribir YES antes de borrar el disco) se quitó el 2026-11-17: el
  instalador no hace ninguna pregunta.
- `ssh_server` (2026-11-17, desviación deliberada para depurar; los
  oficiales no activan sshd): instala `openssh` si falta, escribe
  `/etc/ssh/sshd_config.d/20-pixmatic.conf` (`PermitRootLogin yes`,
  `PasswordAuthentication yes`) y activa `sshd.service`. Acceso con usuario y
  contraseña, también root. `true` en el `settings.jsonc` del repo mientras
  se depura en VM. Con `firewall: true` ufw bloquearía el puerto 22.
- **`additional_packages`** (2026-11-16): árbol con los grupos de netinstall
  de Calamares (`netinstall.yaml` de `cachyos-staging`), grupo → (subgrupo →)
  paquete: `true`/`false`, como se marcan en Calamares. Se instalan los
  paquetes a `true`, dentro del `pacstrap` único; un grupo comentado no se
  instala. Las listas viven en `settings.jsonc` (el script no las repite) y
  se pueden ampliar.
  - **Grupo marcado sin ningún paquete**: en Calamares no existe; el estado
    de un grupo se deriva de sus hijos y, al desmarcar todos, el grupo se
    desmarca solo (`src/modules/netinstall/PackageTreeItem.cpp:210-238`), y
    la instalación solo recoge paquetes marcados
    (`PackageModel.cpp:344-365`), sin otro efecto. Aquí, un grupo con todos
    a `false` no instala nada: mismo resultado.
  - Valores del fichero: preseleccionados en Calamares, a `true` y enteros
    (con sus paquetes gráficos, por fidelidad): *CachyOS Packages*, *CachyOS
    shell configuration*, *Base-devel + Common packages* (por subgrupos) y
    *Plymouth*. Opcionales sin escritorio, a `false` y sin sus paquetes
    gráficos: *Printing-Support* (sin `system-config-printer`) y *Support
    for HP Printer/Scanner* (sin `python-pyqt5`, que solo usa la interfaz
    gráfica de `hplip`). De escritorio, **activos** (2026-11-17; antes comentados): *Firefox
    and language package* e *Hyprland* (paquetes, SDDM y teclado; aplicaciones
    y tema de Omarchy, Fase 3).
    Fuera el resto de escritorios y *Accessibility Tools* (`orca`,
    `mousetweaks`). *CachyOS required* sigue fijo (ya está en la lista de
    `pacstrap.conf`).
  - Con Firefox activo, la instalación por defecto instala `firefox` y
    `firefox-i18n-es-es`, como Calamares (grupo preseleccionado no crítico).
    Comentarlo es una desviación.
  - Dependencias de lo fijo: sin `cachyos-fish-config` se instala `fish`
    suelto (shell del usuario); con `firewall: true` se añade `ufw`. Como
    Calamares mira lo instalado, el script usa la lista resuelta por
    `pacman -Sp` (con dependencias): el hook `plymouth` y `plymouthd.conf`
    solo si se instala `plymouth` (aunque llegue como dependencia de un
    tema), y `Theme=` solo si se instala el paquete del tema. Los servicios
    (incluido `cups.service`) se activan solo si su unidad está instalada; la
    copia de conexiones de NetworkManager, solo si está NetworkManager.
- La sección de claves futuras va antes de la última sección para que el
  objeto lo cierre una clave activa sin coma: descomentar una clave no
  obliga a tocar comas.
- `build.sh` copia `settings.jsonc` tal cual, con comentarios, a
  `/etc/pixmatic/settings.jsonc` (600), para que al editarlo en el live se
  vean las descripciones (2026-11-16; antes generaba un `settings.json` sin
  comentarios). `pixmatic-install` quita las líneas `//` al leerlo y lo lee
  con `jq`; `build.sh` lo valida igual para no generar una ISO con un fichero
  roto. Las claves sin valor por defecto son obligatorias.
- **Shell fija: fish** (2026-11-16).

## 9. Primera versión del instalador (2026-11-16)

`archiso/airootfs/usr/local/bin/pixmatic-install`: un solo script bash que
sigue el orden de §5. Lo que concreta o cambia respecto a lo anterior:

- **Alcance**: sin escritorio, con `[chaotic-aur]` y sin `[omarchy]`,
  ejecución manual (desde el 2026-11-17 se lanza desde el menú del live,
  §10). Configuración desde `settings.jsonc` (§8).
  **Sin preguntas** (2026-11-17): no pide confirmación antes de borrar el
  disco y `user_pass`/`root_pass` (obligatorias) se usan tal cual, aunque
  sean `CHANGEME` o vacías (antes se preguntaba la del usuario y root
  reutilizaba la suya, como `doReusePassword` de Calamares). Copia su log a `/var/log/pixmatic-install.log` del target
  (resto deliberado mientras se depura).
- **LUKS2 con contraseña vacía**: `luksFormat` con un keyfile de 0 bytes
  (probado con cryptsetup 2.8.8: formatea y abre). Para que el initramfs la
  pruebe sin preguntar hace falta `try-empty-password=yes`, y
  **`systemd-gpt-auto-generator` no lee `rd.luks.options=`** (systemd `v262`,
  `src/gpt-auto-generator/gpt-auto-generator.c:79-139`: sus opciones son solo
  `read-only` y `tpm2-*`). Se usa una línea de `/etc/crypttab`,
  `root /dev/gpt-auto-root-luks none try-empty-password=yes,x-initrd.attach`
  (mkinitcpio 42 avisa de que `crypttab.initramfs` está obsoleto; su
  `sd-encrypt` copia al initramfs las líneas con `x-initrd.attach`; cambio del
  2026-11-17 tras la prueba en VM). Se escribe antes del `pacstrap` y el
  `/etc/crypttab` del paquete `filesystem` queda como `.pacnew`, que luego lo
  sustituye con la línea al final (mismo initramfs, generado una vez). Genera la misma
  unidad `systemd-cryptsetup@root.service`, y como gpt-auto escribe la suya en
  el directorio *late* de los generadores, prevalece la de `crypttab`. Sin
  UUID, y la Fase 5 añadirá ahí `tpm2-device=auto`. Responde a la pregunta
  abierta de la Fase 5.
- **Plymouth no lee drop-ins** (`plymouthd` 26 solo busca
  `/etc/plymouth/plymouthd.conf` y `plymouthd.defaults`): el drop-in de §3 no
  es posible. Se escribe `/etc/plymouth/plymouthd.conf` (`Theme=` +
  `UseSimpledrm=1`) **antes del `pacstrap`**, para que el initramfs salga con
  el tema a la primera; pacman deja el del paquete (solo comentarios, en
  `backup`) como `.pacnew`, que se borra. Tema `cachyos-bootanimation`, o
  `cachyos` si `chwd --check amd` (como `plymouthcfg`).
- **`HOOKS`** en `/etc/mkinitcpio.conf.d/90-pixmatic.conf` (orden de §3).
- **`noatime` en cada montaje**: es una opción del VFS por punto de montaje,
  no del btrfs entero, así que las unidades `.mount` llevan
  `Options=subvol=@x,noatime,compress=zstd:1` (como cada línea del `fstab` de
  Calamares). La raíz recibe lo mismo por `rootflags=`.
- **`/etc/kernel/cmdline`**: `rw rootflags=noatime,compress=zstd:1
  zswap.enabled=0`.
- **`/` monta con `nodev`** (visto en la VM, 2026-11-17) sin pedirlo: lo
  pone `systemd-gpt-auto-generator` (la cadena está en su binario, no en su
  manual; sin confirmar en el código). Solo impide usar nodos de dispositivo
  guardados en la raíz; `/dev` es devtmpfs aparte. Se acepta como
  comportamiento de gpt-auto.
- **Entradas de systemd-boot escritas por el instalador** (2026-11-17, tras
  la prueba en VM). Se auditó `sdboot-manage` de PKGBUILDS `master`
  (`systemd-boot-manager` **24**, que usa `/etc/kernel/cmdline` +
  `LINUX_OPTIONS` y no añade `root=`, `sdboot-manage:298-307`), pero el repo
  `cachyos` sirve la **21** (2026-11-17), que no lee `/etc/kernel/cmdline` y
  construye `root=UUID=… rw rootflags=subvol=/@ cryptdevice=UUID=…:root` +
  `LINUX_OPTIONS` a partir de `findmnt /`. Efecto observado en la VM: `/` sin
  `noatime`, **btrfs sin compresión** (`compress` es de todo el sistema de
  ficheros y lo fija el montaje de `/`), sin `zswap.enabled=0`, y
  `subvol=/@` fijo, que anula `snapper rollback`. Los sistemas de Calamares
  tienen hoy el mismo problema (su `/etc/kernel/cmdline` también se ignora).
  Solución: el instalador escribe una entrada por `/boot/vmlinuz-*` como lo
  hace la 24 (`title`, `options` = `/etc/kernel/cmdline` + `LINUX_OPTIONS` de
  `/etc/sdboot-manage.conf`, `linux`, `initrd`) y deja
  `/etc/sdboot-manage.conf.d/90-pixmatic.conf` con `OVERWRITE_EXISTING="no"`
  para que el hook de `systemd-boot-manager` (al actualizar el kernel) no la
  sobrescriba; las rutas no cambian. Un kernel instalado después tendría
  entrada al estilo de la 21. **Quitar el apaño cuando el repo sirva la 24**
  (vigilar `pacman -Si systemd-boot-manager`).
- **ufw instalado pero desactivado por ahora** (decisión del usuario,
  2026-11-16; desviación respecto a ambos oficiales, que lo activan): clave
  `firewall: false`. Con `true`: `systemctl enable ufw` + `ENABLED=yes` en
  `/etc/ufw/ufw.conf` (las políticas por defecto del paquete ya son *deny
  incoming* / *allow outgoing*), en vez de `ufw enable` en el chroot, que
  cargaría las reglas en el kernel del live y cortaría el SSH (hallazgo 8 de
  Calamares).
- **Conexiones de NetworkManager del live** copiadas al sistema instalado
  sin pisar las existentes y con `permissions=user:liveuser:;` cambiado al
  usuario, como Calamares (Cal §22).
- **`[chaotic-aur]`** como en §6: claves `--recv-keys` + `--lsign-key` en el
  live; al final del `pacman.conf`; el `pacstrap` usa los servidores del
  `chaotic-mirrorlist` del paquete (20260428-1) en su orden, `geo-mirror`
  y `cdn-mirror` (`https://<x>.chaotic.cx/$repo/$arch`; antes solo
  `cdn-mirror`, que el 2026-11-17 dio 503 continuos y tumbó la instalación
  en la VM), y el sistema instalado `Include = /etc/pacman.d/chaotic-mirrorlist`; `chaotic-keyring` y
  `chaotic-mirrorlist` en el `pacstrap`.
- Se replica de Calamares: paquetes (sus listas sin `-lts`, con `os-prober`,
  `firefox-i18n-es-es` y el resto de grupos preseleccionados; + `snapper` y
  `btrfs-assistant` de NCI), `/root` 0750, grupo `nopasswdlogin`,
  `vconsole.conf` y `00-keyboard.conf`, bloque de `locale.gen` con `en_US`,
  `locale.conf`, `hosts`, `sudoers.d/10-installer`, `loader.conf`, servicios.
- Se omite (NCI, o sin efecto): `/etc/timezone`, `/etc/default/{keyboard,locale}`,
  semillas de `random-seed` (las crea systemd), copia de `resolv.conf`.
- Borrado del disco: `wipefs` + `blkdiscard` (si el disco lo admite) +
  `sgdisk --zap-all`. **Sin borrado seguro con `nvme-cli` por ahora**
  (decisión del usuario, 2026-11-16); el paquete sigue en el live.

## 10. Menú del live (2026-11-17)

Sustituye al «servicio que lance la instalación al arrancar» de la Fase 4:
la ISO no instala sola, abre un menú y la salvaguarda contra borrados
accidentales es elegir el disco y confirmar el borrado.

- **`pixmatic-menu`** (`archiso/airootfs/usr/local/bin/`, bash + `dialog`,
  paquete añadido al live). Opciones: *Iniciar instalación*, *Editar
  configuración*, *Modo consola*, *Apagar equipo*. Esc no sale del menú.
- **Arranque**: `/etc/profile.d/pixmatic-menu.sh` lo ejecuta (con `sudo` si
  no es root) una vez por sesión (`PIXMATIC_MENU_SHOWN`) en el login
  automático de `liveuser` en tty1 (el autologin de upstream, sin tocar) y en
  las sesiones SSH interactivas (`SSH_TTY`, como `root` o `liveuser`; en el
  live ambos usan bash, que lee `/etc/profile`). No en otras consolas ni en
  `ssh host comando`, `scp` o `sftp`. *Modo consola* sale al prompt; en tty1,
  `exit` cierra la sesión y getty vuelve a abrir el menú; a mano, `sudo
  pixmatic-menu`. Un cerrojo (`flock` sobre `/run/pixmatic-install.lock`)
  impide dos instalaciones a la vez desde sesiones distintas. Alternativa
  descartada: un servicio propio en tty1 en lugar de getty (habría que
  reabrir getty para el modo consola).
- **Instalación**: el disco **solo se elige de la lista**: discos
  `TYPE=disk`, escribibles, de tamaño no nulo, sin `zram` y sin el medio de
  arranque (el disco que contiene el sistema de ficheros con el UUID de
  `archisosearchuuid=`, que se encuentra también con `copytoram`, cuando el
  medio ya está desmontado). Cada entrada: ruta, tamaño y modelo. Después,
  confirmación con «Cancelar» por defecto, que muestra el disco (tamaño
  y modelo) y sus particiones (tamaño, sistema de ficheros, etiqueta y tipo
  GPT), y `pixmatic-install <disco>`.
- **`pixmatic-install <disco>`**: único argumento, el disco que pasa el menú;
  la configuración es siempre `/etc/pixmatic/settings.jsonc`. Sin opciones
  (ni `-d` ni otra ruta de configuración). Se quitan de `settings.jsonc`
  `device` y `on_finish`. El instalador no pregunta nada (§9).
- **Al terminar bien**: el menú ofrece *Reiniciar*, *Apagar* o *Salir a la
  consola*. **Si falla**: el error queda en pantalla (y en
  `/var/log/pixmatic-install.log`), se indica la ruta del log y se sale del
  menú a la consola, con lo montado en `/mnt` para depurar.
- **Editar configuración**: `nano` sobre `/etc/pixmatic/settings.jsonc`; al
  cerrar se valida como lo lee el instalador (objeto JSON sin las líneas
  `//`) y, si no vale, se ofrece volver a editar o deshacer los cambios.
- Ctrl+C durante la instalación corta `pixmatic-install`, no el menú.
- **Flechas por SSH** (visto en VM, 2026-11-17): con `TERM=xterm*`, `dialog`
  activa el modo «cursor de aplicación» (`smkx`, `\E[?1h`) y espera las
  flechas como `\EOA`; el cliente SSH del usuario lo ignora y envía `\E[A`,
  que `dialog` toma como Esc (el menú se redibuja sin moverse). El menú lanza
  `dialog` con `TERM=xterm-noapp` (terminfo de ncurses: no activa ese modo y
  espera `\E[A`, 8 colores) cuando `TERM` empieza por `xterm`; en tty1
  (`linux`) no cambia. Comprobado en el live enviando ambas secuencias.
- Textos del menú en español; los del instalador siguen en inglés.
