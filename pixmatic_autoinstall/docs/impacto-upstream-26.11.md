# Impacto de CachyOS 26.11 en las auditorías

Tras sincronizar con upstream (ISO `b0ebcae`, 2026-11-15; merge `eb04aed` en
`pixmatic_iso`) cambia **lo que se empaqueta** de los dos instaladores de
referencia. Este documento recoge qué cambia respecto a lo auditado y qué
partes de las auditorías y de las decisiones quedan afectadas. **No sustituye
a las auditorías**: es la lista de deltas para revisarlas.

## Versiones

| Componente | Auditado hasta ahora | Empaquetado ahora (PKGBUILD) | En el repo `cachyos` (2026-11-16) |
|---|---|---|---|
| Calamares | paquete `cachyos-calamares-next`, rama `cachyos-dev` `199d71543` (2026-09-26) | paquete **`cachyos-calamares-staging`** 3.4.2-3, rama **`cachyos-staging`** `42a91ab23` (2026-11-15), compilado con `-DWITH_CACHYOS_INSTALLER=ON` y dependencia `cachyos-installer-libs` | `cachyos-calamares-staging 3.4.2-1` (y sigue `-next 3.4.2-13`) |
| New-Cli-Installer | tag `0.12.4` (2026-08-05); `settings.jsonc` según `a257be6` | tag **`0.13.0`** (`30401a3`, 2026-11-15) = 157 commits sobre `0.12.4`, 35 sobre `a257be6` | `0.12.4-1` todavía |
| ISO | `3215497` | `b0ebcae`: `calamares-online.sh` y `packages_desktop.x86_64` pasan a `cachyos-calamares-staging` | — |

Referencias: `pkgbuilds:` = `CachyOS-PKGBUILDS` `a7b3058`
(`cachyos-calamares-staging/PKGBUILD:5-7,16,59,85`,
`cachyos-cli-installer-new/PKGBUILD:6,23`); `cala:` = `cachyos-calamares`
`origin/cachyos-staging`; `nci:` = `New-Cli-Installer` `0.13.0`.

La versión de la columna derecha es la de la base local de pacman de esta
máquina; los repos se pondrán al día en breve. A partir de entonces la ISO de
upstream (y la nuestra, que trae `cachyos-cli-installer-new`) usará estas
versiones.

## Calamares: `cachyos-dev` → `cachyos-staging`

`cachyos-staging` **no es una evolución de `cachyos-dev`**: parte de
`f1c20a500` (2026-06-28) y no tiene 28 commits de `cachyos-dev` (julio-sept.),
entre ellos greetd/noctalia-greeter para Hyprland, la plataforma *handheld* y
«crear el usuario antes de instalar paquetes». A cambio tiene 16 commits
propios, la mayoría los que anuncia el changelog 26.11. Es de esperar que
ambas ramas se reunifiquen; hasta entonces lo que se ejecuta es `staging`.

### Cambios que afectan a `auditoria-calamares-base.md`

| Tema | `cachyos-dev` (auditado) | `cachyos-staging` (empaquetado) | Cita |
|---|---|---|---|
| Orden de `users` | tras `machineid`, antes de `locale` | **tras `initcpio`**, antes de `networkcfg` (el orden antiguo; coincide con nuestra decisión de crear el usuario después de los paquetes) | `cala:settings_online.conf:98-111` |
| Diferir/restaurar initramfs | `shellprocess@modify_mk_hook` / `@reset_mk_hook` | módulo C++ nuevo `gucc` (`action: install-mk-hook` / `remove-mk-hook`) con las librerías de NCI | `cala:settings_online.conf:94,117`, `cala:src/modules/gucc/` |
| `zfshostid`, `hwclock`, `enable_ufw`, `btrfs_snapshot` | módulos/shellprocess propios | `gucc@…` (misma lógica que NCI) | `cala:settings_online.conf:108,114,120,121` |
| `initcpio`, `machineid` | Python/C++ de Calamares | con `gucc: true` usan el backend de NCI (machine-id: dbus/uuid; las semillas de entropía las sigue escribiendo el módulo) | `cala:src/modules/initcpio/initcpio.conf`, `cala:src/modules/machineid/machineid.conf` |
| Hook `kms` | en `HOOKS` | **eliminado** (`remove: [ kms ]`) | `cala:src/modules/initcpiocfg/initcpiocfg.conf:30` |
| Plymouth | paquetes en `pacstrap.conf`, siempre | grupo netinstall **«Plymouth»** (visible, marcado y `critical`); `plymouthcfg` solo pone el tema si está instalado y escribe `UseSimpledrm=1` en `[Daemon]` de `/etc/plymouth/plymouthd.conf` | `cala:src/modules/netinstall/netinstall.yaml:833`, `cala:src/modules/plymouthcfg/plymouthcfg.conf:35`, `cala:src/modules/plymouthcfg/main.py` |
| Kernels | añadidos en `pacstrap/main.py` según plataforma | en `pacstrap.conf` (sigue `linux-cachyos` + `-lts` con headers) | `cala:src/modules/pacstrap/pacstrap.conf:35-38` |
| `dmcheck` | `/etc/calamares/scripts/dmcheck` (del paquete) | **`/usr/local/bin/dmcheck` del live** (el de la ISO) | `cala:src/modules/shellprocess/shellprocess.conf` |
| Servicios de usuario | — | añade `arch-update-tray.service` (user) | `cala:src/modules/services-systemd/services-systemd.conf` |
| GRUB | — | `GRUB_BOOTNEXT` desactivado (no nos afecta: systemd-boot) | `cala:src/modules/grubcfg/grubcfg.conf` |
| netinstall | — | `gst-plugin-dav1d`, `gvfs-mtp`; sin tema Iridescent | `cala:src/modules/netinstall/netinstall.yaml` |

