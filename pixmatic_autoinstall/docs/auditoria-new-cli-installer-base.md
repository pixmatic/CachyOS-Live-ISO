# Auditoría de New-Cli-Installer: instalación base sin escritorio

Fase 2, segunda parte. Secuencia exacta de lo que hace `cachyos-installer`
(New-Cli-Installer, en adelante NCI) con las opciones fijas de este proyecto,
traducida a comandos de consola de bajo nivel para poder replicarla.

Este documento **no compara** con Calamares
([auditoria-calamares-base.md](auditoria-calamares-base.md)); la comparación
irá en un documento aparte.

## Versiones auditadas

| Componente | Repo | Rama/tag | Commit | Nota |
|---|---|---|---|---|
| NCI | `CachyOS/New-Cli-Installer` | **tag `0.12.4`** | `bb3eccb` (2026-08-05) | Lo que empaqueta `cachyos-cli-installer-new` 0.12.4-1 (el que trae la ISO). |
| NCI (referencia) | `CachyOS/New-Cli-Installer` | `master` | `47730e4` (2026-11-12) | 150 commits por delante de `0.12.4`. Solo para la sección [Diferencias con `master`](#diferencias-relevantes-con-master). |
| PKGBUILDs | `CachyOS/CachyOS-PKGBUILDS` | `master` | `6c6dc36` (2026-11-15) | `cachyos-cli-installer-new/` (pkgver 0.12.4), `systemd-boot-manager/` (pkgver 24; el repo `cachyos` sirve aún `21-1`). |
| ISO | `CachyOS/CachyOS-Live-ISO` | `master` | `3215497` (2026-10-03) | `/etc/pacman.conf` del live, que NCI copia al target. |

Rutas citadas:

- Sin prefijo: relativas a New-Cli-Installer en el tag `0.12.4`.
- `master:`: relativas a New-Cli-Installer en `master` (`47730e4`).
- `pkgbuilds:`: relativas a `CachyOS-PKGBUILDS/`.
- `iso:`: relativas a este repo (`archiso/…`).

El PKGBUILD (`pkgbuilds:cachyos-cli-installer-new/PKGBUILD`) compila el tag
firmado `0.12.4` con `-DENABLE_DEVENV=OFF` (modo real: los comandos se
ejecutan, no hay *dry-run*) y copia `net-profiles.toml` y
`server-profiles.toml` a `/var/lib/cachyos-installer/` (copias de respaldo; ver
el aviso de abajo). Dependencias: `fzf gawk chwd cachyos-rate-mirrors curl
coreutils util-linux gptfdisk cryptsetup`.

> **Aviso: la lista de paquetes y servicios se descarga en ejecución.**
> `net-profiles.toml` se baja de
> `https://raw.githubusercontent.com/CachyOS/New-Cli-Installer/master/net-profiles.toml`
> y solo si falla se usa `file:///var/lib/cachyos-installer/net-profiles.toml`
> (`installer-lib/include/cachyos/types.hpp:22-23`,
> `gucc/src/package_list.cpp:56-96`). Es decir: **la lista de paquetes de
> `master` de GitHub, no la del tag**. Hoy el fichero es idéntico en `0.12.4` y
> `master` (`git diff 0.12.4 master -- net-profiles.toml` vacío), pero puede
> cambiar sin nueva versión del instalador.

## Alcance: opciones fijas

Solo se sigue el camino que corresponde a estas opciones. El resto de ramas
(GRUB, Limine, rEFInd, ZFS, BIOS, swap, LVM, escritorios, servidor) se ignoran
salvo cuando cambian algo de este camino.

| Opción | Valor | Cómo se expresa en NCI |
|---|---|---|
| Idioma, números y fechas | `es_ES.UTF-8` | `"locale": "es_ES.UTF-8"` (un único locale para `LANG` y las `LC_*`) |
| Zona | `Europe/Madrid` | `"timezone": "Europe/Madrid"` |
| Teclado | modelo `pc105`, distribución `es`, variante por defecto | `"xkbmap": "es"`. **NCI no tiene opción de modelo ni de variante**: no escribe `XkbModel` ni `XkbVariant`. |
| Firmware | UEFI exclusivo (sin CSM), TPM 2.0 | autodetectado (`/sys/firmware/efi/`). NCI no usa el TPM para nada. |
| Bootloader | `systemd-boot` | `"bootloader": "systemd-boot"` |
| Disco | el de la configuración, **borrar disco**, btrfs | `"device"`, `"fs_name": "btrfs"`, `"allow_auto_partition": true` y **sin** `partitions` → estrategia `EraseAndAuto` |
| Cifrado | "Cifrar sistema" con contraseña | **No existe en el modo headless de `0.12.4`** (ver abajo) |
| Escritorio | ninguno | `"desktop": ""` (modo escritorio sin entorno; ver [Paso 9-10](#paso-9-10-desktop-y-desktopconfigure-no-op)) |
| Swap | ninguna | el particionado automático no crea swap |
| Reloj | UTC | `"hw_clock": "utc"` (si se omite, NCI **no** toca el reloj) |

### El cifrado no es posible en headless con `0.12.4`

En `0.12.4` ni el modo headless ni el modo simple (interactivo) cifran:

- `installer_config.cpp` no tiene ninguna clave de LUKS (solo `encrypt_swap` y
  `zfs_passphrase`).
- El orquestador (`installer-lib/src/orchestrator.cpp:175-439`) no tiene paso
  de cifrado; `CreateLayout`/`EraseAndAuto` formatean la raíz directamente con
  `mkfs.btrfs` (`installer-lib/src/disk.cpp:505-522`).
- El modo simple solo **detecta** LUKS ya abierto (`src/simple_tui.cpp:119-120`,
  `:133`).

El único cifrado de `0.12.4` está en el **modo avanzado interactivo**: LUKS1
sobre una partición elegida a mano. Se documenta como delta en
[Cifrado en `0.12.4`: modo avanzado](#cifrado-en-0124-el-camino-del-modo-avanzado).
`master` sí añade cifrado headless (`luks_passphrase`, LUKS2), aún sin
publicar: ver [Diferencias con `master`](#diferencias-relevantes-con-master).

Por tanto, el camino principal auditado es **headless, borrar disco, btrfs,
systemd-boot, sin cifrar, sin escritorio**.

### Modos del instalador

| Modo | Cómo se elige | Partición | Ejecuta | ¿Se audita? |
|---|---|---|---|---|
| Headless | `"headless_mode": true` en el JSON | `EraseAndAuto` o `CreateLayout` | orquestador `run()` (`src/main.cpp:96-155`) | **sí** (camino principal) |
| Simple (TUI) | `menus: 1` o elección en pantalla | el TUI monta y pasa `UseExisting` | el mismo orquestador (`src/simple_tui.cpp:279`, `:307`) | no (mismos pasos salvo partición) |
| Avanzado (TUI) | `menus: 2` | manual (`cfdisk`…) | pasos sueltos desde menús (`src/tui.cpp:2327-2587`) | solo el delta de LUKS |

## Configuración headless equivalente

```json
{
    "install_type": "simple",
    "headless_mode": true,
    "device": "/dev/nvme0n1",
    "allow_auto_partition": true,
    "fs_name": "btrfs",
    "subvolumes": "default",
    "hostname": "…",
    "locale": "es_ES.UTF-8",
    "xkbmap": "es",
    "timezone": "Europe/Madrid",
    "hw_clock": "utc",
    "user_name": "…",
    "user_pass": "…",
    "root_pass": "…",
    "kernel": "linux-cachyos",
    "bootloader": "systemd-boot",
    "desktop": ""
}
```

Valores por defecto que se aplican al omitir claves (`installer_config.cpp:490-509`
y el struct `InstallerConfig`) y que cambian el resultado:

- `user_shell` = `/bin/bash`; grupos del usuario = `wheel rfkill sys users lp
  video network storage audio` (`installer-lib/src/config.cpp:127`).
- `chwd: true` (ejecuta `chwd -a -f` otra vez en el paso `Chwd`; ver
  [Paso 3h](#3h-chwd-siempre) para la primera ejecución, incondicional).
- `carry_network: true`, `hostcache: true`, `os_prober: true` (sin efecto con
  systemd-boot), `autologin: false`, `encrypt_swap: false`.
- `kernel: linux-cachyos` (un solo kernel).

> Nota: `pixmatic_autoinstall/settings.jsonc` usa hoy `CreateLayout` (particiones
> explícitas, ESP de 2G) y `"desktop": "kde"`. Para reproducir este camino hay que
> poner `allow_auto_partition: true`, quitar `partitions` y `"desktop": ""`.
> `CreateLayout` solo cambia el tamaño de la ESP (ver [Paso 2](#paso-2-partition-borrar-disco--btrfs)).

## Convenciones de los comandos

```bash
DEV=/dev/nvme0n1          # disco de destino ("device")
ESP=${DEV}p1              # /dev/sda1 en SATA (insert_partition_number)
ROOTP=${DEV}p2
MNT=/mnt                  # InstallContext::mountpoint (installer-lib/include/cachyos/types.hpp:137)
OPTS=defaults,noatime,compress=zstd:1   # btrfs en SSD; en HDD: compress=zstd
USER=…  HOSTNAME=…  PASS=…  ROOTPASS=…
```

- **"en el live"**: `/bin/sh -c "<línea>"` en el sistema live
  (`gucc/src/process.cpp:283-285`, `gucc/src/io_utils.cpp:43-45`).
- **"en el target"**: `arch-chroot /mnt /bin/sh -c "<línea>"`
  (`gucc/src/process.cpp:125-127`). A diferencia de un `chroot` plano,
  `arch-chroot` monta y desmonta los sistemas de ficheros de API en cada
  llamada.
- Escrituras de ficheros: NCI las hace desde C++ en el live sobre `$MNT/…`; aquí
  se expresan con `printf`/`cat`.
- Las contraseñas se registran como secretos para enmascararlas en el log
  (`orchestrator.cpp:187-188`), pero **aparecen en la línea de comandos** de los
  procesos (`openssl passwd '…'`).
- Log: `/tmp/cachyos-install.log` en el live; al final se copia a
  `$MNT/cachyos-install.log` (raíz del target).

## Resumen de la secuencia

Fuente: `src/main.cpp:96-155` y `installer-lib/src/orchestrator.cpp:175-439`.
"¿Actúa?": **sí** = hace algo con nuestras opciones; *no-op* = se ejecuta sin
efecto. "Fallo": **aborta** = la instalación se detiene; *aviso* = se registra y
sigue.

| # | Paso | ¿Actúa? | Fallo | Efecto |
|---|---|---|---|---|
| 0 | (preparación en `main`) | sí | aborta* | Red, llavero CachyOS en el live, `pacman -Sy`, validación |
| 1 | `Umount` | sí | aviso | Desmonta lo que haya bajo `/mnt` |
| 2 | `Partition` | sí | aborta | Borra el disco, GPT, ESP FAT32 4 GiB en `/boot`, btrfs + 7 subvolúmenes |
| 3 | `Base` | sí | aborta | `vconsole.conf`, rate-mirrors, `pacstrap`, `pacman.conf`, `mkinitcpio`, `genfstab`, `chwd` |
| 4 | `Fstab` | sí | aborta | Repite `genfstab` |
| 5 | `EncryptSwap` | no-op | aviso | Sin swap |
| 6 | `SystemSettings` | sí | aborta | hostname, hosts, locale, X11 keyboard, keymap del live, zona, hwclock |
| 7 | `Users` | sí | aviso | Contraseña de root, grupos, usuario, sudoers |
| 8 | `MachineId` | sí | aviso | machine-id nuevo y enlace dbus |
| 9 | `Desktop` | no-op | aviso | `desktop` vacío |
| 10 | `DesktopConfigure` | no-op | aviso | (plymouth: no se configura) |
| — | `ServerPackages`, `SshKeys`, `ServerFirewall` | no se ejecutan | — | Solo con `server_profile` |
| 11 | `Autologin` | no-op | aviso | `autologin: false` |
| 12 | `Chwd` | sí | aviso | `chwd -a -f` (segunda vez) |
| 13 | `NetworkCarryover` | sí | aviso | Copia las conexiones de NetworkManager del live |
| 14 | `Bootloader` | sí | aborta | `pacstrap systemd-boot-manager`, `bootctl install`, `sdboot-manage gen` |
| 15 | `DetectCrypto` | no-op | ignorado | Sin LUKS; el resultado no se usa después |
| 16 | `EnableServices` | sí | aviso | `systemctl enable/disable` según `net-profiles.toml`, ufw |
| 17 | `FinalValidation` | sí | aviso | Comprobaciones (solo registra) |
| 18 | `BtrfsSnapshot` | no-op | aviso | Sin `cachyos-snapper-support` |
| 19 | `Cleanup` | sí | aviso | Copia el log y desmonta |
| 20 | `post_install` | no-op | — | Sin script; si lo hubiera, en el live y con el target ya desmontado |

\* Salvo `install_cachyos_repo`, cuyo fallo solo se avisa (`src/main.cpp:115-117`).

---

## Paso 0: preparación en el live

`src/main.cpp:41-136`:

```bash
tty | grep -q '/dev/tty[0-9]*' && setterm -blank 0 -powersave off   # :75-79
# root obligatorio (getuid()==0)

# detect_system (installer-lib/src/system.cpp:34-69), vía utils::id_system()
modprobe -q efivarfs                     # (Apple: modprobe -r -q efivars)
mountpoint -q /sys/firmware/efi/efivars || mount -t efivarfs efivarfs /sys/firmware/efi/efivars
# /sys/firmware/efi/ existe → modo UEFI
systemctl is-active NetworkManager       # solo para elegir nmtui en el TUI

# lee el JSON; con headless_mode=true sigue por aquí
# wait_for_connection(15s) (system.cpp:76-99): GET https://cachyos.org, reintenta 1/s hasta 15 s; sin red → aborta

# install_cachyos_repo (system.cpp:101-113, gucc/src/repos.cpp:108-117)
pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key F3B607488DB35A47
yes | pacman -Sy --noconfirm

# validate_headless_config (installer_config.cpp:514-548): exige device, fs_name,
#   partitions (salvo allow_auto_partition), user_name, user_pass, root_pass y desktop
# installer_config_to_inputs (installer_config.cpp:550-622): vuelve a llamar a
#   detect_system y elige la estrategia: partitions vacío + allow_auto_partition
#   → EraseAndAuto{device} (headless_plan.cpp:167-176)
```

No hay `pacman-key --init/--populate` ni se borra `/etc/pacman.d/gnupg`: se
usa el llavero del live tal cual (lo inicializa `pacman-init.service`) y solo se
importa y firma localmente la clave de CachyOS.

## Paso 1: `Umount`

`orchestrator.cpp:228-237` → `installer-lib/src/disk.cpp:404-419` →
`gucc/src/umount_partitions.cpp:20-52`:

```bash
# swapoff solo si hay swap_device (aquí vacío)
sync
# por cada entrada de /etc/mtab bajo /mnt, de más profunda a menos:
umount -v <punto> || umount -lv <punto>
```

No desmonta ni cierra nada que esté fuera de `/mnt` (particiones del disco
montadas en otra ruta, swaps activas en el disco, mappers LUKS abiertos).

## Paso 2: `Partition` (borrar disco + btrfs)

`installer-lib/src/steps/partition.cpp:169-178` (`EraseAndAuto`).

### Qué decide NCI

- Tabla **GPT** (`gucc/src/partitioning.cpp:140`).
- **ESP**: FAT32, **4 GiB**, montada en **`/boot`** (systemd-boot →
  `installer-lib/src/disk.cpp:57-65`; tamaño en `partitioning.cpp:185`). Tipo
  `U` (EFI System, `C12A7328-F81F-11D2-BA4B-00A0C93EC93B`) y atributo
  `bootable` (`partitioning.cpp:92-99`), que en GPT sfdisk traduce al bit 2
  *LegacyBIOSBootable*.
- **Raíz**: resto del disco, tipo `L` (*Linux filesystem*,
  `0FC63DAF-8483-4772-8E79-3D69D8477DE4`), btrfs. Alineación y comienzo de la
  primera partición: los de sfdisk por defecto (1 MiB).
- Sin swap, sin etiquetas, sin cifrar.
- Opciones de montaje btrfs: `defaults,noatime,compress=zstd:1` si el disco no
  es rotacional (`/sys/block/<disco>/queue/rotational`), `compress=zstd` si lo
  es (`gucc/src/partition_config.cpp:125-131`). ESP:
  `defaults,umask=0077` (`:138-139`).
- Subvolúmenes por defecto (`installer-lib/src/disk.cpp:81-92`):

| Subvolumen | Punto de montaje |
|---|---|
| `/@` | `/` |
| `/@home` | `/home` |
| `/@root` | `/root` |
| `/@srv` | `/srv` |
| `/@cache` | `/var/cache` |
| `/@tmp` | `/var/tmp` |
| `/@log` | `/var/log` |

  `@snapshots` está comentado en el código: no se crea.

### Comandos

```bash
# --- erase_disk (gucc/src/partitioning.cpp:158-176) ---
dd if=/dev/zero of="$DEV" bs=512 count=1
wipefs -af "$DEV"                 # solo el disco, no las particiones
sgdisk -Zo "$DEV"

# --- tabla (gen_sfdisk_command :108-146, run_sfdisk_part :148-156) ---
echo -e 'label: gpt\ntype=U,size=4GiB,bootable\ntype=L\n' | sfdisk -w always "$DEV"
udevadm settle; sync              # settle_devices (gucc/src/io_utils.cpp:71-77)

# --- raíz (installer-lib/src/disk.cpp:505-562) ---
mkfs.btrfs -f "$ROOTP"
udevadm settle; sync
mkdir -p /mnt
mount -t btrfs -o "$OPTS" "$ROOTP" /mnt          # gucc/src/mount_partitions.cpp:21-33
# (consulta lsblk para detectar LUKS/LVM: no hay)

# --- subvolúmenes (gucc/src/btrfs.cpp:53-113) ---
for sv in @ @home @root @srv @cache @tmp @log; do btrfs subvolume create /mnt/$sv; done
umount -v /mnt
mount -o "subvol=/@,$OPTS"      "$ROOTP" /mnt/
mkdir -p /mnt/home      && mount -o "subvol=/@home,$OPTS"  "$ROOTP" /mnt/home
mkdir -p /mnt/root      && mount -o "subvol=/@root,$OPTS"  "$ROOTP" /mnt/root
mkdir -p /mnt/srv       && mount -o "subvol=/@srv,$OPTS"   "$ROOTP" /mnt/srv
mkdir -p /mnt/var/cache && mount -o "subvol=/@cache,$OPTS" "$ROOTP" /mnt/var/cache
mkdir -p /mnt/var/tmp   && mount -o "subvol=/@tmp,$OPTS"   "$ROOTP" /mnt/var/tmp
mkdir -p /mnt/var/log   && mount -o "subvol=/@log,$OPTS"   "$ROOTP" /mnt/var/log

# --- ESP (gucc/src/mount_partitions.cpp:59-100) ---
mkfs.vfat -F32 "$ESP"
udevadm settle; sync
mkdir -p /mnt/boot
mount -t vfat -o defaults,umask=0077 "$ESP" /mnt/boot
```

### Variante `CreateLayout` (particiones en el JSON)

Si se declaran `partitions` (como hace hoy `settings.jsonc`) los comandos son
los mismos con dos diferencias: el tamaño de la ESP sale del JSON (`"2G"` →
`size=2G`) y se valida el esquema antes de tocar el disco
(`installer-lib/src/headless_plan.cpp:178-229`). Los subvolúmenes son los
mismos si `subvolumes` es `"default"`.

## Paso 3: `Base`

`installer-lib/src/packages.cpp:118-164` → `gucc/src/install.cpp:68-170`.

### 3a. Teclado de consola

`gucc/src/install.cpp:88-92`, `gucc/src/locale.cpp:134-143`. `ctx.keymap` es
el valor de `xkbmap` (`installer_config.cpp:598-600`):

```bash
mkdir -p /mnt/etc
printf 'KEYMAP=es\n' > /mnt/etc/vconsole.conf
```

Se escribe **antes** de `pacstrap` para que el hook `sd-vconsole` lo incluya en
el initramfs. Solo `KEYMAP`; sin `FONT`.

### 3b. Mirrors (en el live)

`gucc/src/mirrors.cpp:8-23`:

```bash
/usr/bin/pacman -Sy --noconfirm --needed cachyos-rate-mirrors rate-mirrors   # fallo → aviso
/usr/bin/cachyos-rate-mirrors                                                # fallo → aborta
```

`cachyos-rate-mirrors` reescribe los mirrorlists **del live**
(`/etc/pacman.d/mirrorlist` y los `cachyos-*mirrorlist`).

### 3c. `pacman.conf` temporal con los repos optimizados

`gucc/src/repos.cpp:76-102`, `:119-127`; inserción en
`gucc/src/pacmanconf_repo.cpp:14-44`:

```bash
cp /etc/pacman.conf /tmp/cachyos-installer-pacman.conf
# [cachyos] ya está en el pacman.conf del live → no se añade
systemd-detect-virt | grep -q oracle && { : ; }   # VirtualBox: no añade repos por ISA
# añade UNO de estos bloques delante de la primera sección de repo (tras [options]),
# según gucc::cpu::get_isa_levels():
#   znver4          → [cachyos-znver4] [cachyos-core-znver4] [cachyos-extra-znver4]  (cachyos-v4-mirrorlist)
#   x86_64_v4       → [cachyos-v4] [cachyos-core-v4] [cachyos-extra-v4]              (cachyos-v4-mirrorlist)
#   x86_64_v3       → [cachyos-v3] [cachyos-core-v3] [cachyos-extra-v3]              (cachyos-v3-mirrorlist)
```

Los bloques solo llevan `Include =`: sin `SigLevel` propio.

### 3d. `pacstrap`

`gucc/src/io_utils.cpp:59-70`:

```bash
pacstrap -c -C /tmp/cachyos-installer-pacman.conf /mnt <paquetes>
```

- `-c`: usa la caché de paquetes del live (`hostcache: true`).
- Sin `-G` ni `-M`: pacstrap copia al target el **llavero** del live
  (`/etc/pacman.d/gnupg`, con la clave de CachyOS firmada en el Paso 0) y el
  **`/etc/pacman.d/mirrorlist`** (ya ordenado). Los `cachyos-*mirrorlist` del
  target son los del paquete, sin ordenar.
- `pacstrap` monta los sistemas de ficheros de API en `/mnt` mientras dura.

Lista de paquetes (`gucc/src/package_list.cpp:116-170`), en este orden:

1. `linux-cachyos`, `linux-cachyos-headers` (cada kernel de `kernel` más
   `-headers`).
2. Por ser raíz btrfs y no servidor: `snapper`, `btrfs-assistant-git`.
3. `[base-packages.desktop]` de `net-profiles.toml` (líneas 62-193), porque no
   es servidor, **aunque no haya escritorio**.
4. `[base-packages]` (líneas 1-60).
5. Microcódigo según el fabricante de la CPU: `intel-ucode` o `amd-ucode`.

`[base-packages]`:

```
base base-devel btrfs-progs cachyos-hooks cachyos-keyring cachyos-mirrorlist
cachyos-v4-mirrorlist cachyos-v3-mirrorlist cachyos-rate-mirrors cachyos-settings
cryptsetup device-mapper diffutils dosfstools e2fsprogs efibootmgr exfatprogs
f2fs-tools inetutils iptables-nft jfsutils less linux-firmware logrotate lsb-release
lvm2 man-db man-pages mdadm chwd mkinitcpio netctl perl python s-nail sudo sysfsutils
texinfo usbutils which xfsprogs networkmanager btop duf rsync wget ripgrep micro nano
vim openssh
```

`[base-packages.desktop]`:

```
plymouth cachyos-plymouth-bootanimation cachyos-fish-config cachyos-zsh-config
cachyos-hello cachyos-kernel-manager cachyos-packageinstaller cachyos-settings
cachyos-micro-settings cachyos-wallpapers dnsmasq dnsutils ethtool iwd modemmanager
networkmanager networkmanager-openvpn nss-mdns usb_modeswitch wpa_supplicant
wireless-regdb xl2tpd ufw bluez bluez-hid2hci bluez-libs bluez-utils bluez-obex
pacman-contrib pkgfile rebuild-detector reflector paru octopi accountsservice
bash-completion ffmpegthumbnailer gst-libav gst-plugin-pipewire gst-plugins-bad
gst-plugins-ugly libdvdcss libgsf libopenraw plocate poppler-glib vlc-plugins-all
xdg-user-dirs xdg-utils efitools nfs-utils nilfs-utils smartmontools unrar unzip
awesome-terminal-fonts noto-fonts-emoji cantarell-fonts noto-fonts ttf-bitstream-vera
ttf-dejavu ttf-liberation ttf-opensans ttf-meslo-nerd noto-fonts-cjk alsa-firmware
alsa-plugins alsa-utils pavucontrol pipewire-pulse wireplumber pipewire-alsa
dmidecode dmraid hdparm hwdetect linux-firmware lsscsi mesa-utils mtools sg3_utils
sof-firmware cpupower power-profiles-daemon upower firefox alacritty btop duf
fsarchiver git glances hwinfo meld nano-syntax-highlighting fastfetch pv
python-defusedxml python-packaging rsync wget ripgrep micro nano vim openssh
```

Comprobado el 2026-11-15 contra las bases de datos de pacman de un CachyOS
actual: todos los nombres resuelven; `dnsutils` e `iptables-nft` lo hacen por
*provides* (`bind`, `iptables`). Un nombre inexistente haría fallar el
`pacstrap` completo.

### 3e. Copia de `pacman.conf`

`installer-lib/src/packages.cpp:151`, `gucc/src/install.cpp:107-115`:

```bash
cp /etc/pacman.conf /mnt/etc/pacman.conf    # el del LIVE, no el temporal de 3c
```

El target se queda con el `pacman.conf` del live
(`iso:archiso/airootfs/etc/pacman.conf`): `[cachyos]` con
`SigLevel = Optional TrustAll`, `[core]`, `[extra]`, `[multilib]`, y **sin los
repos `-v3`/`-v4`/`-znver4`** con los que se acaba de instalar. Ver
[Hallazgos](#hallazgos-y-peculiaridades).

### 3f. `mkinitcpio`

`gucc/src/initcpio.cpp:103-191`, llamado con `use_systemd_hook = true`,
`is_luks = false`, sin plymouth (`installer-lib/src/packages.cpp:142-148`).
Reescribe las líneas que empiezan por `MODULES`, `FILES` y `HOOKS` de
`/mnt/etc/mkinitcpio.conf` (`MODULES` y `FILES` con su valor actual):

```bash
sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode kms modconf block keyboard sd-vconsole filesystems)/' /mnt/etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -P
```

Sin `fsck` (btrfs), sin `btrfs` (un solo dispositivo), sin `plymouth`. No toca
`/etc/mkinitcpio.conf.d/`.

### 3g. `fstab`

`gucc/src/fstab.cpp:127-159`:

```bash
genfstab -U -p /mnt > /mnt/etc/fstab
sed -i 's/subvolid=.*,subvol=\/.*,//g' /mnt/etc/fstab
# (borra líneas de datasets ZFS: no aplica)
```

### 3h. `chwd` (siempre)

`gucc/src/install.cpp:141-144`, `gucc/src/chwd.cpp:35-40`:

```bash
arch-chroot /mnt chwd -a -f      # fallo → aborta la instalación
```

Se ejecuta **siempre**, independientemente de la opción `chwd`.

Al terminar, `installer-lib/src/packages.cpp:159-161` crea el marcador
`/mnt/.base_installed`, que **no se borra nunca** (queda en la raíz del sistema
instalado).

## Paso 4: `Fstab`

`installer-lib/src/steps/fstab.cpp:6-8` → `installer-lib/src/disk.cpp:421-428`:
repite exactamente [3g](#3g-fstab) y sobrescribe el `fstab`.

## Paso 5: `EncryptSwap` (no-op)

`installer-lib/src/steps/encrypt_swap.cpp:12-14`: `encrypt_swap` falso y sin
swap.

## Paso 6: `SystemSettings`

`installer-lib/src/config.cpp:50-101`:

```bash
# hostname y hosts (gucc/src/user.cpp:125-162)
printf '%s\n' "$HOSTNAME" > /mnt/etc/hostname
cat > /mnt/etc/hosts <<EOF
# Standard host addresses
127.0.0.1  localhost
::1        localhost ip6-localhost ip6-loopback
ff02::1    ip6-allnodes
ff02::2    ip6-allrouters
# This host address
127.0.1.1  $HOSTNAME
EOF

# locale (gucc/src/locale.cpp:19-62)
cat > /mnt/etc/locale.conf <<'EOF'
LANG="es_ES.UTF-8"
LC_NUMERIC="es_ES.UTF-8"
LC_TIME="es_ES.UTF-8"
LC_MONETARY="es_ES.UTF-8"
LC_PAPER="es_ES.UTF-8"
LC_NAME="es_ES.UTF-8"
LC_ADDRESS="es_ES.UTF-8"
LC_TELEPHONE="es_ES.UTF-8"
LC_MEASUREMENT="es_ES.UTF-8"
LC_IDENTIFICATION="es_ES.UTF-8"
LC_MESSAGES="es_ES.UTF-8"
EOF
sed -i "s/#es_ES.UTF-8/es_ES.UTF-8/" /mnt/etc/locale.gen   # en el live, sobre el fichero del target
arch-chroot /mnt locale-gen

# teclado X11 (gucc/src/locale.cpp:97-123)
mkdir -p /mnt/etc/X11/xorg.conf.d
cat > /mnt/etc/X11/xorg.conf.d/00-keyboard.conf <<'EOF'
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "es"
EndSection
EOF

# teclado del LIVE (config.cpp:76-83; fallo → aviso)
localectl set-keymap es

# zona horaria (gucc/src/timezone.cpp:47-72): enlace absoluto
rm -f /mnt/etc/localtime
ln -s /usr/share/zoneinfo/Europe/Madrid /mnt/etc/localtime

# reloj (gucc/src/hwclock.cpp:13-29), solo porque hw_clock está definido
arch-chroot /mnt hwclock --systohc --utc || arch-chroot /mnt hwclock --systohc --utc --directisa
```

Lo que **no** hace: `/etc/vconsole.conf` ya quedó con `KEYMAP=es` en
[3a](#3a-teclado-de-consola) y no se toca; no escribe `XkbModel`/`XkbVariant`,
`/etc/default/keyboard`, `/etc/default/locale` ni `/etc/timezone`; el
`sed` de `locale.gen` también descomentaría cualquier otra línea que contenga
`#es_ES.UTF-8` (no la hay en el `locale.gen` estándar).

## Paso 7: `Users`

`installer-lib/src/steps/users.cpp:9-24`, `installer-lib/src/config.cpp:103-143`,
`gucc/src/user.cpp:22-123`:

```bash
# contraseña de root (set_user_password, :35-44)
H=$(openssl passwd "$ROOTPASS")          # en el live; OpenSSL 3+: MD5-crypt ($1$…)
arch-chroot /mnt usermod -p "$H" root

# shell: solo con zsh/fish instala cachyos-{zsh,fish}-config (aquí bash → nada)

# grupos (create_group, :22-33)
for g in wheel rfkill sys users lp video network storage audio; do
    arch-chroot /mnt groupadd --force "$g"
done
arch-chroot /mnt useradd -m -U -s /bin/bash "$USER"
arch-chroot /mnt usermod -aG wheel,rfkill,sys,users,lp,video,network,storage,audio "$USER"
arch-chroot /mnt chown -R "$USER:$USER" "/home/$USER"
H=$(openssl passwd "$PASS")
arch-chroot /mnt usermod -p "$H" "$USER"

# sudoers (:105-121)
printf '%%wheel ALL=(ALL) ALL\n' > /mnt/etc/sudoers.d/10-installer
chmod 0440 /mnt/etc/sudoers.d/10-installer
```

Los fallos de este paso son solo avisos: la instalación sigue aunque no se cree
el usuario.

## Paso 8: `MachineId`

`gucc/src/machine_id.cpp:53-67`:

```bash
rm -f /mnt/etc/machine-id /mnt/var/lib/dbus/machine-id
systemd-machine-id-setup --root=/mnt         # en el live
mkdir -p /mnt/var/lib/dbus
ln -s /etc/machine-id /mnt/var/lib/dbus/machine-id
```

No toca `/var/lib/systemd/random-seed`.

## Paso 9-10: `Desktop` y `DesktopConfigure` (no-op)

`installer-lib/src/steps/desktop.cpp:10-12`,
`installer-lib/src/steps/desktop_configure.cpp:10-12`: salen sin hacer nada si
`desktop` está vacío. Consecuencia: `configure_desktop_extras`
(`installer-lib/src/packages.cpp:187-220`) **no se ejecuta**, así que aunque
`plymouth` y `cachyos-plymouth-bootanimation` están instalados (3d), no se fija
el tema (`plymouth-set-default-theme cachyos-bootanimation`) ni se añade el hook
`plymouth` a `mkinitcpio.conf`.

Alternativa sin escritorio: `server_profile: "minimal"` (modo servidor). Cambia
mucho el resultado: no instala `[base-packages.desktop]` ni
`snapper`/`btrfs-assistant-git`, activa `sshd`, exige `ssh_authorized_keys`,
instala paquetes del perfil y configura ufw con reglas propias. No se audita.

## Paso 11: `Autologin` (no-op)

`installer-lib/src/steps/autologin.cpp:15-17`: `autologin` falso.

## Paso 12: `Chwd`

`installer-lib/src/steps/chwd.cpp:10-19`, con `chwd: true` (por defecto):

```bash
arch-chroot /mnt chwd -a -f      # segunda vez; fallo → aviso
```

## Paso 13: `NetworkCarryover`

`installer-lib/src/steps/network_carryover.cpp:18-24`,
`gucc/src/network.cpp:156-193`:

```bash
mkdir -p /mnt/etc/NetworkManager/system-connections
for f in /etc/NetworkManager/system-connections/*.nmconnection; do
    cp -f "$f" /mnt/etc/NetworkManager/system-connections/
    chmod 600 "/mnt/etc/NetworkManager/system-connections/${f##*/}"
done
```

Copia tal cual (sin reescribir `permissions=` ni otros campos).

## Paso 14: `Bootloader` (systemd-boot)

`installer-lib/src/bootloader.cpp:130-155`, `:366-389`;
`gucc/src/bootloader.cpp:223-254`:

```bash
mountpoint -q /sys/firmware/efi/efivars || mount -t efivarfs efivarfs /sys/firmware/efi/efivars

pacstrap -c -C /mnt/etc/pacman.conf /mnt systemd-boot-manager   # con el pacman.conf del target (3e)

# is_volume_removable: lsblk, campo "rm" del disco → falso en un NVMe/SATA interno
arch-chroot /mnt bootctl --path=/boot install
arch-chroot /mnt sdboot-manage gen
# si el disco fuera extraíble: quita "autodetect" de HOOKS (sin regenerar el initramfs)
```

NCI **no calcula la línea de comandos del kernel** para systemd-boot ni escribe
`/etc/kernel/cmdline` ni `loader.conf` (el que crea `bootctl install` queda
como esté). Todo lo hace `sdboot-manage gen`
(`pkgbuilds:systemd-boot-manager/sdboot-manage:277-371`, configuración
`sdboot-manage.conf` con `LINUX_OPTIONS="nowatchdog quiet splash"`):

- Sin `/etc/kernel/cmdline`, la cmdline sale de `generate_cmdline`
  (`sdboot-manage:181-229`), con `findmnt` sobre `/` dentro del chroot:
  `root=UUID=<uuid-btrfs> rw rootflags=subvol=/@` + `LINUX_OPTIONS`.
- Genera una entrada por kernel a partir de `/boot/vmlinuz-*` y
  `/boot/initramfs-*.img` (los del Paso 3f):

```
# /boot/loader/entries/linux-cachyos.conf
title Linux CachyOS
options root=UUID=<uuid-btrfs> rw rootflags=subvol=/@ nowatchdog quiet splash
linux /vmlinuz-linux-cachyos
initrd /initramfs-linux-cachyos.img
```

El microcódigo va dentro del initramfs (hook `microcode`). `splash` aparece en
la cmdline aunque el initramfs no lleve el hook `plymouth`.

## Paso 15: `DetectCrypto` (no-op)

`installer-lib/src/steps/detect_crypto.cpp:10-22`, `installer-lib/src/crypto.cpp:22-50`:
consulta `lsblk` y guarda el estado LUKS en el contexto. Sin LUKS no cambia
nada. El orquestador ignora el resultado y ningún paso posterior lo usa (el
comentario dice "for kernel-params use", pero el bootloader ya se instaló).

## Paso 16: `EnableServices`

`installer-lib/src/packages.cpp:260-306`, lista de `net-profiles.toml`
(`[services]` líneas 195-207 y `[services.desktop]` 209-224). Cada unidad se
activa solo si existe `/mnt/usr/lib/systemd/system/<unidad>` (se añade
`.service` si no lleva punto); si no existe, se salta en silencio
(`:46-76`). Comando en el target: `systemctl enable|disable <unidad>` o
`systemctl --global enable <unidad>` para las de usuario
(`gucc/src/systemd_services.cpp:16-38`).

| Unidad | Acción | ¿Existe con nuestras opciones? |
|---|---|---|
| `NetworkManager` | enable (urgente) | sí |
| `fstrim.timer` | enable | sí (util-linux) |
| `systemd-timesyncd` | enable | sí |
| `sshd` | — | se quita de la lista en modo escritorio (`gucc/src/package_list.cpp:229-235`) |
| `apparmor` | enable | solo si lo instala alguna dependencia (no está en la lista) |
| `haveged` | enable | ídem |
| `cronie` | enable | ídem |
| `pacman-init` | disable | no existe en el target |
| `bluetooth` | enable | sí (`bluez`) |
| `cups` | enable | no (no se instala) |
| `avahi-daemon` | enable | sí (dependencia de `nss-mdns`) |
| `ModemManager` | enable | sí (`modemmanager`) |
| `tlp` | enable | no |
| `ufw` | enable | sí |
| `firewalld` | enable | no |
| `vboxservice`, `vmtoolsd`, `vmware-vmblock-fuse` | enable | solo si `chwd` los instaló (VM) |
| `arch-update.timer`, `arch-update-tray.service` | `--global` enable | no (no se instala `arch-update`) |

Después (`:282-303`):

```bash
# display manager: busca unidades de DM en el target → ninguna → no hace nada
# ufw instalado (gucc/src/firewall.cpp:69-86); kdeconnect no está → sin regla extra
arch-chroot /mnt systemctl enable ufw
arch-chroot /mnt ufw default deny incoming
arch-chroot /mnt ufw default allow outgoing
arch-chroot /mnt ufw enable
```

Otras unidades activas en el sistema instalado (p. ej. las de
`cachyos-settings`) las activan los scriptlets de los paquetes, no NCI.

## Paso 17: `FinalValidation`

`installer-lib/src/validation.cpp:72-115`. Solo registra avisos; no aborta:

```bash
test -e /mnt/.base_installed
test -e /mnt/boot/loader/loader.conf     # bootloader_installed() para systemd-boot (:35-38)
grep -qv '^#' /mnt/etc/fstab
arch-chroot /mnt locale -a | wc -l          # >= 3
arch-chroot /mnt passwd --status root | cut -d' ' -f2 | grep -q NP   # no debe ser NP
test -e /mnt/home
```

## Paso 18: `BtrfsSnapshot` (no-op)

`gucc/src/btrfs.cpp:161-191`:

```bash
arch-chroot /mnt pacman -Qs cachyos-snapper-support   # no instalado → sale
```

Con ese paquete crearía `snapper --no-dbus -c root create … 'Fresh CachyOS
Installation'` y guardaría el número en `/etc/cachyos/installation-snapshot`.
`snapper` sí está instalado (3d), pero sin configuración `root`.

## Paso 19: `Cleanup`

`installer-lib/src/steps/cleanup.cpp:17-35`:

```bash
cp -f /tmp/cachyos-install.log /mnt/cachyos-install.log
sync
# umount -v (o -lv) de cada punto bajo /mnt, de más profundo a menos (como el Paso 1)
```

No cierra mappers ni apaga el equipo.

## Paso 20: `post_install`

`src/main.cpp:141-144`: solo si la instalación tuvo éxito y hay
`post_install`. Se ejecuta **en el live**, con el target ya desmontado:
`/bin/sh -c "<script> &>>/tmp/cachyos-install.log"`; su fallo no cambia el
código de salida.

---

## Estado final esperado del target (resumen)

| Elemento | Valor |
|---|---|
| Particiones | `p1` ESP 4 GiB FAT32 (`C12A7328…`, atributo LegacyBIOSBootable), `p2` btrfs (`0FC63DAF…`) |
| Subvolúmenes | `@ @home @root @srv @cache @tmp @log` (sin `@snapshots`) |
| Montaje btrfs | `noatime,compress=zstd:1` (SSD) |
| `fstab` | `genfstab -U -p`; ESP en `/boot` con `umask=0077` |
| Kernel | `linux-cachyos` (+ headers); un solo kernel |
| initramfs | `HOOKS=(base systemd autodetect microcode kms modconf block keyboard sd-vconsole filesystems)` |
| Bootloader | systemd-boot (`bootctl install`) + `systemd-boot-manager`; entrada `linux-cachyos.conf` |
| cmdline | `root=UUID=… rw rootflags=subvol=/@ nowatchdog quiet splash` |
| Locale | `es_ES.UTF-8` en `LANG` y 10 `LC_*` (sin `LC_CTYPE`/`LC_COLLATE`) |
| Teclado | `vconsole.conf`: `KEYMAP=es`; X11: `XkbLayout es` sin modelo |
| Zona | `/etc/localtime` → `/usr/share/zoneinfo/Europe/Madrid`; RTC en UTC |
| Usuario | bash, grupos `wheel rfkill sys users lp video network storage audio`; root con contraseña propia |
| Hashes | MD5-crypt (`$1$`) vía `openssl passwd` |
| sudo | `/etc/sudoers.d/10-installer`: `%wheel ALL=(ALL) ALL` |
| `pacman.conf` | el del live: solo `[cachyos]` genérico, `SigLevel = Optional TrustAll` |
| Servicios | `NetworkManager`, `fstrim.timer`, `systemd-timesyncd`, `bluetooth`, `avahi-daemon`, `ModemManager`, `ufw` (+ los que existan de la lista) |
| Firewall | ufw activo: deny incoming, allow outgoing |
| Restos | `/.base_installed`, `/cachyos-install.log` |
| Plymouth | instalado, sin tema fijado ni hook |
| Snapper | instalado, sin configurar |

---

## Cifrado en `0.12.4`: el camino del modo avanzado

Único camino con LUKS en `0.12.4`. Es interactivo y manual; se resume lo que
cambia respecto al camino principal.

### Secuencia de menús

`src/tui.cpp:2480-2551` (*Prepare Installation*) y `:2327-2404`
(*Install System*):

1. *Select Bootloader* → systemd-boot.
2. *Partition Disk* → herramienta interactiva (`cfdisk`…): ESP y partición raíz
   a mano.
3. *LUKS Encryption* → *Automatic LUKS Encryption* (o *Express* / *Define
   Key-Size and Cypher*).
4. *Mount Partitions* → formatear el mapper con btrfs, subvolúmenes, montar ESP
   en `/boot`.
5. *Install Base Packages* → `steps::base` + `steps::enable_services`
   (`src/utils.cpp:501-539`).
6. *Install Bootloader* → `steps::bootloader` (`src/utils.cpp:648-686`).
7. *Configure Base* → fstab, hostname, locale, teclado X11, zona y reloj,
   contraseña de root, usuarios (`src/tui.cpp:706-757`).

El modo avanzado **no ejecuta** `MachineId`, `NetworkCarryover`, `Chwd` (más
allá del de `Base`), `FinalValidation` ni `BtrfsSnapshot`.

### Comandos de cifrado

`src/crypto.cpp:127-197`, `gucc/src/luks.cpp:73-81`:

```bash
modprobe -a dm-mod dm_crypt
# (desmonta, lista particiones; el usuario elige partición, nombre del mapper y contraseña)

# Automatic:   FLAGS=""
# Express:     FLAGS="--pbkdf-force-iterations 200000"
# Define…:     FLAGS="-s 512 -c aes-xts-plain64" (editable)
echo "$LUKSPASS" | cryptsetup -q $FLAGS --type luks1 luksFormat "$ROOTP"
echo "$LUKSPASS" | cryptsetup open --type luks1 "$ROOTP" "$MAPPER"
```

Siempre **LUKS1** (los valores por defecto de `cryptsetup` para LUKS1). Sin
TPM, sin keyfile (con `/boot` sin cifrar, `boot_encrypted_setting` no crea
`crypto_keyfile.bin`).

### Efecto en los pasos posteriores

- *Mount Partitions* detecta el mapper (`gucc/src/mount_partitions.cpp:35-57`)
  y guarda `LUKS=1`, nombre, UUID y `cryptdevice=UUID=…:<mapper>`.
- *Install Base* llama antes a `recheck_luks()`, así que `is_luks = true` y
  `mkinitcpio.conf` queda con
  `HOOKS=(base systemd keyboard autodetect microcode kms modconf block sd-vconsole sd-encrypt filesystems)`
  (`gucc/src/initcpio.cpp:127-128`, `:148-153`).
- `genfstab -U` escribe el UUID del btrfs del mapper.
- *Install Bootloader*: `sdboot-manage gen` encuentra el dispositivo `crypt`
  bajo `/` y, como `HOOKS` contiene `sd-encrypt`, añade
  `rd.luks.name=<uuid-luks>=<mapper>` (`sdboot-manage:206-226`).
- No se escribe `/etc/crypttab` ni `/etc/crypttab.initramfs`: el desbloqueo
  depende solo de `rd.luks.name=` en la cmdline.

---

## Diferencias relevantes con `master`

Solo lo que afecta a este camino. `master` (`47730e4`) no está empaquetado.

- **Cifrado headless**: nueva clave `luks_passphrase`
  (`master:installer-lib/src/installer_config.cpp:70`, `:308`; commit `992b9d0`).
  Con `CreateLayout`, tras particionar formatea la raíz con **LUKS2** y la abre
  como `/dev/mapper/<kLuksRootMapper>` antes del `mkfs`
  (`master:installer-lib/src/steps/partition.cpp:110-123`;
  `master:installer-lib/include/cachyos/partition_planner.hpp:157`). Nuevo paso
  `luks_keyfile` que solo embebe `crypto_keyfile.bin` si `/boot` está cifrado
  (`master:installer-lib/src/steps/luks_keyfile.cpp:20-34`).
- **Orquestador reorganizado**: nuevos pasos `luks_keyfile`, `initramfs` (antes
  del bootloader), `restore_initramfs_hook` y `post_install`
  (`master:installer-lib/src/orchestrator.cpp:186-247`); en `gucc/src/install.cpp`
  se instala un hook que difiere `mkinitcpio` durante `pacstrap`
  (`install_deferral_hook`, commits `7d8603f`, `6250309`).
- **systemd-boot**: crea `/etc/kernel/cmdline` por defecto (`77ba090`) y usa
  `rd.luks.uuid=` (`403d49f`, `89ffd89`).
- **Teclado de consola**: opción propia `keymap` (`03fa440`).
- **Hook `kms`** eliminado de `HOOKS` (`0a58bf2`).
- **Tipo de la partición raíz**: `SD_GPT_ROOT_X86_64`
  (`4f68bce3-e8cd-4db1-96e7-fbcaf984b709`) en UEFI en lugar de `L` (`47730e4`).

---

## Hallazgos y peculiaridades

1. **Sin cifrado en headless** con la versión empaquetada; solo LUKS1 manual en
   el modo avanzado.
2. **La lista de paquetes y servicios viene de GitHub `master` en tiempo de
   ejecución** (`net-profiles.toml`), no del tag instalado.
3. **`pacman.conf` del target sin repos optimizados**: se instala con
   `-v3`/`-v4`/`-znver4` (3c) pero se copia el `pacman.conf` del live (3e). Las
   actualizaciones posteriores saldrían de `[cachyos]`/`[core]`/`[extra]`
   genéricos. A confirmar en VM.
4. **`chwd -a -f` se ejecuta dos veces**, y la primera (dentro de `Base`) es
   incondicional: `"chwd": false` no la evita.
5. **`genfstab` dos veces** (3g y Paso 4) y **`mkinitcpio -P` una sola vez**,
   antes de instalar `systemd-boot-manager`.
6. **Contraseñas con MD5-crypt** (`openssl passwd` sin algoritmo; en OpenSSL 3+
   el predeterminado es `$1$`, comprobado con OpenSSL 4.1.0) y pasadas en la línea
   de comandos (`openssl passwd '<pass>'`, `echo '<pass>' | cryptsetup`).
   Una comilla simple en la contraseña rompe el comando.
7. **"Sin escritorio" no es mínimo**: en modo escritorio con `desktop: ""` se
   instala todo `[base-packages.desktop]` (Firefox, fuentes, PipeWire, Bluetooth,
   octopi, alacritty…), más `snapper` y `btrfs-assistant-git`.
8. **Plymouth a medias**: instalado y con `splash` en la cmdline, pero sin hook
   en el initramfs ni tema fijado (porque `DesktopConfigure` no corre sin
   escritorio).
9. **`vconsole.conf` sí se escribe** en `0.12.4` (`KEYMAP=<xkbmap>`, 3a). Solo
   `KEYMAP`; sin `FONT`. Corrige la nota anterior de que en headless no se
   configuraba.
10. **Teclado X11 sin modelo ni variante** (`XkbLayout` únicamente).
11. **`hw_clock` opcional**: si se omite, no se ejecuta `hwclock`.
12. **ESP con atributo GPT LegacyBIOSBootable** por el `bootable` de sfdisk.
13. **Restos en el target**: `/.base_installed` y `/cachyos-install.log`.
14. **`loader.conf`** queda como lo deje `bootctl install`; NCI no fija
    `timeout` ni `default`.
15. **`Umount` previo limitado a `/mnt`**: si el disco tiene particiones
    montadas en otro sitio, swap activa o LUKS abierto, `wipefs`/`sfdisk`
    pueden fallar.
16. **`DetectCrypto` no sirve para nada** en el orquestador de `0.12.4` (se
    ejecuta después del bootloader y nadie usa el resultado).
17. Se activa `ufw` con `ufw enable` dentro del chroot.

## Pendiente de verificar en VM

- `pacman.conf` final del target y origen de los paquetes instalados
  (`pacman -Qi … | grep Repo`, `/etc/pacman.conf`).
- `fstab` real: si `genfstab` deja `subvolid=` (el `sed` de NCI solo actúa si
  `subvol=` va seguido de coma).
- Contenido de `/boot/loader/loader.conf` tras `bootctl install`.
- Entradas de `/boot/loader/entries/` y cmdline efectiva (`/proc/cmdline`).
- Unidades realmente activadas (`systemctl list-unit-files --state=enabled`),
  incluidas `apparmor`, `haveged`, `cronie`.
- Que `ufw enable` funciona dentro de `arch-chroot`.
- Hash de `/etc/shadow` (`$1$`).
- Con `systemd-boot-manager` 21-1 (el que sirve hoy el repo), que la cmdline
  generada coincide con la de la versión 24 auditada.
