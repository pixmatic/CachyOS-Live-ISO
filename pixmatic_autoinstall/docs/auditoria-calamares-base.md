# Auditoría de Calamares: instalación base sin escritorio

Fase 2, primera parte. Secuencia exacta de lo que hace el Calamares de CachyOS
(modo *online*) con las opciones fijas de este proyecto, traducida a comandos
de consola de bajo nivel para poder replicarla.

## Versiones auditadas

| Componente | Repo | Rama/tag | Commit | Nota |
|---|---|---|---|---|
| Calamares | `CachyOS/cachyos-calamares` | `cachyos-dev` | `199d71543` (2026-09-26) | El PKGBUILD compila la rama sin fijar commit (pkgver 3.4.2-13). |
| PKGBUILDs | `CachyOS/CachyOS-PKGBUILDS` | `master` | `6c6dc36` (2026-11-15) | `cachyos-calamares/`, `systemd-boot-manager/` (pkgver 24; el repo `cachyos` sirve aún `21-1`). |
| KPMcore | `invent.kde.org/system/kpmcore` | tag `v26.08.3` | — | Versión empaquetada hoy (`extra` y `cachyos-extra-v3`). Calamares particiona con KPMcore, que lanza `sfdisk`, `mkfs.*`, `cryptsetup`. |
| ISO | `CachyOS/CachyOS-Live-ISO` | `master` | `3215497` (2026-10-03) | `calamares-online.sh` y ficheros del live que usa Calamares. |

Rutas citadas:

- Sin prefijo: relativas a `cachyos-calamares/`.
- `kpmcore:`: relativas a KPMcore `v26.08.3`.
- `iso:`: relativas a este repo (`archiso/…`).
- `pkgbuilds:`: relativas a `CachyOS-PKGBUILDS/`.

> Aviso: `netinstall.conf` descarga `netinstall.yaml` **desde GitHub
> (`cachyos-dev` HEAD) en tiempo de ejecución**, y solo usa la copia local si
> falla (`src/modules/netinstall/netinstall.conf`). La lista de paquetes real
> puede cambiar sin nueva versión de Calamares. Hay que revisarla al implementar.

## Alcance: opciones fijas

Solo se sigue el camino que corresponde a estas opciones. El resto de ramas
(GRUB, Limine, rEFInd, ZFS, BIOS, swap, escritorios, handheld) se ignoran salvo
cuando cambian algo de este camino.

| Opción | Valor | Cómo llega a Calamares |
|---|---|---|
| Idioma, números y fechas | `es_ES.UTF-8` | `LANG` y todas las `LC_*` |
| Zona | `Europe/Madrid` | módulo `locale` |
| Teclado | modelo `pc105`, distribución `es`, variante por defecto (vacía) | módulo `keyboard` |
| Firmware | UEFI exclusivo (sin CSM), TPM 2.0 | `firmwareType = efi` |
| Bootloader | `systemd-boot` | `packagechooser_bootloader = systemd-boot` |
| Disco | el de la configuración, **borrar disco**, btrfs | particionado automático (`doAutopartition`) |
| Cifrado | "Cifrar sistema" con contraseña (de un fichero privado) | `luksPassphrase` |
| Escritorio | *No Desktop* | `packagechooser_desktop` con `id: ""` |
| Swap | ninguna (opción por defecto) | `partition.conf:54` `initialSwapChoice: none` |

Valores por defecto que la interfaz deja cambiar y que aquí se dan por
aceptados (anotados porque cambian el resultado):

- **Contraseña de root = la del usuario** (`users.conf:42`
  `doReusePassword: true`, casilla marcada por defecto).