`netinstall.conf` de `staging` descarga `netinstall.yaml` de la rama
**`cachyos`** (no de `cachyos-staging`; `cala:src/modules/netinstall/netinstall.conf:9`).
`cachyos` (`1f939ebed`, 2026-11-09) es antecesora de `cachyos-staging` y el
fichero es idéntico en las dos (2026-11-16).

Otros cambios de `staging` en este camino, vistos al rehacer la auditoría:
`initcpio` con `gucc: true` usa `arch-chroot` en vez de `chroot`;
`pacstrap` ya no copia `enable-ufw` ni `btrfs-installation-snapshot` (los
hace el módulo `gucc`); el `plymouthd.conf` resultante queda con dos
secciones `[Daemon]`. Y una corrección a la auditoría anterior: `dmcheck`
**sí actúa sin escritorio** (`pacman -Qs ly` casa por descripción y deja un
enlace roto `ly@tty2.service`).

### Cambios que afectan a `anexo-hyprland-calamares.md`

El anexo describe greetd + `noctalia-greeter` + `shellprocess@greetd`. En
`staging`:

- El grupo Hyprland es `hyprland dolphin kitty sddm cachyos-hypr-noctalia`
  (**SDDM**, sin greetd ni noctalia-greeter;
  `cala:src/modules/netinstall/netinstall.yaml:565-584`).
- `greetd` está comentado en `displaymanager.conf` (`:17`) y no existe
  `shellprocess@greetd` ni `shellprocess_greetd.conf`.
- Desaparece, por tanto, el problema de `allow_empty_password = true` del
  greeter (H8 de la comparación), pero vuelve SDDM.

El changelog dice además que el `dmcheck` de la ISO busca ahora
`noctalia-greeter` en vez de `greetd`, lo que no encaja con un `staging`
sin noctalia-greeter: se espera que esto cambie al reunificar las ramas.
Para nosotros no es decisivo (el Hyprland lo pone Omarchy), pero el anexo
debe indicar la rama.

## New-Cli-Installer: `0.12.4` → `0.13.0`

Lo auditado (`0.12.4`) queda desfasado en estos puntos. La tabla recoge
solo los 35 commits `a257be6..0.13.0` (`0a58bf2`…`30401a3`); los 122 de
`0.12.4..a257be6` (refactor a gucc, cmdline para systemd-boot, validación
de usuario/hostname…) también entran en `0.13.0` y no están revisados aquí:

| Tema | `0.12.4` | `0.13.0` | Cita |
|---|---|---|---|
| Claves de configuración | 43 | **45**: `luks_passphrase` (LUKS2 en la raíz, headless) y `console_keymap` (vconsole si difiere de `xkbmap`) | `nci:installer-lib/src/installer_config.cpp:70,74` |
| `EraseAndAuto` | estrategia propia | **eliminada**: `allow_auto_partition` genera el esquema por defecto y pasa por `CreateLayout` | `nci:installer-lib/src/headless_plan.cpp` |
| Tipo GPT de la raíz | genérico `0FC63DAF…` | **`SD_GPT_ROOT_X86_64`** (`4F68BCE3…`), como hemos decidido nosotros | `47730e4` |
| Initramfs | se regenera varias veces | **una sola vez** (paso `Initramfs` tras diferir el hook), y sin `kms` | `nci:installer-lib/src/orchestrator.cpp:169`, `6250309`, `0a58bf2` |
| Usuario | antes de los paquetes del sistema; fallo = aviso | **después** de los paquetes (existen shell y grupos) y **fatal** | `nci:installer-lib/src/orchestrator.cpp:159`, `4fcec26` |
| `chwd` | al final | antes de `Users` | `nci:installer-lib/src/orchestrator.cpp` |
| `hw_clock` | sin valor por defecto | `utc` por defecto | `3c3d0b9` |
| LUKS en la cmdline | no hay LUKS en headless | `rd.luks.name=<uuid>=cryptroot root=/dev/mapper/cryptroot` (`403d49f` probó `rd.luks.uuid=`, `5e3132e` lo revirtió); paso `LuksKeyfile` propio (solo con `/boot` cifrado) | `nci:gucc/src/kernel_params.cpp:21-29` |
| `post_install` | en el live **tras desmontar** el destino | en el live **con el destino montado**, `$1` = raíz del destino, antes de `BtrfsSnapshot` y `Cleanup`; si falla, aviso | `nci:installer-lib/src/orchestrator.cpp:177`, `38e5af3` |
| Fallos | sin limpieza al abortar | limpia montajes y LUKS al abortar, fallar o terminar | `7f5d3af` |
| Caché de paquetes | vacía (descargas en la del live) | **llena**: descarga en la del target y no la limpia | `nci:gucc/src/io_utils.cpp:224-242` |
| `pacman.conf` del target | el del live, sin repos optimizados | el generado con los repos optimizados, y mirrorlists ordenados | `nci:gucc/src/install.cpp:113-130` |
| `pacstrap` | `HookDir`/`CacheDir` del live | los del destino | `e2b095d` |
| Formateo | — | `mkfs.*` explícitos, `sfdisk -W always` | `3a4552f`, `93c233f` |

## Qué queda afectado en nuestro trabajo

1. **`auditoria-calamares-base.md`** y **`anexo-hyprland-calamares.md`**:
   **rehechos contra `cachyos-staging`** (2026-11-16), con una sección de
   cambios respecto a `cachyos-dev` en cada uno. Cuando upstream reunifique
   las ramas habrá que revisarlos otra vez (es previsible que vuelvan greetd
   + noctalia-greeter y `users` antes de los paquetes).
2. **`auditoria-new-cli-installer-base.md`** y
   **`anexo-hyprland-new-cli-installer.md`**: **rehechos contra `0.13.0`**
   (2026-11-16), con LUKS2 en el camino principal y tablas de cambios
   respecto a `0.12.4` (también contraseñas SHA-512 por stdin, `pacman.conf`
   con repos optimizados y caché llena).
3. **`comparacion-base-resultante.md`**: **rehecha** (2026-11-16). Sin la
   asimetría del cifrado; se cierran caché, ESP, `kms`, initramfs y orden del
   usuario; aparecen el tipo GPT de la raíz y `zswap.enabled=0`; R2 queda
   reducida al `SigLevel` de `[cachyos]` y R3 baja a bajo-medio.
4. **Decisiones** ([decisiones.md](decisiones.md)): ninguna queda contradicha. Varias quedan
   respaldadas por upstream (tipo GPT de la raíz, initramfs generado una vez,
   usuario tras los paquetes, abortar si falla el usuario). A revisar:
   - plymouth: `UseSimpledrm=1` y `HOOKS` sin `kms` en lugar de «plymouth
     completo» tal como se auditó;
   - Hyprland: el que trae el Calamares empaquetado vuelve a usar SDDM.
   - «Caché de paquetes vacía» y «`pacman.conf` sin repos optimizados» eran
     rasgos de NCI `0.12.4`; en `0.13.0` es al revés. Las contraseñas de NCI
     pasan de MD5 a SHA-512 (Calamares usa yescrypt).
5. **`settings.jsonc`**: sigue siendo válido para la `0.12.4` que hay hoy en
   los repos. Con `0.13.0` hay que añadir (comentadas) `luks_passphrase` y
   `console_keymap`, corregir la descripción de `xkbmap` (ya en `0.12.4`
   escribía `KEYMAP=` en `vconsole.conf`) y la de `post_install`.
6. **Fase 5**: el plan anterior basado en `post_install` tras desmontar ya no
   sirve tal cual, pero la fase ya estaba pendiente de replantear para el
   instalador propio.
