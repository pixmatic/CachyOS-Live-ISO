# Auditoría de New-Cli-Installer: instalación base sin escritorio

Fase 2, segunda parte. Secuencia exacta de lo que hace `cachyos-installer`
(New-Cli-Installer, en adelante NCI) con las opciones fijas de este proyecto,
traducida a comandos de consola de bajo nivel para poder replicarla.

Este documento **no compara** con Calamares
([auditoria-calamares-base.md](auditoria-calamares-base.md)); la comparación
está en [comparacion-base-resultante.md](comparacion-base-resultante.md).

> **Revisión 2026-11-16**: rehecha contra el tag **`0.13.0`**, el que empaqueta
> ahora `cachyos-cli-installer-new` (ver
> [impacto-upstream-26.11.md](impacto-upstream-26.11.md)). La versión anterior,
> contra `0.12.4`, está en el historial de git (commit `635d754`). Lo que
> cambia respecto a ella está resumido en
> [Cambios respecto a `0.12.4`](#cambios-respecto-a-0124).

## Versiones auditadas

| Componente | Repo | Rama/tag | Commit | Nota |
|---|---|---|---|---|
| NCI | `CachyOS/New-Cli-Installer` | **tag `0.13.0`** | `30401a3` (2026-11-15) | Lo que compila `cachyos-cli-installer-new` 0.13.0-1. El repo `cachyos` aún sirve `0.12.4-1` (2026-11-16). |
| PKGBUILDs | `CachyOS/CachyOS-PKGBUILDS` | `master` | `a7b3058` (2026-11-15) | `cachyos-cli-installer-new/` (pkgver 0.13.0), `systemd-boot-manager/` (pkgver 24; el repo `cachyos` sirve aún `21-1`). |
| ISO | `CachyOS/CachyOS-Live-ISO` | `master` | `b0ebcae` (2026-11-15) | `/etc/pacman.conf` del live, base del `pacman.conf` del target. |

Rutas citadas:

- Sin prefijo: relativas a New-Cli-Installer en el tag `0.13.0`.
- `pkgbuilds:`: relativas a `CachyOS-PKGBUILDS/`.
- `iso:`: relativas a este repo (`archiso/…`).

El PKGBUILD (`pkgbuilds:cachyos-cli-installer-new/PKGBUILD`) compila el tag
firmado con `-DENABLE_DEVENV=OFF` (modo real) y lo divide en dos paquetes:
`cachyos-installer-libs` (`libgucc.so`, `libcachyos-installer-lib.so`;
dependencias `curl openssl fmt gawk chwd cachyos-rate-mirrors coreutils
util-linux gptfdisk cryptsetup`) y `cachyos-cli-installer-new` (binario,
`fzf`, y copias de respaldo de `net-profiles.toml` y `server-profiles.toml` en
`/var/lib/cachyos-installer/`). Calamares `cachyos-staging` usa también
`cachyos-installer-libs`.

> **Aviso: la lista de paquetes y servicios se descarga en ejecución.**
> `net-profiles.toml` se baja de
> `https://raw.githubusercontent.com/CachyOS/New-Cli-Installer/master/net-profiles.toml`
> y solo si falla se usa `file:///var/lib/cachyos-installer/net-profiles.toml`
> (`installer-lib/include/cachyos/types.hpp:26-27`,
> `gucc/src/package_list.cpp:58-98`). Es la lista de `master` en GitHub, no la
> del tag. Hoy es idéntica en `0.12.4`, `0.13.0` y `master`.

## Alcance: opciones fijas

Solo se sigue el camino que corresponde a estas opciones. El resto de ramas
(GRUB, Limine, rEFInd, ZFS, BIOS, swap, LVM, escritorios, servidor, modo TUI)
se ignoran salvo cuando cambian algo de este camino.

| Opción | Valor | Cómo se expresa en NCI |
|---|---|---|
| Idioma, números y fechas | `es_ES.UTF-8` | `"locale": "es_ES.UTF-8"` (un único locale para `LANG` y las `LC_*`) |
| Zona | `Europe/Madrid` | `"timezone": "Europe/Madrid"` |
| Teclado | modelo `pc105`, distribución `es`, variante por defecto | `"xkbmap": "es"` (consola: `console_keymap`, por defecto igual a `xkbmap`). **Sin opción de modelo ni de variante**. |
| Firmware | UEFI exclusivo (sin CSM), TPM 2.0 | autodetectado (`/sys/firmware/efi/`). NCI no usa el TPM. |
| Bootloader | `systemd-boot` | `"bootloader": "systemd-boot"` |
| Disco | el de la configuración, **borrar disco**, btrfs | `"device"`, `"fs_name": "btrfs"`, `"allow_auto_partition": true` y **sin** `partitions` |
| Cifrado | "Cifrar sistema" con contraseña | **`"luks_passphrase": "…"`** (LUKS2 en la raíz; nuevo en `0.13.0`) |
| Escritorio | ninguno | `"desktop": ""` |
| Swap | ninguna | el esquema por defecto no crea swap |
| Reloj | UTC | `"hw_clock": "utc"` (por defecto en headless desde `0.13.0`) |

Camino principal auditado: **headless, borrar disco, btrfs + LUKS2,
systemd-boot, sin escritorio**. La variante sin cifrar se indica en cada paso
y en [Sin LUKS](#variante-sin-luks).

## Configuración headless equivalente

```json
{
    "install_type": "simple",
    "headless_mode": true,
    "device": "/dev/nvme0n1",
    "allow_auto_partition": true,
    "fs_name": "btrfs",
    "subvolumes": "default",
    "luks_passphrase": "…",
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

Valores por defecto que se aplican al omitir claves
(`installer-lib/src/installer_config.cpp:480-505` y el struct
`InstallerConfig`) y que cambian el resultado:

- headless: `hostname` `cachyos`, `locale` `en_US.UTF-8`, `xkbmap` `us`,
  `timezone` `UTC`, **`hw_clock` `utc`**, `user_shell` `/bin/bash`, `kernel`
  `linux-cachyos`.
- Grupos del usuario: `wheel rfkill sys users lp video network storage audio`
  (`installer-lib/src/config.cpp:113`).
- `chwd: true`, `carry_network: true`, `hostcache: true`, `os_prober: true`
  (sin efecto con systemd-boot), `autologin: false`, `encrypt_swap: false`,
  `subvolumes` por defecto (`use_default_subvolumes = true`).

> Nota: `pixmatic_autoinstall/settings.jsonc` usa particiones explícitas
> (`partitions`, ESP de `2G`) y `"desktop": "kde"`, y no lleva
> `luks_passphrase` (la ISO trae aún `0.12.4`, que la rechazaría). Desde
> `0.13.0` las dos formas acaban en la misma estrategia `CreateLayout`; con el
> esquema por defecto la ESP mide `2048MiB`, igual que `2G` en sfdisk.

## Convenciones de los comandos

```bash
DEV=/dev/nvme0n1          # disco de destino ("device")
ESP=${DEV}p1              # /dev/sda1 en SATA (insert_partition_number)
ROOTP=${DEV}p2            # partición LUKS
MAP=cryptroot             # kLuksRootMapper (installer-lib/include/cachyos/disk.hpp:67)
ROOT=/dev/mapper/$MAP     # sin LUKS: ROOT=$ROOTP
MNT=/mnt                  # InstallContext::mountpoint (installer-lib/include/cachyos/types.hpp:135)
OPTS=defaults,noatime,compress=zstd:1   # btrfs en SSD; en HDD: compress=zstd
USER=…  HOSTNAME=…  PASS=…  ROOTPASS=…  LUKSPASS=…
```

- Los comandos se lanzan **con `argv`** (sin shell) salvo los que el código
  escribe como cadena, que van por `/bin/sh -c` (`gucc/src/process.cpp:388`).
  **"en el target"** = prefijo `/usr/bin/arch-chroot /mnt`
  (`gucc/src/process.cpp:190-191`); `arch-chroot` monta los sistemas de
  ficheros de API en cada llamada.
- Todos los procesos hijos llevan `LC_ALL=C`; los del target, además, sin
  `TMP`/`TMPDIR`/`TEMP`/`TEMPDIR` (`gucc/src/process.cpp:61-73`).
- Escrituras de ficheros: NCI las hace desde C++ en el live sobre `$MNT/…`;
  aquí se expresan con `printf`/`cat`.
- Contraseñas: registradas como secretos y enmascaradas en el log
  (`installer-lib/src/orchestrator.cpp:265-274`). **Ya no aparecen en la línea
  de comandos**: van por stdin a `cryptsetup` y a `openssl passwd -stdin`; en
  la línea de `usermod -p` solo va el hash.
- Log: `/tmp/cachyos-install.log` en el live
  (`installer-lib/include/cachyos/logging.hpp:24`); al final se copia a
  `$MNT/cachyos-install.log`.
- `--dry-run` registra los comandos sin ejecutarlos (`src/main.cpp:59-60`).

## Resumen de la secuencia

Fuente: `src/main.cpp:94-115`, `installer-lib/src/run_from_config.cpp:18-44`
y `installer-lib/src/orchestrator.cpp:129-181` (plan) y `:253-347` (bucle).
"¿Actúa?": **sí** = hace algo con nuestras opciones; *no-op* = se ejecuta sin
efecto. "Fallo": **aborta** = la instalación se detiene, *aviso* = se registra
y sigue (`fatal_label`, `orchestrator.cpp:32-53`). **Al abortar o cancelar se
ejecuta `Cleanup`** (desmonta y cierra LUKS; `orchestrator.cpp:288-293`).

| # | Paso | ¿Actúa? | Fallo | Efecto |
|---|---|---|---|---|
| 0 | (preparación) | sí | aborta* | Validación, red, llaveros del live, detección UEFI, plan de particiones |
| 1 | `Umount` | sí | aviso | Desmonta lo que haya bajo `/mnt` |
| 2 | `Partition` | sí | aborta | Borra el disco, GPT, ESP 2 GiB, **LUKS2**, btrfs + 7 subvolúmenes |
| 3 | `DetectCrypto` | sí | ignorado | Detecta el mapper LUKS de `/` (afecta a `HOOKS` y cmdline) |
| 4 | `Base` | sí | aborta | `vconsole.conf`, rate-mirrors, `pacman.conf` con repos optimizados, hook que difiere el initramfs, `pacstrap`, `HOOKS` |
| 5 | `Fstab` | sí | aborta | `genfstab` |
| 6 | `LuksKeyfile` | no-op | aborta | Solo con `/boot` cifrado |
| 7 | `EncryptSwap` | no-op | aviso | Sin swap |
| 8 | `SystemSettings` | sí | aborta | hostname, hosts, locale, X11 keyboard, keymap del live, zona, hwclock |
| 9 | `MachineId` | sí | aviso | machine-id nuevo y enlace dbus |
| 10 | `Desktop` | no-op | aviso | `desktop` vacío |
| 11 | `DesktopConfigure` | no-op | aviso | (plymouth: no se configura) |
| 12 | `Chwd` | sí | aviso | `chwd -a -f` (una sola vez) |
| — | `ServerPackages`, `ServerFirewall`, `SshKeys` | no se ejecutan | — | Solo con `server_profile` |
| 13 | `Users` | sí | **aborta** | Contraseña de root, grupos, usuario, sudoers |
| 14 | `Autologin` | no-op | aviso | `autologin: false` |
| 15 | `NetworkCarryover` | sí | aviso | Copia las conexiones de NetworkManager del live |
| 16 | `Initramfs` | sí | aborta | `mkinitcpio -P` (única generación) |
| 17 | `RestoreInitramfsHook` | sí | aviso | Quita el hook que difería el initramfs |
| 18 | `Bootloader` | sí | aborta | `pacstrap systemd-boot-manager`, `bootctl install`, `/etc/kernel/cmdline`, `sdboot-manage gen` |
| 19 | `EnableServices` | sí | aviso | `systemctl enable/disable` según `net-profiles.toml`, ufw |
| 20 | `FinalValidation` | sí | aviso | Comprobaciones (solo registra) |
| — | `PostInstall` | no se ejecuta | aviso | Solo con `post_install`; con el target **montado** |
| 21 | `BtrfsSnapshot` | no-op | aviso | Sin `cachyos-snapper-support` |
| 22 | `Cleanup` | sí | aviso | Copia el log, desmonta, cierra LUKS |

\* Salvo los llaveros, cuyo fallo solo se avisa (`run_from_config.cpp:34-36`).

---

## Paso 0: preparación en el live

`src/main.cpp:84-115`, `installer-lib/src/run_from_config.cpp:18-44`:

```bash
# si stdin es /dev/tty*: setterm -blank 0 -powersave off      (main.cpp:85-87)
# lee y valida el JSON (claves desconocidas = error); headless_mode → sigue aquí
# root obligatorio (getuid()==0)                                (main.cpp:95)

# validate_headless_config (installer_config.cpp:510-560): exige device, fs_name,
#   partitions (salvo allow_auto_partition), user_name, user_pass, root_pass y
#   desktop; valida hostname y user_name

# wait_for_connection(15s) (system.cpp:97-111): GET https://cachyos.org (timeout 15 s),
#   reintenta 1/s hasta 15 s; sin red → aborta

# install_cachyos_repo (system.cpp:113-118) → refresh_keyrings (gucc/src/repos.cpp:127-145)
pacman-key --init
pacman -Sy --noconfirm --needed cachyos-keyring      # hasta 5 intentos (repos.cpp:106-112)
#   si falla: pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
#             pacman-key --lsign-key F3B607488DB35A47 ; y repite la instalación
pacman -Sy --noconfirm --needed archlinux-keyring    # hasta 5 intentos
pacman-key --populate
# cualquier fallo aquí → solo aviso

# installer_config_to_inputs (installer_config.cpp:562-641)
#   detect_system (system.cpp:57-81): carga el módulo efivarfs; /sys/firmware/efi/
#   existe → UEFI; si efivars no está montado: mount -t efivarfs efivarfs /sys/firmware/efi/efivars
#   headless_strategy_from_config (headless_plan.cpp:145-237):
#     partitions vacío + allow_auto_partition → esquema por defecto (disk.cpp:193-209)
#     luks_passphrase: no vacía; con systemd-boot exige una partición /boot aparte
#       (headless_plan.cpp:207-220) → la ESP en /boot lo cumple
#     → CreateLayout{device, partitions, btrfs_subvolumes, luks_passphrase}
```

Respecto al live: `pacman-key --init` sobre el llavero ya inicializado por
`pacman-init.service` no lo rehace; se instalan los paquetes de llaveros
actuales y se repuebla. El llavero del target sale de aquí (pacstrap lo
copia; Paso 4).

## Paso 1: `Umount`

Se ejecuta con `CreateLayout` (`installer-lib/src/steps/partition.cpp:64-66`);
`gucc/src/umount_partitions.cpp:18-47`:

```bash
sync
# por cada entrada de /proc/mounts bajo /mnt, de más profunda a menos:
umount -v <punto> || umount -v -l <punto>
```

No desmonta ni cierra nada fuera de `/mnt` (particiones del disco montadas en
otra ruta, swaps activas, mappers LUKS abiertos).

## Paso 2: `Partition` (borrar disco + LUKS2 + btrfs)

`installer-lib/src/steps/partition.cpp:96-140` (`CreateLayout`).

### Qué decide NCI

- Tabla **GPT** (`gucc/src/partitioning.cpp:122`).
- **ESP**: FAT32, **2048 MiB**, montada en **`/boot`**
  (`installer-lib/include/cachyos/disk.hpp:91-127`). Tipo `U` (EFI System,
  `C12A7328-F81F-11D2-BA4B-00A0C93EC93B`) y atributo `bootable`
  (`gucc/src/partitioning.cpp:49-84`), que en GPT sfdisk traduce al bit 2
  *LegacyBIOSBootable*.
- **Raíz**: resto del disco, tipo **`SD_GPT_ROOT_X86_64`**
  (`4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709`) en UEFI (`partitioning.cpp:51-56`).
  Alineación y comienzo de la primera partición: los de sfdisk (1 MiB).
- **LUKS2** sobre la raíz, abierta como `/dev/mapper/cryptroot`; el btrfs va
  dentro (`partition.cpp:110-123`). Opciones de `cryptsetup`: las suyas por
  defecto (`extra_flags` vacío).
- Sin swap ni etiquetas.
- Opciones de montaje btrfs: `defaults,noatime,compress=zstd:1` si el disco no
  es rotacional, `compress=zstd` si lo es
  (`gucc/src/partition_config.cpp:132-138`; SSD según
  `/sys/block/<disco>/queue/rotational`, `gucc/src/system_query.cpp:236-245`).
  ESP: `defaults,umask=0077` (`partition_config.cpp:145-146`).
- Subvolúmenes por defecto (`installer-lib/src/disk.cpp:119-130`):

| Subvolumen | Punto de montaje |
|---|---|
| `/@` | `/` |
| `/@home` | `/home` |
| `/@root` | `/root` |
| `/@srv` | `/srv` |
| `/@cache` | `/var/cache` |
| `/@tmp` | `/var/tmp` |
| `/@log` | `/var/log` |

  `@snapshots` está comentado: no se crea.

### Comandos

```bash
# --- erase_disk (gucc/src/partitioning.cpp:139-155) ---
dd if=/dev/zero of="$DEV" bs=512 count=1
wipefs -af "$DEV"                 # solo el disco, no las particiones
sgdisk -Zo "$DEV"

# --- tabla (gen_sfdisk_command :90-128, run_sfdisk_part :130-137) ---
printf 'label: gpt\ntype=U,size=2048MiB,bootable\ntype=4f68bce3-e8cd-4db1-96e7-fbcaf984b709\n' \
    | sfdisk -w always -W always "$DEV"
udevadm settle; sync              # settle_devices (gucc/src/io_utils.cpp:244-250)

# --- LUKS2 (gucc/src/luks.cpp:69-83; contraseña por stdin, terminada en \n) ---
printf '%s\n' "$LUKSPASS" | sh -c "cryptsetup -q  --type luks2 luksFormat $ROOTP"
printf '%s\n' "$LUKSPASS" | sh -c "cryptsetup open --type luks2 $ROOTP $MAP"

# --- raíz (installer-lib/src/disk.cpp:602-632) ---
mkfs.btrfs -f "$ROOT"
udevadm settle; sync
mkdir -p /mnt
mount -t btrfs -o "$OPTS" "$ROOT" /mnt        # gucc/src/mount_partitions.cpp:24-38
# (lee /proc/self/mounts y lsblk: detecta LUKS y guarda UUIDs)

# --- subvolúmenes (gucc/src/btrfs.cpp:41-80) ---
for sv in @ @home @root @srv @cache @tmp @log; do btrfs subvolume create /mnt/$sv; done
umount -v /mnt
mount -o "subvol=/@,$OPTS"      "$ROOT" /mnt/
mkdir -p /mnt/home      && mount -o "subvol=/@home,$OPTS"  "$ROOT" /mnt/home
mkdir -p /mnt/root      && mount -o "subvol=/@root,$OPTS"  "$ROOT" /mnt/root
mkdir -p /mnt/srv       && mount -o "subvol=/@srv,$OPTS"   "$ROOT" /mnt/srv
mkdir -p /mnt/var/cache && mount -o "subvol=/@cache,$OPTS" "$ROOT" /mnt/var/cache
mkdir -p /mnt/var/tmp   && mount -o "subvol=/@tmp,$OPTS"   "$ROOT" /mnt/var/tmp
mkdir -p /mnt/var/log   && mount -o "subvol=/@log,$OPTS"   "$ROOT" /mnt/var/log

# --- ESP (gucc/src/mount_partitions.cpp:77-108) ---
mkfs.vfat -F32 "$ESP"
udevadm settle; sync
mkdir -p /mnt/boot
mount -t vfat -o defaults,umask=0077 "$ESP" /mnt/boot
```

### Variante con `partitions` en el JSON

Mismos comandos; el tamaño de la ESP sale del JSON (`"2G"` → `size=2G`, que
sfdisk interpreta como GiB) y antes de tocar el disco se validan numeración,
una sola `root`, una sola `boot` en UEFI y tamaños
(`installer-lib/src/headless_plan.cpp:41-139`).

## Paso 3: `DetectCrypto`

`installer-lib/src/steps/detect_crypto.cpp:10-22` →
`installer-lib/src/crypto.cpp:63-91`: con `lsblk` busca el dispositivo montado
en `/mnt` y su ancestro `crypt`. Resultado: `is_luks = true`, mapper
`cryptroot`, UUID de la cabecera LUKS (`$ROOTP`) y
`cryptdevice=UUID=<uuid-luks>:cryptroot` (este último no se usa con
systemd-boot). Se ejecuta **antes** de `Base` porque decide los `HOOKS`
(orquestador, `:142-143`). Si falla solo se registra.

## Paso 4: `Base`

`installer-lib/src/packages.cpp:133-172` → `gucc/src/install.cpp:73-158`.

### 4a. Teclado de consola

`gucc/src/install.cpp:89-93`, `gucc/src/keyboard.cpp:40-76`. El valor es
`console_keymap` o, si falta, `xkbmap` (`installer_config.cpp:616-619`):

```bash
mkdir -p /mnt/etc
printf 'KEYMAP=es\n' > /mnt/etc/vconsole.conf
```

Antes de `pacstrap`, para que `sd-vconsole` lo meta en el initramfs. Solo
`KEYMAP`; sin `FONT`.

### 4b. Mirrors (en el live)

`gucc/src/mirrors.cpp:13-24`:

```bash
pacman -Sy --noconfirm --needed cachyos-rate-mirrors rate-mirrors   # fallo → aviso
cachyos-rate-mirrors                                                # fallo → aborta
```

Reescribe los mirrorlists **del live** (`/etc/pacman.d/mirrorlist` y los
`cachyos-*mirrorlist`).

### 4c. `pacman.conf` con los repos optimizados

`gucc/src/repos.cpp:78-104`, `:161-166`; inserción en
`gucc/src/pacmanconf_repo.cpp:43-66`:

```bash
cp /etc/pacman.conf /tmp/cachyos-installer-pacman.conf
# [cachyos] ya está en el pacman.conf del live → no se añade
systemd-detect-virt     # si contiene "oracle" (VirtualBox) no añade repos por ISA
# añade UNO de estos bloques delante de la primera sección de repo, según la CPU:
#   znver4    → [cachyos-znver4] [cachyos-core-znver4] [cachyos-extra-znver4]  (cachyos-v4-mirrorlist)
#   x86_64_v4 → [cachyos-v4] [cachyos-core-v4] [cachyos-extra-v4]              (cachyos-v4-mirrorlist)
#   x86_64_v3 → [cachyos-v3] [cachyos-core-v3] [cachyos-extra-v3]              (cachyos-v3-mirrorlist)
```

Los bloques solo llevan `Include =`: heredan el `SigLevel` global
(`Required DatabaseOptional`); el `[cachyos]` del live conserva su
`SigLevel = Optional TrustAll` (`iso:archiso/airootfs/etc/pacman.conf:73-74`).

### 4d. Hook que difiere el initramfs

`gucc/src/initcpio.cpp:306-316` (copia del mecanismo de Calamares,
`:27-86`). Antes de `pacstrap` escribe en el target:

- `/mnt/etc/pacman.d/hooks/90-mkinitcpio-install.hook`: mismo nombre que el
  hook de `mkinitcpio`, así que lo sustituye. Disparadores
  `usr/lib/modules/*/vmlinuz` y `usr/lib/initcpio/*`, `PostTransaction`.
- `/mnt/usr/share/libalpm/scripts/mkinitcpio-install-calamares` (ejecutable):
  crea `/etc/mkinitcpio.d/<pkgbase>.preset` desde la plantilla y copia
  `vmlinuz` a `/boot/vmlinuz-<pkgbase>`, **sin generar el initramfs**.

Se quitan en el Paso 17.

### 4e. `pacstrap`

`gucc/src/io_utils.cpp:224-242`:

```bash
pacstrap -c -C /tmp/cachyos-installer-pacman.conf /mnt <paquetes> \
    --cachedir /mnt/var/cache/pacman/pkg --cachedir /var/cache/pacman/pkg \
    --hookdir /mnt/etc/pacman.d/hooks
```

- `--cachedir` del target primero: pacman descarga en la primera caché
  escribible, así que **lo descargado queda en la caché del target**
  (`@cache`); la del live (`hostcache: true`) solo se lee. NCI no la vacía
  después.
- `--hookdir` del target: así se aplica el hook de 4d.
- Sin `-G` ni `-M`: pacstrap copia al target el llavero del live (Paso 0) y
  `/etc/pacman.d/mirrorlist` (ya ordenado).

Lista de paquetes (`gucc/src/package_list.cpp:131-180`), en este orden:

1. `linux-cachyos`, `linux-cachyos-headers`.
2. Por ser raíz btrfs y no servidor: `snapper`, `btrfs-assistant-git`.
3. `[base-packages.desktop]` de `net-profiles.toml` (líneas 62-193), porque no
   es servidor, **aunque no haya escritorio**.
4. `[base-packages]` (líneas 1-60).
5. Microcódigo según la CPU: `intel-ucode` o `amd-ucode`.

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
actual: todos los nombres resuelven (`dnsutils` e `iptables-nft` por
*provides*). Un nombre inexistente haría fallar el `pacstrap` completo.

### 4f. Ficheros copiados del live

`gucc/src/install.cpp:113-130`:

```bash
cp /tmp/cachyos-installer-pacman.conf /mnt/etc/pacman.conf      # el de 4c, con repos optimizados
for f in cachyos-mirrorlist cachyos-v3-mirrorlist cachyos-v4-mirrorlist; do
    [ -e /etc/pacman.d/$f ] && cp /etc/pacman.d/$f /mnt/etc/pacman.d/$f   # ordenados en 4b
done
rm -f /tmp/cachyos-installer-pacman.conf                         # al salir del paso
```

El target se queda con **los mismos repos con los que se instaló**
(`[cachyos-v3]`… delante de `[cachyos]`, `[core]`, `[extra]`, `[multilib]`) y
con todos los mirrorlists ordenados.

### 4g. `HOOKS` de `mkinitcpio`

`gucc/src/initcpio.cpp:216-304`, con `use_systemd_hook = true`,
`is_luks = true` (Paso 3) y sin plymouth (`installer-lib/src/packages.cpp:89-99`,
`:156`). Reescribe las líneas activas `MODULES`, `FILES` y `HOOKS` de
`/mnt/etc/mkinitcpio.conf` (`MODULES` y `FILES` con su valor actual):

```bash
sed -i 's/^HOOKS=.*/HOOKS=(base systemd keyboard autodetect microcode modconf block sd-vconsole sd-encrypt filesystems)/' /mnt/etc/mkinitcpio.conf
```

- Con LUKS, `keyboard` va **antes** de `autodetect` (todos los drivers de
  teclado, para escribir la contraseña).
- Sin `kms`, sin `fsck` (btrfs), sin `btrfs` (un dispositivo), sin
  `plymouth`. No toca `/etc/mkinitcpio.conf.d/`.
- **No genera el initramfs aquí** (Paso 16).

Al terminar, `installer-lib/src/packages.cpp:166-169` crea el marcador
`/mnt/.base_installed`, que **no se borra nunca**.

## Paso 5: `Fstab`

`installer-lib/src/steps/fstab.cpp`, `gucc/src/fstab.cpp:117-154`:

```bash
genfstab -U -p /mnt > /mnt/etc/fstab
# strip_subvolid_options (:176-189): quita desde "subvolid=" hasta la ÚLTIMA coma
#   de la línea, solo si esa coma está DESPUÉS de ",subvol=/…"
# (comenta datasets ZFS: no aplica)
```

El kernel lista `subvolid=` y `subvol=` al final de las opciones
(`…,subvolid=256,subvol=/@`); no hay coma después de `subvol=`, así que la
limpieza **no actúa** y el `fstab` conserva `subvolid=` (igual que el `sed` de
`0.12.4`). Con LUKS, `genfstab -U` escribe el UUID del btrfs (dentro del
mapper). Solo una vez (en `0.12.4` eran dos).

## Paso 6: `LuksKeyfile` (no-op)

`installer-lib/src/steps/luks_keyfile.cpp:20-34`: solo actúa si **no** hay
partición `/boot` aparte (raíz y `/boot` cifrados: añade
`/crypto_keyfile.bin` a la LUKS y a `FILES` de `mkinitcpio.conf`). Con la ESP
en `/boot`, `is_fde = false` y no hace nada.

## Paso 7: `EncryptSwap` (no-op)

`installer-lib/src/steps/encrypt_swap.cpp:10-28`: sin swap.

## Paso 8: `SystemSettings`

`installer-lib/src/config.cpp:41-89`:

```bash
# hostname y hosts (gucc/src/user.cpp:125-147)
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

# locale (gucc/src/locale.cpp:35-74)
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
# descomenta las líneas cuya primera palabra es exactamente es_ES.UTF-8 (:116-120)
sed -i 's/^#\(es_ES\.UTF-8\s\)/\1/' /mnt/etc/locale.gen
arch-chroot /mnt locale-gen

# teclado X11 (gucc/src/locale.cpp:91-96, gucc/src/keyboard.cpp:48-84)
mkdir -p /mnt/etc/X11/xorg.conf.d
cat > /mnt/etc/X11/xorg.conf.d/00-keyboard.conf <<'EOF'
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "es"
EndSection
EOF

# teclado del LIVE (config.cpp:67-74; fallo → aviso)
localectl set-keymap es

# zona horaria (gucc/src/timezone.cpp:55-77): enlace absoluto
rm -f /mnt/etc/localtime
ln -s /usr/share/zoneinfo/Europe/Madrid /mnt/etc/localtime

# reloj (gucc/src/hwclock.cpp:13-21)
arch-chroot /mnt sh -c 'hwclock --systohc --utc' || arch-chroot /mnt sh -c 'hwclock --systohc --utc --directisa'
```

Lo que **no** hace: no toca `/etc/vconsole.conf` (4a); no escribe
`XkbModel`/`XkbVariant`, `/etc/default/keyboard`, `/etc/default/locale` ni
`/etc/timezone`. Cualquier fallo de este paso **aborta**.

## Paso 9: `MachineId`

`gucc/src/machine_id.cpp:20-70`:

```bash
rm -f /mnt/etc/machine-id /mnt/var/lib/dbus/machine-id
systemd-machine-id-setup --root=/mnt         # en el live
mkdir -p /mnt/var/lib/dbus
ln -s /etc/machine-id /mnt/var/lib/dbus/machine-id
```

No toca `/var/lib/systemd/random-seed`.

## Paso 10-11: `Desktop` y `DesktopConfigure` (no-op)

`installer-lib/src/steps/desktop.cpp:6-15`,
`installer-lib/src/steps/desktop_configure.cpp`: salen sin hacer nada si
`desktop` está vacío. Por tanto `configure_desktop_extras`
(`installer-lib/src/packages.cpp:191-211`) no corre: `plymouth` y
`cachyos-plymouth-bootanimation` quedan instalados (4e) pero sin tema fijado
ni hook `plymouth`.

## Paso 12: `Chwd`

`installer-lib/src/steps/chwd.cpp:9-14`, `gucc/src/chwd.cpp:87-92`, con
`chwd: true`:

```bash
arch-chroot /mnt sh -c 'chwd -a -f'      # fallo → aviso
```

Una sola vez (en `0.12.4` había otra, incondicional, dentro de `Base`). Corre
con el hook de 4d activo: si instala paquetes con kernel o módulos, el
initramfs se genera igualmente después (Paso 16).

## Paso 13: `Users`

`installer-lib/src/steps/users.cpp:9-19`, `installer-lib/src/config.cpp:91-122`,
`gucc/src/user.cpp:25-123`:

```bash
# contraseña de root (set_user_password, :48-57)
H=$(printf '%s' "$ROOTPASS" | openssl passwd -6 -stdin)    # en el live; SHA-512 ($6$)
arch-chroot /mnt usermod -p "$H" root

# shell: con zsh/fish instala antes cachyos-{zsh,fish}-config con pacstrap
#   (pacman.conf del target); con bash, nada

for g in wheel rfkill sys users lp video network storage audio; do
    arch-chroot /mnt groupadd --force "$g"
done
arch-chroot /mnt useradd -m -U -s /bin/bash "$USER"
arch-chroot /mnt usermod -aG wheel,rfkill,sys,users,lp,video,network,storage,audio "$USER"
arch-chroot /mnt chown -R "$USER:$USER" "/home/$USER"
H=$(printf '%s' "$PASS" | openssl passwd -6 -stdin)
arch-chroot /mnt usermod -p "$H" "$USER"

# sudoers (:109-121)
printf '%%wheel ALL=(ALL) ALL\n' > /mnt/etc/sudoers.d/10-installer
chmod 0440 /mnt/etc/sudoers.d/10-installer
```

Va **después de todos los paquetes del sistema** (existen ya shell y grupos de
los paquetes; `useradd -m` copia el `/etc/skel` completo) y **cualquier fallo
aborta** la instalación.

## Paso 14: `Autologin` (no-op)

`installer-lib/src/steps/autologin.cpp`: `autologin` falso.

## Paso 15: `NetworkCarryover`

`installer-lib/src/steps/network_carryover.cpp:18-24`,
`gucc/src/network.cpp:151-186`:

```bash
mkdir -p /mnt/etc/NetworkManager/system-connections
for f in /etc/NetworkManager/system-connections/*.nmconnection; do
    cp -f "$f" /mnt/etc/NetworkManager/system-connections/
    chmod 600 "/mnt/etc/NetworkManager/system-connections/${f##*/}"
done
```

Copia tal cual (sin reescribir `permissions=` ni otros campos).

## Paso 16: `Initramfs`

`installer-lib/src/steps/initramfs.cpp:12-14`:

```bash
arch-chroot /mnt sh -c 'mkinitcpio -P'      # fallo → aborta
```

Única generación, con `HOOKS` de 4g, `vconsole.conf` de 4a y lo que haya
añadido `chwd`. Los presets y `/boot/vmlinuz-linux-cachyos` los dejó el
script de 4d.

## Paso 17: `RestoreInitramfsHook`

`installer-lib/src/steps/initramfs.cpp:16-18`, `gucc/src/initcpio.cpp:318-327`:

```bash
rm -f /mnt/etc/pacman.d/hooks/90-mkinitcpio-install.hook \
      /mnt/usr/share/libalpm/scripts/mkinitcpio-install-calamares
```

A partir de aquí vuelve a regir el hook de `mkinitcpio`. `Cleanup` lo repite
por si la instalación se aborta antes.

## Paso 18: `Bootloader` (systemd-boot)

`installer-lib/src/bootloader.cpp:335-361`, `:414-432`;
`gucc/src/bootloader.cpp:225-254`:

```bash
mountpoint -q /sys/firmware/efi/efivars || mount -t efivarfs efivarfs /sys/firmware/efi/efivars

pacstrap -c -C /mnt/etc/pacman.conf /mnt systemd-boot-manager \
    --cachedir /mnt/var/cache/pacman/pkg --cachedir /var/cache/pacman/pkg \
    --hookdir /mnt/etc/pacman.d/hooks

arch-chroot /mnt sh -c 'bootctl --path=/boot install'
printf '%s\n' "$CMDLINE" > /mnt/etc/kernel/cmdline
arch-chroot /mnt sh -c 'sdboot-manage gen'
# solo si el disco es extraíble (lsblk "rm" del disco padre): quita "autodetect" de HOOKS
```

**Línea de comandos** (`installer-lib/src/bootloader.cpp:106-142`, `:283-293`;
`gucc/src/kernel_params.cpp:21-96`; `kDefaultKernelParams` en
`gucc/include/gucc/kernel_params.hpp:18-22`):

```
CMDLINE="splash quiet zswap.enabled=0 nowatchdog rw rootflags=subvol=/@ rd.luks.name=<uuid-luks>=cryptroot root=/dev/mapper/cryptroot"
```

- `splash` porque existe `/usr/bin/plymouth` en el target (aunque el initramfs
  no lleve el hook `plymouth`).
- `rootflags=subvol=/@`: sale de las opciones de montaje de `/mnt`
  (subvolumen distinto del 5).
- LUKS con hook systemd: `rd.luks.name=<UUID de la cabecera>=cryptroot` y
  `root=/dev/mapper/cryptroot` (en lugar de `root=UUID=`). El commit `403d49f`
  probó `rd.luks.uuid=`, pero `5e3132e` lo dejó en `rd.luks.name=` porque
  `rd.luks.uuid=` abre el mapper como `luks-<uuid>` y `root=` no lo
  encontraría (comentario en `kernel_params.cpp:25`).
- No escribe `/etc/crypttab` ni `/etc/crypttab.initramfs`: el desbloqueo
  depende solo de la cmdline.

**Entradas** (`pkgbuilds:systemd-boot-manager/sdboot-manage:276-371`,
configuración `sdboot-manage.conf` con `LINUX_OPTIONS="nowatchdog quiet
splash"`): con `/etc/kernel/cmdline` no vacío, la versión 24 usa su contenido
**y le añade `LINUX_OPTIONS`** (`:298-307`). Genera una entrada por kernel con
los `/boot/vmlinuz-*` e `initramfs-*.img` del Paso 16:

```
# /boot/loader/entries/linux-cachyos.conf
title Linux CachyOS
options splash quiet zswap.enabled=0 nowatchdog rw rootflags=subvol=/@ rd.luks.name=<uuid-luks>=cryptroot root=/dev/mapper/cryptroot nowatchdog quiet splash
linux /vmlinuz-linux-cachyos
initrd /initramfs-linux-cachyos.img
```

`nowatchdog quiet splash` quedan **repetidos**. El microcódigo va dentro del
initramfs (hook `microcode`). `loader.conf` queda como lo deje `bootctl
install`.

## Paso 19: `EnableServices`

`installer-lib/src/packages.cpp:242-288`, lista de `net-profiles.toml`
(`[services]` líneas 195-207 y `[services.desktop]` 209-224). Cada unidad se
aplica solo si existe `/mnt/usr/lib/systemd/system/<unidad>` (se añade
`.service` si no lleva punto); si no, se salta
(`gucc/src/systemd_services.cpp:55-61`). Comando en el target:
`systemctl enable|disable <unidad>` o `systemctl --global enable <unidad>`
para las de usuario.

| Unidad | Acción | ¿Existe con nuestras opciones? |
|---|---|---|
| `NetworkManager` | enable (urgente) | sí |
| `fstrim.timer` | enable | sí (util-linux) |
| `systemd-timesyncd` | enable | sí |
| `sshd` | — | se quita de la lista en modo escritorio (`gucc/src/package_list.cpp:225-231`) |
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

Después (`:264-285`):

```bash
# display manager: busca unidades de DM en el target → ninguna → no hace nada
# ufw instalado (gucc/src/firewall.cpp:23-33, :74-90); kdeconnect no está → sin regla extra
arch-chroot /mnt systemctl enable ufw
arch-chroot /mnt sh -c 'ufw default deny incoming'
arch-chroot /mnt sh -c 'ufw default allow outgoing'
arch-chroot /mnt sh -c 'ufw enable'
```

Otras unidades activas (p. ej. las de `cachyos-settings`) las activan los
scriptlets de los paquetes, no NCI.

## Paso 20: `FinalValidation`

`installer-lib/src/validation.cpp:100-143`. Solo registra avisos:

- existe `/mnt/.base_installed`;
- existe `/mnt/boot/loader/loader.conf` (o `/mnt/boot/efi/loader/loader.conf`);
- `/mnt/etc/fstab` tiene alguna línea activa;
- `arch-chroot /mnt locale -a` devuelve algún locale que no sea `C`/`POSIX`;
- el campo de contraseña de root en `/mnt/etc/shadow` no está vacío ni es
  `*`, `!`, `!!` o `!*`;
- existe `/mnt/home`.

## `PostInstall` (no se ejecuta)

`installer-lib/src/steps/post_install.cpp:14-23`: solo si hay `post_install`.
Ejecuta el script **en el live, con el target aún montado** y la raíz del
target como `$1` (`<script> /mnt`, sin shell: el fichero debe ser
ejecutable). Va después de `FinalValidation` y antes de `BtrfsSnapshot`; si
falla, aviso.

## Paso 21: `BtrfsSnapshot` (no-op)

`installer-lib/src/steps/btrfs_snapshot.cpp:15-21`, `gucc/src/btrfs.cpp:123-143`:

```bash
arch-chroot /mnt pacman -Qq cachyos-snapper-support   # no instalado → sale
```

Con ese paquete: `snapper --no-dbus -c root create --print-number
--description 'Fresh CachyOS Installation' --userdata 'important=yes'` y el
número en `/etc/cachyos/installation-snapshot`. `snapper` sí está instalado
(4e), pero sin configuración `root`.

## Paso 22: `Cleanup`

`installer-lib/src/steps/cleanup.cpp:20-46` (también al abortar o cancelar):

```bash
rm -f /mnt/etc/pacman.d/hooks/90-mkinitcpio-install.hook \
      /mnt/usr/share/libalpm/scripts/mkinitcpio-install-calamares   # ya hecho en el Paso 17
cp -f /tmp/cachyos-install.log /mnt/cachyos-install.log             # si /mnt está montado
sync
# umount -v (o -lv) de cada punto bajo /mnt, de más profundo a menos (como el Paso 1)
cryptsetup close cryptroot
```

No apaga ni reinicia el equipo.

---

## Variante sin LUKS

Sin `luks_passphrase`:

- Paso 2: sin `cryptsetup`; `mkfs.btrfs` y montajes sobre `$ROOTP`.
- Paso 4g: `HOOKS=(base systemd autodetect microcode modconf block keyboard sd-vconsole filesystems)`
  (`keyboard` después de `block`, sin `sd-encrypt`).
- Paso 18: `CMDLINE="splash quiet zswap.enabled=0 nowatchdog rw rootflags=subvol=/@ root=UUID=<uuid-btrfs>"`.
- Paso 22: sin `cryptsetup close`.

El modo avanzado interactivo (TUI) sigue teniendo su propio camino de cifrado;
ya no se audita porque el headless cubre LUKS.

---

## Estado final esperado del target (resumen)

| Elemento | Valor |
|---|---|
| Particiones | `p1` ESP 2 GiB FAT32 (`C12A7328…`, atributo LegacyBIOSBootable), `p2` LUKS2 (`4F68BCE3…`, raíz x86-64) |
| LUKS | LUKS2 con los valores por defecto de `cryptsetup`, mapper `cryptroot`, una contraseña; sin keyfile ni TPM |
| Subvolúmenes | `@ @home @root @srv @cache @tmp @log` (sin `@snapshots`) |
| Montaje btrfs | `noatime,compress=zstd:1` (SSD) |
| `fstab` | `genfstab -U -p` (con `subvolid=`); ESP en `/boot` con `umask=0077` |
| `crypttab` | ninguno |
| Kernel | `linux-cachyos` (+ headers); un solo kernel |
| initramfs | `HOOKS=(base systemd keyboard autodetect microcode modconf block sd-vconsole sd-encrypt filesystems)`, generado una vez |
| Bootloader | systemd-boot (`bootctl install`) + `systemd-boot-manager`; entrada `linux-cachyos.conf` |
| cmdline | `/etc/kernel/cmdline` = `splash quiet zswap.enabled=0 nowatchdog rw rootflags=subvol=/@ rd.luks.name=<uuid>=cryptroot root=/dev/mapper/cryptroot`; la entrada añade `nowatchdog quiet splash` (repetidos) |
| Locale | `es_ES.UTF-8` en `LANG` y 10 `LC_*` (sin `LC_CTYPE`/`LC_COLLATE`) |
| Teclado | `vconsole.conf`: `KEYMAP=es`; X11: `XkbLayout es` sin modelo |
| Zona | `/etc/localtime` → `/usr/share/zoneinfo/Europe/Madrid`; RTC en UTC |
| Usuario | bash, grupos `wheel rfkill sys users lp video network storage audio`; root con contraseña propia |
| Hashes | **SHA-512 (`$6$`)** vía `openssl passwd -6 -stdin` |
| sudo | `/etc/sudoers.d/10-installer`: `%wheel ALL=(ALL) ALL` |
| `pacman.conf` | el del live **más los repos optimizados** con los que se instaló; mirrorlists de CachyOS ordenados |
| Caché de paquetes | **llena** (`/var/cache/pacman/pkg` en `@cache`, con todo lo descargado) |
| Servicios | `NetworkManager`, `fstrim.timer`, `systemd-timesyncd`, `bluetooth`, `avahi-daemon`, `ModemManager`, `ufw` (+ los que existan de la lista) |
| Firewall | ufw activo: deny incoming, allow outgoing |
| Restos | `/.base_installed`, `/cachyos-install.log` |
| Plymouth | instalado, sin tema fijado ni hook; `splash` en la cmdline |
| Snapper | instalado, sin configurar |

---

## Cambios respecto a `0.12.4`

| Tema | `0.12.4` | `0.13.0` |
|---|---|---|
| Preparación | red, llaveros y validación en `src/main.cpp` | en `installer-lib` (`run_from_config`); `installer-lib` y `gucc` se empaquetan aparte y las usa también Calamares `cachyos-staging` |
| Ejecución de comandos | por `/bin/sh -c` | `argv` sin shell en la mayoría |
| Llaveros del live | importa y firma la clave de CachyOS | `pacman-key --init`, instala `cachyos-keyring` y `archlinux-keyring`, `--populate` |
| Borrar disco | estrategia `EraseAndAuto`, ESP **4 GiB** | `CreateLayout` con esquema por defecto, ESP **2 GiB** |
| Tipo de la raíz | `L` (`0FC63DAF…`) | `SD_GPT_ROOT_X86_64` (`4F68BCE3…`) |
| `sfdisk` | `-w always` | `-w always -W always` |
| Cifrado | no existe en headless | `luks_passphrase` → LUKS2, mapper `cryptroot` |
| `pacman.conf` del target | el del live, sin repos optimizados | el generado, con repos optimizados; mirrorlists ordenados copiados |
| Caché de paquetes | en la del live (`-c`) | descargas en la del target; queda llena |
| initramfs | `mkinitcpio -P` en `Base` | hook que lo difiere durante `pacstrap`; una sola generación antes del bootloader |
| `kms` en `HOOKS` | sí | no |
| `genfstab` | dos veces | una |
| `chwd -a -f` | dos veces (una incondicional) | una (respeta `chwd`) |
| Usuario | antes de `MachineId`; fallo = aviso | tras `Chwd`; fallo = aborta |
| Contraseñas | MD5-crypt (`$1$`) en la línea de comandos | SHA-512 (`$6$`) por stdin |
| `locale.gen` | `sed` que descomenta cualquier `#es_ES.UTF-8…` | solo líneas cuya primera palabra es el locale |
| `hw_clock` | sin defecto (si se omitía, no se tocaba) | `utc` por defecto |
| Teclado de consola | `xkbmap` | `console_keymap` o `xkbmap` |
| cmdline | sin `/etc/kernel/cmdline`; `sdboot-manage` la genera | `/etc/kernel/cmdline` propio (+ `LINUX_OPTIONS` de `sdboot-manage` 24) |
| Parámetros por defecto | `nowatchdog quiet splash` | además `zswap.enabled=0` |
| `post_install` | tras desmontar, `sh -c` con salida al log | con el target montado, `<script> /mnt` |
| Fallos | sin limpieza al abortar (`Cleanup` solo al final) | `Cleanup` desmonta y cierra LUKS también al abortar o cancelar |

## Hallazgos y peculiaridades

1. **La lista de paquetes y servicios viene de GitHub `master` en tiempo de
   ejecución** (`net-profiles.toml`), no del tag instalado.
2. **Caché de paquetes llena en el target**: `--cachedir` del target va
   primero; NCI no la limpia (en `0.12.4` quedaba vacía). A confirmar en VM.
3. **Parámetros repetidos en la entrada**: `/etc/kernel/cmdline` ya lleva
   `splash quiet … nowatchdog` y `sdboot-manage` 24 añade
   `nowatchdog quiet splash`. Con la versión 21 del repo puede ser distinto.
4. **`fstab` con `subvolid=`**: la limpieza solo actúa si hay otra opción
   después de `subvol=`, y el kernel lo pone al final. Un `snapper rollback`
   que cambie el subvolumen por defecto no afecta a `/` (va por
   `rootflags=subvol=/@`), pero `subvolid=` en `fstab` fija el subvolumen por
   número.
5. **Sin `crypttab`**: el desbloqueo depende de `rd.luks.name=` en la cmdline.
6. **`chwd` con el initramfs diferido**: si `chwd` añade módulos (NVIDIA), se
   recogen en la generación única del Paso 16.
7. **"Sin escritorio" no es mínimo**: con `desktop: ""` se instala todo
   `[base-packages.desktop]` (Firefox, fuentes, PipeWire, Bluetooth, octopi,
   alacritty…), más `snapper` y `btrfs-assistant-git`.
8. **Plymouth a medias**: instalado y con `splash`, sin hook ni tema (porque
   `DesktopConfigure` no corre sin escritorio).
9. **Teclado X11 sin modelo ni variante** (`XkbLayout` únicamente).
10. **ESP con atributo GPT LegacyBIOSBootable** por el `bootable` de sfdisk.
11. **Restos en el target**: `/.base_installed` y `/cachyos-install.log`.
12. **`loader.conf`** queda como lo deje `bootctl install`.
13. **`Umount` previo limitado a `/mnt`**: si el disco tiene particiones
    montadas en otro sitio, swap activa o LUKS abierto, `wipefs`/`sfdisk`
    pueden fallar.
14. **`cryptsetup luksFormat` con los valores por defecto** de la versión del
    live (argon2id, aes-xts-plain64, 512 bits en cryptsetup 2.x); NCI no fija
    nada.
15. Se activa `ufw` con `ufw enable` dentro del chroot.

## Pendiente de verificar en VM

- Que la caché del target queda llena (`du -sh /var/cache/pacman/pkg`).
- `fstab` real (si conserva `subvolid=`).
- Entrada de `/boot/loader/entries/` y cmdline efectiva (`/proc/cmdline`), con
  la versión de `systemd-boot-manager` que sirva el repo.
- Que el hook de 4d sustituye al de `mkinitcpio` durante el `pacstrap` (que
  no se genera el initramfs) y que el Paso 16 lo genera bien.
- Desbloqueo LUKS en el arranque con `rd.luks.name=` y `sd-encrypt`, sin
  `crypttab`.
- Contenido de `/boot/loader/loader.conf` tras `bootctl install`.
- Unidades realmente activadas (`systemctl list-unit-files --state=enabled`),
  incluidas `apparmor`, `haveged`, `cronie`.
- Que `ufw enable` funciona dentro de `arch-chroot`.
- Hash de `/etc/shadow` (`$6$`).
- Parámetros LUKS reales (`cryptsetup luksDump`).