- **Grupos de netinstall preseleccionados**, incluido *Firefox and language
  package* (ver [Paso 14](#paso-14-packagesonline-netinstall)).
- Nombre de host propuesto `cachyos-${cpu}` (`users.conf:130`).

## Convenciones de los comandos

```bash
DEV=/dev/nvme0n1          # disco de destino (de la configuración)
ESP=${DEV}p1              # /dev/sda1 en SATA
CRYPT=${DEV}p2
ROOT=/tmp/calamares-root-XXXXXXXX   # tempfile.mkdtemp(prefix="calamares-root-")
LUKS_UUID=$(cryptsetup luksUUID "$CRYPT")
MAPPER=luks-$LUKS_UUID    # nombre que pone KPMcore
USER=…  HOSTNAME=…  PASS=…   # salen de la configuración privada
```

- **"en el live"**: el proceso corre en el sistema live (host).
- **"en el target"**: Calamares ejecuta `chroot $ROOT <cmd>` (un `chroot`
  plano, `src/libcalamares/utils/Runner.cpp:148`) con entorno `LC_ALL=C` y sin
  `TMP*`. **No es `arch-chroot`**: los sistemas de ficheros de API los monta
  antes el módulo `mount` y siguen montados hasta `umount`. La única excepción es
  `chwd`, que sí usa `arch-chroot`.
- Los `shellprocess` del target ejecutan `chroot $ROOT /bin/sh -c "<línea>"`
  (`src/libcalamares/utils/CommandList.cpp:262`). Una línea que empieza por `-`
  ignora errores. `${ROOT}` se expande al punto de montaje y `${USER}` al login
  (`CommandList.cpp:104-114`).

## Resumen de la secuencia `exec`

Fuente: `settings_online.conf:70-104` (el que copia `calamares-online.sh` como
`/etc/calamares/settings.conf`). En la columna "¿Actúa?": **sí** = hace algo con
nuestras opciones; *no-op* = se ejecuta pero no hace nada.

| # | Módulo | ¿Actúa? | Efecto |
|---|---|---|---|
| 0 | (`calamares-online.sh`) | sí | Llavero de pacman en el live, NTP |
| 1 | `partition` | sí | GPT, ESP FAT32 de 2 GiB, LUKS2 + btrfs |
| 2 | `zfs` | no-op | — |
| 3 | `mount` | sí | Subvolúmenes btrfs, montajes del target y de API |
| 4 | `shellprocess@modify_mk_hook` | sí | Desactiva `mkinitcpio` durante la instalación de paquetes |
| 5 | `shellprocess@initialize_pacman` | sí | Ordena mirrors y refresca llaveros en el live; los copia al target |
| 6 | `shellprocess@before-online` | sí | `pacman.conf` del target + repos optimizados según la CPU |
| 7 | `pacstrap` | sí | `pacman --sysroot` con la lista base; copia ficheros del live |
| 8 | `machineid` | sí | machine-id, random-seed, enlace dbus |
| 9 | `users` | sí | sudoers, grupos, usuario, contraseñas, hostname |
| 10 | `locale` | sí | `/etc/localtime`, `/etc/timezone` |
| 11 | `keyboard` | sí | `vconsole.conf`, `00-keyboard.conf`, `/etc/default/keyboard` |
| 12 | `localecfg` | sí | `locale.gen`, `locale-gen`, `locale.conf`, `/etc/default/locale` |
| 13 | `chwd` | sí | Drivers según el hardware |
| 14 | `packages@online` | sí | `pacman -Sy`, `-Su` y paquetes de netinstall |
| 15 | `luksbootkeyfile` | no-op | `/boot` sin cifrar → no hay keyfile |
| 16 | `luksopenswaphookcfg` | no-op | Sin swap |
| 17 | `fstab` | sí | `fstab` y `crypttab` |
| 18 | `plymouthcfg` | sí | Tema de plymouth |
| 19 | `zfshostid` | no-op | — |
| 20 | `initcpiocfg` | sí | `mkinitcpio.conf` (HOOKS con `sd-encrypt`) |
| 21 | `initcpio` | sí | `mkinitcpio -P` |
| 22 | `networkcfg` | sí | Conexiones de NetworkManager y `resolv.conf` del live |
| 23 | `displaymanager` | no-op | Sin DM instalado |
| 24 | `hwclock` | sí | `hwclock --systohc --utc` |
| 25 | `grubcfg` | no-op | No es GRUB |
| 26 | `bootloader` | sí | `bootctl install`, `kernel-install`, `loader.conf` |
| 27 | `shellprocess@reset_mk_hook` | sí | Restaura los hooks de `mkinitcpio` |
| 28 | `services-systemd` | sí | `systemctl enable/disable` |
| 29 | `shellprocess` | sí | Limpieza del live, skel, shell fish, `sdboot-manage gen` |
| 30 | `shellprocess@enable_ufw` | sí | ufw activado |
| 31 | `shellprocess@greetd` | no-op | — |
| 32 | `shellprocess@btrfs_snapshot` | no-op | Sin snapper (systemd-boot no lo instala) |
| 33 | `shellprocess@cleanup_calamares` | sí | Borra `/etc/calamares` del target |
| 34 | `umount` | sí | `umount -lv` de todo |

---

## Paso 0: en el live, antes de abrir Calamares

`iso:archiso/airootfs/usr/local/bin/calamares-online.sh:3-49`:

```bash
rm -rf /etc/pacman.d/gnupg
pacman -Sy --noconfirm archlinux-keyring cachyos-keyring
pacman-key --init
pacman-key --populate archlinux cachyos
timedatectl set-ntp true
pacman -Sy --noconfirm cachyos-calamares-next      # (solo para Calamares)
```

Durante la fase interactiva, al elegir la zona, Calamares también ejecuta en el
live `timedatectl set-timezone Europe/Madrid`
(`src/modules/locale/Config.cpp:213-216`). No afecta al target.

## Paso 1: `partition` (borrar disco + btrfs + cifrado)

### Qué decide Calamares

- Tabla **GPT** (`partition.conf:58`).
- **ESP**: FAT32, **2048 MiB**, montada en **`/boot`** (`partition.conf:9-11`;
  systemd-boot no tiene entrada en `bootloaderOverrides`, `partition.conf:65-83`,
  así que valen los valores generales). Empieza en **2 MiB**
  (`core/PartitionActions.cpp:130`), sin etiqueta y sin cifrar.
- **Raíz**: desde el final de la ESP hasta el último sector utilizable (total
  − 67 sectores, redondeado a 4 KiB, `PartitionActions.cpp:144-145`). Ocupa el
  100 % del resto (layout por defecto, `core/PartitionLayout.cpp:136`). LUKS2
  (`partition.conf:34`) con btrfs dentro, sin etiqueta.
- Sin swap. Sin partición BIOS boot (UEFI).

### Jobs (`core/PartitionCoreModule.cpp:647-697`)

1. `AutoMountManagementJob`: desactiva el automontaje de KDE/Solid (no-op en una
   ISO de consola).
2. `ClearTempMountsJob`: desmonta restos de `/tmp/calamares-*`.
3. `ClearMountsJob` sobre el disco (`jobs/ClearMountsJob.cpp:397-412`): cierra
   mappers LUKS (`cryptsetup close`), desmonta LVs, desactiva VGs
   (`vgchange -an`), desmonta las particiones del disco y regenera las swaps
   (`mkswap -U <uuid>`).
4. `CreatePartitionTableJob` → `CreatePartitionJob` (ESP) → `SetPartFlagsJob`
   (ESP) → `CreatePartitionJob` (raíz cifrada).
5. `FillGlobalStorageJob`: guarda en GlobalStorage los datos de cada partición
   que usan los módulos siguientes: `uuid` (del fs interior), `luksMapperName`,
   `luksUuid`, `luksPassphrase`.

Tras cada operación KPMcore refresca el kernel y udev:
`udevadm settle`, `partx --update $DEV`, `udevadm trigger --subsystem-match=block`
(`kpmcore:src/plugins/sfdisk/sfdiskpartitiontable.cpp:49-58`).

### Comandos equivalentes (KPMcore `v26.08.3`)

```bash
# --- limpieza previa (ClearMountsJob) ---
swapoff/umount de las particiones de $DEV; cryptsetup close de mappers sobre $DEV

# --- tabla (kpmcore:src/plugins/sfdisk/sfdiskdevice.cpp:63-66) ---
printf 'label: gpt\nwrite\n' | sfdisk --wipe=always "$DEV"

# --- ESP (NewOperation: kpmcore:src/ops/newoperation.cpp:66-110) ---
# CreatePartitionJob (sfdiskpartitiontable.cpp:74-76); sectores para disco de 512 B lógicos:
printf 'start=4096 size=4194304\nwrite\n' | sfdisk --force --append "$DEV"
# CreateFileSystemJob (kpmcore:src/fs/fat12.cpp:159-189)
mkfs.fat -F32 -I -v "$ESP"
sfdisk --part-type "$DEV" 1 EBD0A0A2-B9E5-4433-87C0-68B6B72699C7   # tipo por fs (createfilesystemjob.cpp:62, typemap :173)
# SetFileSystemLabelJob (etiqueta vacía → quita etiqueta, fat12.cpp:139-145)
fatlabel "$ESP" -r
# CheckFileSystemJob (fat12.cpp:148-152)
fsck.fat -a -w -v "$ESP"
# SetPartFlagsJob ESP (sfdiskpartitiontable.cpp:281-283)
sfdisk --part-type "$DEV" 1 C12A7328-F81F-11D2-BA4B-00A0C93EC93B

# --- raíz cifrada ---
printf 'start=4198400 size=<hasta último sector alineado>\nwrite\n' | sfdisk --force --append "$DEV"
# CreateFileSystemJob → luks2::create (kpmcore:src/fs/luks2.cpp:42-66)
printf '%s\n' "$PASS" | cryptsetup --use-random --sector-size 4096 --key-size 512 \
    --hash sha512 --batch-mode --force-password --type luks2 luksFormat "$CRYPT"
printf '%s\n' "$PASS" | cryptsetup open "$CRYPT" "luks-$(cryptsetup luksUUID "$CRYPT")"   # luks.cpp:469-471
mkfs.btrfs --force "/dev/mapper/$MAPPER"                                           # btrfs.cpp:137-160
sfdisk --part-type "$DEV" 2 0FC63DAF-8483-4772-8E79-3D69D8477DE4   # luks abierto informa btrfs → "Linux filesystem"
btrfs filesystem label "/dev/mapper/$MAPPER" ""                    # btrfs.cpp:207-211 (vía luks::writeLabel)
btrfs check "/dev/mapper/$MAPPER"                                  # btrfs.cpp:131-135 (vía luks::check)
```

Notas:

- No se pasa `--pbkdf`: Calamares no lo fija, así que se usa el de cryptsetup
  por defecto (argon2id). KPMcore escribe `passphrase + '\n'` por stdin; sin
  `--key-file`, cryptsetup lee hasta el primer salto de línea.
- El mapper **queda abierto** con el nombre `luks-<UUID LUKS>`, que es el que
  aparece luego en `fstab`, `crypttab` y la cmdline.
- En discos 4Kn los sectores cambian: 2 MiB = 512 sectores. Conviene calcular
  en bytes: inicio de ESP = 2 MiB, ESP = 2048 MiB y raíz hasta el final
  alineado a 4 KiB.
- Las particiones GPT no llevan nombre (`PARTLABEL`).

## Paso 3: `mount`

`src/modules/mount/main.py:342-403` con `mount.conf:10-64`. Se monta por orden
lexicográfico del punto de montaje.

```bash
ROOT=$(mktemp -d /tmp/calamares-root-XXXXXXXX)
O=defaults,noatime,compress=zstd:1      # NVMe; SSD/HDD SATA: compress=zstd (mount.conf:52-56, main.py:115-122)

mount -t btrfs -o "$O" "/dev/mapper/$MAPPER" "$ROOT"        # nivel superior
for sv in @ @home @root @srv @cache @tmp @log; do btrfs subvolume create "$ROOT/$sv"; done
chmod 750 "$ROOT/@root"                                       # main.py:299-300
umount -v "$ROOT"

mount -t btrfs -o "subvol=/@,$O"      "/dev/mapper/$MAPPER" "$ROOT"
mount -t btrfs -o "subvol=/@home,$O"  "/dev/mapper/$MAPPER" "$ROOT/home"      # mkdir -p implícito
mount -t btrfs -o "subvol=/@root,$O"  "/dev/mapper/$MAPPER" "$ROOT/root"
mount -t btrfs -o "subvol=/@srv,$O"   "/dev/mapper/$MAPPER" "$ROOT/srv"
mount -t btrfs -o "subvol=/@cache,$O" "/dev/mapper/$MAPPER" "$ROOT/var/cache"
mount -t btrfs -o "subvol=/@tmp,$O"   "/dev/mapper/$MAPPER" "$ROOT/var/tmp"
mount -t btrfs -o "subvol=/@log,$O"   "/dev/mapper/$MAPPER" "$ROOT/var/log"
mount -t vfat  -o defaults,umask=0077 "$ESP" "$ROOT/boot"                    # opciones "efi"

mount --bind /dev "$ROOT/dev"
mount -t proc proc "$ROOT/proc"
mount -t tmpfs tmpfs "$ROOT/run"
mount --bind /run/udev "$ROOT/run/udev"
mount -t sysfs sys "$ROOT/sys"
mount -t efivarfs efivarfs "$ROOT/sys/firmware/efi/efivars"
```

- La SSD se detecta con `/sys/block/<disco>/queue/rotational == 0` y NVMe por el
  prefijo `nvme` del dispositivo de la partición (`main.py:60-74`, `:115-122`).
  **Ojo**: con LUKS la partición que se mira es la física (`partition["device"]`,
  p. ej. `nvme0n1p2`), no el mapper, así que la detección funciona.
- `@` se registra como `btrfsRootSubvolume` (`main.py:302-304`) para la cmdline.
- `/tmp` no es subvolumen; puede acabar como tmpfs en `fstab` (Paso 17).

## Paso 4: `shellprocess@modify_mk_hook`

`src/modules/shellprocess/shellprocess_modify_mk_hook.conf` (en el live):

```bash
mkdir -p /etc/pacman.d/hooks/
cp /etc/calamares/scripts/90-mkinitcpio-install.hook /etc/pacman.d/hooks/        # en el live
mkdir -p "$ROOT/usr/share/libalpm/scripts/"
cp /etc/calamares/scripts/mkinitcpio-install-calamares "$ROOT/usr/share/libalpm/scripts/"
chmod +x "$ROOT/usr/share/libalpm/scripts/mkinitcpio-install-calamares"
mkdir -p "$ROOT/etc/pacman.d/hooks/"
cp /etc/calamares/scripts/90-mkinitcpio-install.hook "$ROOT/etc/pacman.d/hooks/"
```

El hook (`src/scripts/90-mkinitcpio-install.hook`) tiene el mismo nombre que el
de `mkinitcpio`, así que lo **sustituye**. Llama a `mkinitcpio-install-calamares`
(`src/scripts/mkinitcpio-install-calamares:1-40`), que para cada kernel instalado:

- crea `/etc/mkinitcpio.d/<pkgbase>.preset` desde `/usr/share/mkinitcpio/hook.preset`
  si no existe (o recupera el `.pacsave`);
- copia el kernel a `/boot/vmlinuz-<pkgbase>`;
- monta la lista de argumentos para `mkinitcpio`… **pero nunca lo ejecuta**.

Efecto: mientras se instalan paquetes no se genera ningún initramfs. Se genera
una sola vez en el Paso 21.

## Paso 5: `shellprocess@initialize_pacman`

`shellprocess_initialize_pacman.conf` (en el live):

```bash
# update-mirrorlist (src/scripts/update-mirrorlist)
pacman -Sy --noconfirm --needed cachyos-rate-mirrors rate-mirrors
cachyos-rate-mirrors                      # reescribe los mirrorlist del live

# create-pacman-keyring (src/scripts/create-pacman-keyring)
pacman-key --init
for i in 1..5: pacman -Sy --noconfirm --needed cachyos-keyring && break
for i in 1..5: pacman -Sy --noconfirm --needed archlinux-keyring && break
pacman-key --populate

mkdir -p "$ROOT/etc/pacman.d/"
cp /etc/pacman.d/{mirrorlist,cachyos-mirrorlist,cachyos-v3-mirrorlist,cachyos-v4-mirrorlist} "$ROOT/etc/pacman.d/"
cp -a /etc/pacman.d/gnupg "$ROOT/etc/pacman.d/"
cp /etc/resolv.conf "$ROOT/etc/"
```

## Paso 6: `shellprocess@before-online`

`shellprocess-before-online.conf` (en el live):

```bash
cp /etc/pacman-more.conf "$ROOT/etc/pacman.conf"
/etc/calamares/scripts/detect-architecture "$ROOT/etc/pacman.conf"
```

- `pacman-more.conf` es `iso:archiso/airootfs/etc/pacman-more.conf`:
  `[cachyos]`, `[core]`, `[extra]`, `[multilib]`, `ParallelDownloads = 10`,
  `SigLevel = Required DatabaseOptional`. Nuestra ISO lo conserva (no está en
  `remove.list`).
- `detect-architecture` (`src/scripts/detect-architecture:1-68`) inserta antes de
  `[cachyos]`:
  - Zen 4 (familia 0x19 con modelos 0x10-0x1f o 0x60-0xaf) o Zen 5 (familia
    0x1a), con `avx512f`: `[cachyos-znver4]`, `[cachyos-core-znver4]`,
    `[cachyos-extra-znver4]` (mirrorlist v4);
  - si no, CPU x86-64-v4: `[cachyos-v4]`, `[cachyos-extra-v4]`, `[cachyos-core-v4]`;
  - si no, CPU x86-64-v3: `[cachyos-v3]`, `[cachyos-extra-v3]`, `[cachyos-core-v3]`.

## Paso 7: `pacstrap`

`src/modules/pacstrap/main.py:69-199`. Lista base: `pacstrap.conf:13-57`. Se
añade según las opciones (`main.py:94-155`):

- kernels: `linux-cachyos linux-cachyos-headers linux-cachyos-lts linux-cachyos-lts-headers`;
- systemd-boot: `systemd-boot-manager`;
- microcódigo: `intel-ucode` si `vendor_id` es `GenuineIntel`; si no, `amd-ucode`;
- btrfs + systemd-boot: **nada** (snapper, `btrfs-assistant` y
  `*-snapper-*` solo con limine, grub o refind).

```bash
# antes: borra /boot/{intel,amd}-ucode.img si existen (main.py:157-166)
/etc/calamares/scripts/pacstrap_calamares -c "$ROOT" \
  base base-devel btrfs-progs cachyos-hooks cachyos-keyring cachyos-mirrorlist \
  cachyos-v4-mirrorlist cachyos-v3-mirrorlist cachyos-rate-mirrors cachyos-settings \
  cryptsetup device-mapper diffutils dosfstools e2fsprogs efibootmgr exfatprogs \
  f2fs-tools inetutils jfsutils less linux-firmware logrotate lsb-release lvm2 \
  man-db man-pages mdadm chwd mkinitcpio netctl os-prober perl python s-nail sudo \
  sysfsutils texinfo usbutils which xfsprogs plymouth cachyos-plymouth-bootanimation \
  cachyos-plymouth-theme \
  linux-cachyos linux-cachyos-headers linux-cachyos-lts linux-cachyos-lts-headers \
  systemd-boot-manager {intel|amd}-ucode
```

`pacstrap_calamares` (`src/scripts/pacstrap_calamares:345-358`) es un pacstrap
recortado: no monta nada (ya lo hizo `mount`) ni copia llavero o mirrorlist (ya
lo hizo el Paso 5). En la práctica:

```bash
mkdir -m 0755 -p "$ROOT"/var/{cache/pacman/pkg,lib/pacman,log} "$ROOT"/{dev,run,etc/pacman.d}
mkdir -m 1777 -p "$ROOT"/tmp
mkdir -m 0555 -p "$ROOT"/{sys,proc}
pacman --sysroot "$ROOT" -Sy <paquetes> --noconfirm --needed
```

- `--sysroot` hace que pacman use **el `pacman.conf`, el llavero, los mirrorlist
  y los hooks del target** (los de los Pasos 4-6). Los paquetes se descargan en
  `$ROOT/var/cache/pacman/pkg` (subvolumen `@cache`) y **se quedan en el sistema
  instalado**.
- Como `pacman.conf` y los mirrorlist ya existen, los paquetes `pacman`,
  `pacman-mirrorlist` y `cachyos-*mirrorlist` dejan sus versiones como
  `.pacnew`. Lo mismo pasa con `/etc/resolv.conf`.

Después copia ficheros del live al target (`main.py:179-193`,
`pacstrap.conf:65-72`) con `shutil.copy2`:

```bash
cp -a /etc/mkinitcpio.conf                          "$ROOT/etc/mkinitcpio.conf"   # del paquete mkinitcpio del live
cp -a /etc/calamares/scripts/{dmcheck,enable-ufw,bootloader-post-setup,shell-setup,btrfs-installation-snapshot} \
      "$ROOT/etc/calamares/scripts/"
cp -a /usr/local/bin/remove-nvidia                  "$ROOT/usr/local/bin/"        # se queda en el target (ver hallazgos)
```

En la ISO oficial no hay un `/etc/mkinitcpio.conf` propio en `airootfs` (solo
`mkinitcpio.conf.d/archiso.conf`, que no se copia). El fichero copiado es el
del paquete y el Paso 20 reescribe sus `HOOKS`.

Hooks de pacman que se disparan aquí y son relevantes:

- el `90-mkinitcpio-install.hook` sustituido (Paso 4);
- `sdboot-kernel-update.hook` de `systemd-boot-manager` (`sdboot-manage autogen`).
  Falla sin consecuencias: aún no hay `loader.conf`
  (`pkgbuilds:systemd-boot-manager/sdboot-manage:282-284`).

## Paso 8: `machineid`

`machineid.conf:13-30`, `Workers.cpp:143-190`:

```bash
rm -f "$ROOT"/etc/machine-id "$ROOT"/var/lib/dbus/machine-id \
      "$ROOT"/var/lib/urandom/random-seed "$ROOT"/var/lib/systemd/random-seed
mkdir -p "$ROOT"/var/lib/urandom "$ROOT"/var/lib/systemd
head -c 512 /dev/urandom > "$ROOT/var/lib/urandom/random-seed"    # max(poolsize, 512) bytes
head -c 512 /dev/urandom > "$ROOT/var/lib/systemd/random-seed"
systemd-machine-id-setup --root="$ROOT"                            # en el live
chroot "$ROOT" ln -sf /etc/machine-id /var/lib/dbus/machine-id
```

Los ficheros de entropía se crean con la umask de Calamares (no se fuerza
`0600`). En el sistema de referencia, `systemd-random-seed` ya los ha
reescrito con `0600`.

## Paso 9: `users`

Jobs en orden (`src/modules/users/Config.cpp:1084-1126`), todos en el target:

```bash
# SetupSudoJob (MiscJobs.cpp:51-72; sudoersConfigureWithGroup=false → "(ALL)")
printf '%%wheel ALL=(ALL) ALL\n' > "$ROOT/etc/sudoers.d/10-installer"; chmod 0440 …

# SetupGroupsJob (MiscJobs.cpp:130-206): groupadd de los grupos que falten
chroot "$ROOT" groupadd --system nopasswdlogin       # único que no existe en Arch

# CreateUserJob (CreateUserJob.cpp:63-76, 97-98, 166)
chroot "$ROOT" useradd -m -U -s /bin/bash -c "$FULLNAME" -K UMASK=077 "$USER"
chroot "$ROOT" usermod -aG wheel,rfkill,sys,users,lp,video,network,storage,wheel,audio,nopasswdlogin "$USER"
chroot "$ROOT" chown -R "$USER:$USER" "/home/$USER"

# SetPasswordJob ×2 (SetPasswordJob.cpp:84-104): crypt() con crypt_gensalt(NULL) → yescrypt ($y$)
chroot "$ROOT" usermod -p "$(hash yescrypt de $PASS)" "$USER"
chroot "$ROOT" usermod -p "$(hash yescrypt de $ROOTPASS)" root   # por defecto ROOTPASS=PASS

# SetHostNameJob (SetHostNameJob.cpp:52-73; hostname location EtcFile, writeHostsFile true)
echo "$HOSTNAME" > "$ROOT/etc/hostname"
cat > "$ROOT/etc/hosts" <<EOF
# Standard host addresses
127.0.0.1  localhost
::1        localhost ip6-localhost ip6-loopback
ff02::1    ip6-allnodes
ff02::2    ip6-allrouters
# This host address
127.0.1.1  $HOSTNAME
EOF
```

- Grupos: `users.conf:17-34`. `wheel` aparece dos veces y `usermod` lo acepta.
- **El usuario entra en `nopasswdlogin`**: `groupsForThisUser()` mete todos los
  `defaultGroups` (`Config.cpp:179-198`), y en ese `users.conf` está
  `nopasswdlogin`. Confirmado en esta máquina (ver
  [Evidencia](#evidencia-empírica)).
- Equivalente de consola para la contraseña: `chpasswd` (Arch usa yescrypt por
  defecto en `login.defs`) o `usermod -p "$(openssl passwd -6 …)"`. Para el mismo
  algoritmo exacto, generar el hash yescrypt (p. ej. `mkpasswd -m yescrypt`).
- `/home/$USER` queda con `0700` (umask 077).

## Paso 10: `locale` (zona horaria)

`SetTimezoneJob.cpp:36-88`. Calamares hace chroot (`dont-chroot: false`), así
que no usa `timedatectl`:

```bash
chroot "$ROOT" rm -f /etc/localtime
chroot "$ROOT" ln -s /usr/share/zoneinfo/Europe/Madrid /etc/localtime
echo "Europe/Madrid" > "$ROOT/etc/timezone"
```

## Paso 11: `keyboard`

`SetKeyboardLayoutJob.cpp:417-497`. `convertedKeymapPath` apunta a
`/lib/kbd/keymaps/xkb` (`keyboard.conf:18`), que no existe en Arch. Por eso se
usa la tabla `kbd-model-map` (línea 74: `es es pc105 - …`) y resulta
`KEYMAP=es`.

```bash
# vconsole.conf (writeVConsoleData, :244-336): conserva otras líneas y sustituye KEYMAP/XKB*
cat > "$ROOT/etc/vconsole.conf" <<EOF
KEYMAP=es
XKBLAYOUT=es
XKBMODEL=pc105
EOF

# 00-keyboard.conf (writeX11Data, :338-377): sin XkbModel
mkdir -p "$ROOT/etc/X11/xorg.conf.d"
cat > "$ROOT/etc/X11/xorg.conf.d/00-keyboard.conf" <<'EOF'
# Read and parsed by systemd-localed. It's probably wise not to edit this file
# manually too freely.
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "es"
        Option "XkbVariant" ""
EndSection
EOF

# /etc/default/keyboard (writeDefaultKeyboardData, :379-410); /etc/default existe (shadow)
cat > "$ROOT/etc/default/keyboard" <<'EOF'
# KEYBOARD CONFIGURATION FILE

# Consult the keyboard(5) manual page.

XKBMODEL="pc105"
XKBLAYOUT="es"
XKBVARIANT=""
BACKSPACE="guess"
EOF
```

No hay `FONT=` en `vconsole.conf`.

## Paso 12: `localecfg`

`src/modules/localecfg/main.py:116-175`. `localeConf` lleva `LANG` y las nueve
`LC_*` (`locale/LocaleConfiguration.cpp:320-336`). Se recorren en orden
alfabético porque vienen de un `QMap`.

```bash
# rewrite_locale_gen (main.py:65-113): NO descomenta en su sitio; añade al final
cat >> "$ROOT/etc/locale.gen" <<'EOF'

###
#
# Locales enabled by Calamares
en_US.UTF-8 UTF-8
es_ES.UTF-8 UTF-8
EOF
chroot "$ROOT" locale-gen

for f in "$ROOT/etc/locale.conf" "$ROOT/etc/default/locale"; do
cat > "$f" <<'EOF'
LANG=es_ES.UTF-8
LC_ADDRESS=es_ES.UTF-8
LC_IDENTIFICATION=es_ES.UTF-8
LC_MEASUREMENT=es_ES.UTF-8
LC_MONETARY=es_ES.UTF-8
LC_NAME=es_ES.UTF-8
LC_NUMERIC=es_ES.UTF-8
LC_PAPER=es_ES.UTF-8
LC_TELEPHONE=es_ES.UTF-8
LC_TIME=es_ES.UTF-8
EOF
done
```

`en_US.UTF-8` se activa siempre (`main.py:71,84`). El orden exacto de las dos
líneas añadidas depende del orden en que aparecen en `locale.gen`.

## Paso 13: `chwd`

`src/modules/chwd/main.py:80-89`:

```bash
arch-chroot "$ROOT" chwd --autoconfigure
```

Instala los drivers y perfiles que correspondan al hardware real (GPU, etc.).
Es el único paso con `arch-chroot`.

## Paso 14: `packages@online` (netinstall)

`packages_online.conf` (`update_db`, `update_system`, `num_retries: 6`,
`disable_download_timeout`, `needed_only`) y `packages/main.py:487-524`. Todo en
el target y con hasta 6 reintentos:

```bash
chroot "$ROOT" pacman -Sy
chroot "$ROOT" pacman -Su --noconfirm --disable-download-timeout
# grupos críticos seleccionados → una transacción
chroot "$ROOT" pacman -S --noconfirm --noprogressbar --needed --disable-download-timeout <lista>
# grupos no críticos seleccionados → paquete a paquete, ignorando fallos (try_install)
chroot "$ROOT" pacman -S --noconfirm --noprogressbar --needed --disable-download-timeout cachyos-fish-config
chroot "$ROOT" pacman -S … cachyos-zsh-config
chroot "$ROOT" pacman -S … firefox
chroot "$ROOT" pacman -S … firefox-i18n-<locale>
```

Con *No Desktop* no se añade ningún grupo de escritorio, pero entran **todos
los grupos preseleccionados** de `src/modules/netinstall/netinstall.yaml`
(copia de `199d71543`):

| Grupo | Crítico | Paquetes |
|---|---|---|
| CachyOS required (oculto) | sí | `cachyos-hooks cachyos-keyring cachyos-mirrorlist cachyos-v3-mirrorlist cachyos-v4-mirrorlist cachyos-rate-mirrors chwd` |
| CachyOS kernels (oculto, desktop) | sí | `linux-cachyos linux-cachyos-headers linux-cachyos-lts linux-cachyos-lts-headers` |
| CachyOS Packages (`:34`) | sí | `cachyos-hello cachyos-kernel-manager cachyos-packageinstaller cachyos-settings cachyos-micro-settings cachyos-wallpapers` |
| Base-devel + Common packages (`:53`) | sí | subgrupos Network, firewall (`ufw ufw-extras`), bluetooth, packages management, desktop integration, filesystem, fonts, audio, hardware, power, applications (`alacritty btop … openssh`) |
| CachyOS shell configuration (`:46`) | no | `cachyos-fish-config cachyos-zsh-config` |
| Firefox and language package (`:833`) | no | `firefox firefox-i18n-$LOCALE` |

`$LOCALE` se sustituye por el BCP47 del idioma elegido (GlobalStorage
`locale`, `packages/main.py:656-697`). Hay que comprobar en VM qué valor da con
español de España (`firefox-i18n-es-es` existe; `es-ES` no casaría).

La lista crítica literal que generó Calamares está en el `pacman.log` de esta
máquina (ver [Evidencia](#evidencia-empírica)).

## Paso 15-16: `luksbootkeyfile`, `luksopenswaphookcfg` (no-op)

- `luksbootkeyfile`: con `/boot` sin cifrar sale sin crear
  `/crypto_keyfile.bin` (`LuksBootKeyFileJob.cpp:287-291`). **No hay keyfile**.
  El initramfs pide la contraseña.
- `luksopenswaphookcfg`: sin swap cifrada, `LOSHInfo` no es válido y no escribe
  `/etc/openswap.conf` (`LOSHJob.cpp:55-70`).

## Paso 17: `fstab` (y `crypttab`)

`src/modules/fstab/main.py:193-310` y `:130-191`; `fstab.conf`:
`crypttabOptions: luks`, `tmpOptions.ssd.tmpfs: true`.

`$ROOT/etc/fstab` (ancho de columnas `{:41} {:<14} {:<7} {:<10} 0 {}`):

```
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a device; this may
# be used with UUID= as a more robust way to name devices that works even if
# disks are added and removed. See fstab(5).
#
# <file system>             <mount point>  <type>  <options>  <dump>  <pass>
UUID=<UUID-ESP>                           /boot          vfat    defaults,umask=0077 0 2
/dev/mapper/luks-<UUID-LUKS>              /              btrfs   subvol=/@,defaults,noatime,compress=zstd:1 0 0
/dev/mapper/luks-<UUID-LUKS>              /home          btrfs   subvol=/@home,defaults,noatime,compress=zstd:1 0 0
/dev/mapper/luks-<UUID-LUKS>              /root          btrfs   subvol=/@root,defaults,noatime,compress=zstd:1 0 0
/dev/mapper/luks-<UUID-LUKS>              /srv           btrfs   subvol=/@srv,defaults,noatime,compress=zstd:1 0 0
/dev/mapper/luks-<UUID-LUKS>              /var/cache     btrfs   subvol=/@cache,defaults,noatime,compress=zstd:1 0 0
/dev/mapper/luks-<UUID-LUKS>              /var/tmp       btrfs   subvol=/@tmp,defaults,noatime,compress=zstd:1 0 0
/dev/mapper/luks-<UUID-LUKS>              /var/log       btrfs   subvol=/@log,defaults,noatime,compress=zstd:1 0 0
tmpfs                                     /tmp           tmpfs   defaults,noatime,mode=1777 0 0
```

- Las particiones cifradas usan `/dev/mapper/<mapper>`, no `UUID=`
  (`main.py:282-288`).
- `pass` es 2 para vfat y 0 para btrfs (`main.py:268-273`).
- La línea **tmpfs `/tmp`** solo aparece si el disco de la raíz no es rotacional
  (`main.py:220-239`). En NVMe sí aparece.

`$ROOT/etc/crypttab` (`main.py:144-191`). Como `/boot` no está cifrado,
`password = none` y las opciones quedan **vacías** (`main.py:169-174`). El
`luks` de `crypttabOptions` no llega a usarse:

```
# /etc/crypttab: mappings for encrypted partitions.
# … (cabecera, main.py:40-52) …
# <name>               <device>                         <password> <options>
luks-<UUID-LUKS>      UUID=<UUID-LUKS>                              none 
```

Con `sd-encrypt` el initramfs no lee esta línea (lee `rd.luks.uuid` de la
cmdline). El `crypttab` del sistema solo lo usa systemd tras el *switch-root*,
y ve el dispositivo ya abierto.

## Paso 18: `plymouthcfg`

`plymouthcfg.conf`, `main.py:70-78`:

```bash
chroot "$ROOT" plymouth-set-default-theme cachyos-bootanimation   # o "cachyos" si `chwd --check amd` (en el live) detecta GPU AMD
```

## Paso 20: `initcpiocfg`

`src/modules/initcpiocfg/main.py:84-239`, `initcpiocfg.conf` (`useSystemdHook:
true`; los `bogus` de prepend/append se anulan con remove). Lee el
`/etc/mkinitcpio.conf` **del live** y escribe el del target cambiando solo las
líneas `HOOKS`, `MODULES`, `BINARIES` y `FILES`. Además quita la sangría de
todas las líneas (`.strip()`).

```
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base systemd autodetect microcode kms modconf block keyboard sd-vconsole plymouth sd-encrypt filesystems)
```

- `systemd` porque existe `systemd-cat` en el target (`main.py:121-126`).
- `plymouth` porque existe `plymouth` (`:153-154`).
- `sd-encrypt` porque `/` lleva `luksMapperName` (`:173-186`).
- Sin `fsck` porque hay btrfs (`:204-205`). Sin `resume` porque no hay swap.

## Paso 21: `initcpio`

`InitcpioJob.cpp:41-87`, `initcpio.conf` (`kernel: all`):

```bash
chmod 600 "$ROOT"/boot/initramfs*            # fixPermissions (si ya hubiera alguno)
(umask 077; chroot "$ROOT" mkinitcpio -P)    # UMask::Safe → initramfs 0600
```

Los presets los creó `mkinitcpio-install-calamares` (Paso 4) a partir de
`hook.preset`, y los kernels ya están en `/boot/vmlinuz-<pkgbase>`. Salen
`/boot/initramfs-linux-cachyos.img` y `/boot/initramfs-linux-cachyos-lts.img`
(el `hook.preset` actual de Arch ya no genera *fallback*).

## Paso 22: `networkcfg`

`src/modules/networkcfg/main.py:96-187`:

```bash
# copia las conexiones guardadas en el live que no existan en el target (p. ej. wifi configurada con nmtui)
cp -n /etc/NetworkManager/system-connections/* "$ROOT/etc/NetworkManager/system-connections/"
#   y sustituye "permissions=user:<liveuser>:;" por el usuario instalado
rm -f "$ROOT/etc/resolv.conf"; cp -P /etc/resolv.conf "$ROOT/etc/resolv.conf"   # copia el enlace si lo es
```

Netplan no aplica.

## Paso 24: `hwclock`

`src/modules/hwclock/main.py:33-54`:

```bash
chroot "$ROOT" hwclock --systohc --utc || chroot "$ROOT" hwclock --systohc --utc --directisa
```

Escribe la hora del sistema (sincronizada por NTP en el Paso 0) en el RTC y
crea `/etc/adjtime` con `UTC`.

## Paso 26: `bootloader` (systemd-boot)

`src/modules/bootloader/main.py:547-571` (`install_systemd_boot`),
`bootloader.conf` (`kernelParams: [quiet, nowatchdog]`,
`loaderEntries: [timeout 5, console-mode keep]`):

```bash
# 1. en el LIVE (subprocess, no chroot) y sin --root:
bootctl --path="$ROOT/boot" install

# 2. por cada vmlinuz de $ROOT/usr/lib/modules/*/ (orden de os.walk):
echo -n "$CMDLINE" > "$ROOT/etc/kernel/cmdline"
mkdir -p "$ROOT/boot/$(cat $ROOT/etc/machine-id)"
chroot "$ROOT" kernel-install add <kver> /usr/lib/modules/<kver>/vmlinuz

# 3. loader.conf (create_loader, :256-283)
printf 'default @saved\ntimeout 5\nconsole-mode keep\n' > "$ROOT/boot/loader/loader.conf"
```

`CMDLINE` se forma en `get_kernel_params` (`main.py:141-219`), en este orden:

```
quiet nowatchdog splash rw rootflags=subvol=/@ rd.luks.uuid=<UUID-LUKS> root=/dev/mapper/luks-<UUID-LUKS>
```

- `splash` porque está plymouth.
- `rd.luks.uuid` (y no `cryptdevice=`) porque `HOOKS` contiene `systemd`
  (`:149`, `:173-177`).

Efectos de `kernel-install add` en el target: con `$BOOT/<machine-id>`
presente, el layout es BLS. Se ejecutan los plugins de
`/usr/lib/kernel/install.d/`: `50-depmod`, **`50-mkinitcpio`** (genera otro
initramfs, `mkinitcpio --nopost -k … -g <staging>/initrd`) y `90-loaderentry`.
Este último copia `linux` e `initrd` a `/boot/<machine-id>/<kver>/` y escribe
`/boot/loader/entries/<machine-id>-<kver>.conf`. Esas entradas se borran en el
Paso 29.

## Paso 27: `shellprocess@reset_mk_hook`

```bash
chroot "$ROOT" rm /etc/pacman.d/hooks/90-mkinitcpio-install.hook
chroot "$ROOT" rm /usr/share/libalpm/scripts/mkinitcpio-install-calamares
```

A partir de aquí vuelve a funcionar el hook normal de `mkinitcpio`. La copia
en el live (Paso 4) no se deshace, pero da igual.

## Paso 28: `services-systemd`

`services-systemd.conf`, `main.py:29-76`. En el target `systemctl <acción>
<unidad>`; los fallos se ignoran (ninguna unidad es `mandatory`).

| Unidad | Acción | ¿Instalada con nuestras opciones? |
|---|---|---|
| `NetworkManager` | enable | sí |
| `cups` | enable | no (Printing-Support no está preseleccionado) |
| `avahi-daemon` | enable | sí (dependencia de `nss-mdns`) |
| `systemd-timesyncd` | enable | sí |
| `vboxservice`, `vmtoolsd`, `vmware-vmblock-fuse` | enable | solo si `chwd` los instaló (VM) |
| `firewalld` | enable | no |
| `zfs-import-cache`, `zfs-mount`, `zfs-import.target`, `zfs.target` | enable | no |
| `fstrim.timer` | enable | sí |
| `pacman-init` | disable | no existe en el target |
| `multi-user.target` | disable | sin `[Install]`: no hace nada |
| `bluetooth` | enable | sí |
| `arch-update.timer` | `--global` enable | no (no está instalado) |

Otras unidades activas en un sistema recién instalado (p. ej. `systemd-resolved`,
`ananicy-cpp`, `systemd-oomd`, `cachyos-rate-mirrors.timer`) **no las activa
Calamares**, sino los scriptlets de los paquetes (`cachyos-settings`…). Se
replican solas al instalar los mismos paquetes.

## Paso 29: `shellprocess` (principal)

`shellprocess.conf`, en el target:

```bash
rm /etc/systemd/system/etc-pacman.d-gnupg.mount          # (-) no existe en el target
rm /etc/systemd/system/display-manager.service           # (-)
/etc/calamares/scripts/dmcheck                            # sin DM → no hace nada
rm /etc/calamares/scripts/dmcheck; rm /usr/local/bin/dmcheck   # (-)
rm -rf /home/liveuser                                     # (-)
runuser $USER -c "cp -rf /etc/skel/. /home/$USER/."       # (-) recopia skel: trae lo que añadieron paquetes posteriores al useradd
runuser $USER -c "rm -rf /home/$USER/{.xsession,.xprofile,.xinitrc}"   # (-)
/etc/calamares/scripts/shell-setup $USER                  # chsh -s /bin/fish $USER (fish existe → fish)
rm /etc/calamares/scripts/shell-setup
/etc/calamares/scripts/bootloader-post-setup
rm /etc/calamares/scripts/bootloader-post-setup
```

`bootloader-post-setup` (`src/scripts/bootloader-post-setup:29-32`), rama
systemd-boot:

```bash
pacman -Qq systemd-boot-manager && bootctl is-installed &&
  { rm -rf /boot/loader/entries/*; sdboot-manage gen; }
```

`sdboot-manage gen` (`pkgbuilds:systemd-boot-manager/sdboot-manage:277-371`,
config `sdboot-manage.conf`) genera **una entrada por kernel** a partir de
`/boot/vmlinuz-*` y `/boot/initramfs-*.img` (los del Paso 21):

```
# /boot/loader/entries/linux-cachyos.conf
title Linux CachyOS
options <contenido de /etc/kernel/cmdline> nowatchdog quiet splash
linux /vmlinuz-linux-cachyos
initrd /initramfs-linux-cachyos.img
```

y lo mismo para `linux-cachyos-lts` (`title Linux CachyOS Lts`). El microcódigo
no lleva línea `initrd` propia: va dentro del initramfs (hook `microcode`).
`LINUX_OPTIONS="nowatchdog quiet splash"` se **añade** a `/etc/kernel/cmdline`
(`sdboot-manage:298-307`), así que esos parámetros salen duplicados.

## Paso 30: `shellprocess@enable_ufw`

`src/scripts/enable-ufw` (ufw está instalado por el subgrupo *firewall*), en el
target:

```bash
systemctl enable ufw
ufw default deny incoming
ufw default allow outgoing
ufw enable
```

## Paso 32-33: snapshot y limpieza

- `btrfs-installation-snapshot` sale sin hacer nada: no está
  `cachyos-snapper-support`.
- Luego `rm` del script, `rmdir /etc/calamares/scripts` y `rmdir /etc/calamares`
  en el target.

## Paso 34: `umount`

`UmountJob.cpp:42-91`: `umount -lv` de cada punto bajo `$ROOT` (de más
profundo a menos) y al final `umount -lv $ROOT`. **No cierra el mapper LUKS**.

---

## Estado final esperado del target (resumen)

| Elemento | Valor |
|---|---|
| Particiones | `p1` ESP 2 GiB FAT32 (`C12A7328…`), `p2` LUKS2 (`0FC63DAF…`) |
| LUKS2 | `aes-xts-plain64` (por defecto), clave de 512 bits, sha512, argon2id, sector 4096, 1 keyslot (contraseña) |
| btrfs | `@ @home @root @srv @cache @tmp @log`; `@root` 0750 |
| `/etc/kernel/cmdline` | `quiet nowatchdog splash rw rootflags=subvol=/@ rd.luks.uuid=<U> root=/dev/mapper/luks-<U>` (ver hallazgo 1) |
| `mkinitcpio.conf` HOOKS | `base systemd autodetect microcode kms modconf block keyboard sd-vconsole plymouth sd-encrypt filesystems` |
| ESP | `EFI/systemd/`, `EFI/BOOT/BOOTX64.EFI`, `loader/loader.conf`, `loader/entries/linux-cachyos{,-lts}.conf`, `vmlinuz-*`, `initramfs-*.img`, `<machine-id>/<kver>/…` (hallazgo 2) |
| NVRAM | entrada "Linux Boot Manager" creada por `bootctl install` |
| Usuario | shell fish, grupos `wheel rfkill sys users lp video network storage audio nopasswdlogin`, home 0700 |
| sudo | `/etc/sudoers.d/10-installer`: `%wheel ALL=(ALL) ALL` |
| Locale/teclado/zona | ver Pasos 10-12 |
| Servicios activados por Calamares | NetworkManager, avahi-daemon, systemd-timesyncd, fstrim.timer, bluetooth, ufw |

## Hallazgos y peculiaridades

Se marca cada uno como **[verificado]** (en esta máquina) o **[deducido]** (del
código, pendiente de confirmar en VM).

1. **[deducido] Parámetros del kernel duplicados.** `get_kernel_params` hace
   `append` sobre la lista `kernelParams` de la configuración del job
   (`bootloader/main.py:145-147`, `:188`, `:204`). Con Boost.Python
   (`-DWITH_PYBIND11=OFF`) ese diccionario se crea una sola vez por job
   (`src/libcalamares/pyboost/PythonJobApi.cpp:134`), así que la segunda
   llamada (segundo kernel) repite `splash rw rootflags=… rd.luks.uuid=… root=…`.
   A eso `sdboot-manage gen` añade `nowatchdog quiet splash`. El kernel lo
   tolera (se queda con el último valor), pero la cmdline no queda limpia.
2. **[deducido] Restos en la ESP.** `kernel-install add` deja
   `/boot/<machine-id>/<kver>/{linux,initrd}` (dos kernels con sus initramfs,
   varios cientos de MiB). `bootloader-post-setup` solo borra
   `loader/entries/*`. `bootctl install` se ejecuta **en el live sin `--root`**:
   comprobar que no crea también un directorio con el machine-id del live.
3. **[deducido] Tres generaciones de initramfs.** `mkinitcpio -P` (Paso 21) y
   `kernel-install` (dos `mkinitcpio` más). Las que arranca son las del Paso 21.
4. **[verificado] `remove-nvidia` se queda en el target** como
   `/usr/local/bin/remove-nvidia`, sin dueño. El paso que lo ejecuta y borra
   (`shellprocess-before`) no está en la secuencia online.
5. **[verificado] Usuario en el grupo `nopasswdlogin`** aunque tenga
   contraseña. Ese grupo solo tiene efecto si algún DM o PAM lo usa para entrar
   sin contraseña.
6. **[verificado] Caché de paquetes** de toda la instalación en
   `/var/cache/pacman/pkg` (`pacstrap_calamares -c` con `--sysroot`).
7. **[verificado] `.pacnew`** de `pacman.conf`, los 4 mirrorlist y `resolv.conf`.
8. **[deducido] `ufw enable` dentro de un `chroot` actúa sobre el kernel del
   live** (mismo espacio de nombres de red). Desde ese momento el live rechaza
   conexiones entrantes, **incluido SSH**. Importa si en la Fase 4 se vigila la
   instalación por SSH.
9. `crypttab` sin opciones y sin keyfile; el desbloqueo lo hace `sd-encrypt`
   con `rd.luks.uuid`. Es el punto de partida natural para TPM2
   (`systemd-cryptenroll` + `tpm2-device=auto` en
   `/etc/crypttab.initramfs` o `rd.luks.options=`).
10. No se usa `genfstab` ni `arch-chroot` (salvo `chwd`). `fstab` y `crypttab`
    se escriben con formato propio.
11. El `90-mkinitcpio-install.hook` que queda en `/etc/pacman.d/hooks/` de esta
    máquina es de `limine-mkinitcpio-hook` (rama limine), no un resto de
    Calamares.

## Evidencia empírica

Esta máquina (`cachyhos`, VM VirtualBox) se instaló con este Calamares el
2026-11-14, en **BIOS, limine, sin cifrado y *No Desktop***. No coincide con
nuestro camino en bootloader, firmware ni cifrado, pero confirma:

- `/var/log/pacman.log:1` (pacstrap): la orden literal `pacman --sysroot
  /tmp/calamares-root-… -Sy --noconfirm --needed base base-devel … limine
  limine-entry-tool intel-ucode snapper btrfs-assistant limine-snapper-sync`.
- `pacman.log:490-501`: `pacman -Sy`, `pacman -Su --noconfirm
  --disable-download-timeout` y la transacción crítica de netinstall (CachyOS
  Packages + Base-devel/Common + required + kernels). Después,
  `cachyos-fish-config` y `cachyos-zsh-config` sueltos (try_install). Firefox no
  aparece: en esa instalación se desmarcó (o falló).
- `fstab`: mismo formato, subvolúmenes y opciones (`compress=zstd`: disco no
  NVMe). `/boot` con `defaults,noatime`: en BIOS la ESP no recibe las opciones
  `efi`.
- `vconsole.conf`, `00-keyboard.conf`, `/etc/default/keyboard`, `locale.conf`,
  `/etc/default/locale`, `/etc/timezone`, `/etc/hosts`, el bloque final de
  `locale.gen`, `/etc/adjtime` (`UTC`) y `/var/lib/dbus/machine-id →
  /etc/machine-id`: idénticos a lo descrito.
- `HOOKS=(base systemd autodetect microcode kms modconf block keyboard
  sd-vconsole plymouth filesystems)`, y cmdline `quiet nowatchdog splash rw
  rootflags=subvol=/@ root=UUID=…` (rama limine, sin LUKS).
- Usuario con shell `/bin/fish` y grupos `sys network wheel audio lp storage
  video users rfkill nopasswdlogin`; `/root` 0750, home 0700.
- `/usr/local/bin/remove-nvidia` sin dueño; `.pacnew` de `pacman.conf`, los
  mirrorlist y `resolv.conf`.

## Pendiente de verificar en VM (UEFI + systemd-boot + LUKS)

- Contenido final de `loader/entries/*.conf` y de `/etc/kernel/cmdline`
  (hallazgos 1 y 2) y si `bootctl install` usa el machine-id del live.
- Valor de `$LOCALE` para `firefox-i18n-*` con español de España.
- Efecto de `ufw enable` en el live (hallazgo 8).
- Qué instala `chwd --autoconfigure` en el hardware de destino.
- Parámetros reales del LUKS2 (`cryptsetup luksDump`) con cryptsetup 2.8.

## Puntos de decisión para la comparación con New-Cli-Installer

No se deciden aquí; se recogen para la tabla de diferencias de la Fase 2.

- ¿Replicar los grupos de netinstall preseleccionados (aplicaciones gráficas
  como `cachyos-hello`, `alacritty`, `meld`, `pavucontrol`, fuentes, códecs,
  Firefox) en un sistema que tendrá Hyprland, o solo los críticos/base?
- ¿Mantener los dos kernels (`linux-cachyos` y `-lts`)?
- ¿Replicar las rarezas (cmdline duplicada, restos de `kernel-install` en la
  ESP, `nopasswdlogin`, `remove-nvidia`, caché de paquetes) o corregirlas como
  desviación documentada?
- ¿Mantener `ufw enable` al final o moverlo para no cortar SSH al live?
- Cerrar el mapper LUKS al desmontar (Calamares no lo hace).
- Cómo encaja TPM2 (Fase 5) sobre `sd-encrypt` + `rd.luks.uuid`.
