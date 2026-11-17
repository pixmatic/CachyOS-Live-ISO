# Sistema resultante con Hyprland: sin Omarchy y con Omarchy

Cómo quedaría el sistema que instala **nuestro instalador** en dos
escenarios:

- **A. Hyprland de CachyOS** (sin Omarchy): la base decidida tras comparar
  Calamares y NCI, más el escritorio Hyprland como lo instala Calamares, con
  sus fallos corregidos.
- **B. Omarchy 4.5** encima de esa misma base.

No es una auditoría: es una síntesis de las decisiones ya tomadas
([decisiones.md](decisiones.md)) y de lo auditado en:

- [comparacion-base-resultante.md](comparacion-base-resultante.md) (base;
  Calamares `cachyos-staging` `42a91ab23` vs NCI `0.13.0`);
- [anexo-hyprland-calamares.md](anexo-hyprland-calamares.md) y
  [anexo-hyprland-new-cli-installer.md](anexo-hyprland-new-cli-installer.md);
- [auditoria-omarchy.md](auditoria-omarchy.md) (Omarchy `v4.5.0`
  `ac2690cd7`, ISO `v4-5-0` `2f22117aa`, paquetes 4.5.0-2).

Fecha: 2026-11-16. Las versiones de paquetes son las de los repos ese día.

> **Decisión (2026-11-16): escenario A; no se aplica Omarchy.** De Omarchy
> solo se toman (a) las aplicaciones que se elijan de
> `install/omarchy-base.packages` y (b) el tema visual de Hyprland (Tokyo
> Night, plantillas `default/themed/*.tpl`, `config/hypr/looknfeel.lua`;
> el escritorio Quickshell está por auditar). El escenario B y sus opciones
> de arranque se conservan como referencia de por qué no se aplica; sus
> «Decisiones pendientes» quedan cerradas salvo la shell y el autologin con
> LUKS.

## Resumen

| | Base (sin escritorio) | A. + Hyprland de CachyOS | B. + Omarchy 4.5 |
|---|---|---|---|
| Bootloader | systemd-boot | systemd-boot | **Limine** (dependencia dura de `omarchy`) o systemd-boot con Limine neutralizado; ver [B.1](#b1-arranque-el-conflicto-que-hay-que-decidir) |
| initramfs | systemd + `sd-encrypt` | igual | Omarchy fija HOOKS busybox; hay que anularlos con un drop-in propio |
| Repos | CachyOS optimizados | igual | CachyOS + `[omarchy]`; Omarchy **reescribe** `pacman.conf` al instalarse |
| Escritorio | — | Hyprland + Noctalia (`cachyos-hypr-noctalia`), dolphin, kitty | Hyprland (en Omarchy, de su mirror congelado de Arch) + Quickshell de Omarchy, ≈160 paquetes |
| DM | — | SDDM, sin autologin | SDDM con tema `omarchy`, autologin con LUKS |
| Identidad | CachyOS | CachyOS | `/etc/os-release` = **Omarchy** |
| Encaje con lo que prueba CachyOS | alto | alto (grupo oficial de Calamares) | bajo-medio: dos distribuciones mezcladas |

Conclusión: A es un CachyOS oficial con pocas desviaciones y todas
deliberadas. B es viable pero obliga a **revisar al menos dos decisiones ya
tomadas** (systemd-boot y HOOKS con systemd) y a convivir con un
`omarchy-settings` que sobrescribe ficheros en cada actualización.
Recomendación en [Decisiones pendientes](#decisiones-pendientes).

## Base común (lo que deja nuestro instalador sin escritorio)

Resumen de las decisiones; el porqué está en [decisiones.md](decisiones.md) y en la
comparación.

| Área | Estado final |
|---|---|
| Disco | GPT: ESP de 2 GiB (`C12A7328…`) en `/boot` sin cifrar; raíz con tipo **x86-64 root** `4F68BCE3…` y LUKS2. |
| Cifrado | LUKS2; desbloqueo en el initrd por gpt-auto (`gpt-auto-root-luks` → `/dev/mapper/root`). Fase 5: TPM2. |
| btrfs | `@` como subvolumen por defecto (`set-default`); resto de subvolúmenes planos (hermanos de `@`) montados con **unidades `.mount`** en `/etc/systemd/system/` (`What=/dev/gpt-auto-root`, `Options=subvol=@x`). **Sin `/etc/fstab`**. `/tmp` por `tmp.mount`. |
| cmdline | `/etc/kernel/cmdline` sin `root=` ni `subvol=`; `rootflags=noatime,compress=zstd:1` y sin duplicados. Entrada escrita por el instalador: `systemd-boot-manager` 21 ignora `/etc/kernel/cmdline` (decisiones §9). |
| Paquetes | **Un único `pacstrap`**: base + `linux-cachyos` (+ headers, sin `-lts`) + conjunto oficial de Calamares + `snapper` y `btrfs-assistant` (de NCI). Caché vacía al terminar, sin `.pacnew`. |
| Repos | `pacman.conf` de Calamares: repos optimizados (`-v3`/`-v4`/`znver4` según CPU) y `SigLevel` global, sin `Optional TrustAll`. |
| initramfs | `HOOKS` en un drop-in de `/etc/mkinitcpio.conf.d/` (systemd, `sd-vconsole`, `plymouth`, `sd-encrypt`), generado una sola vez. |
| Plymouth | hook + tema de CachyOS. |
| Bootloader | systemd-boot (`bootctl install`, entradas sin restos en la ESP). |
| Usuario | creado **después** de los paquetes, shell **fish**, contraseña yescrypt; `/root` 0750. |
| Hardware | `chwd -a` (puede añadir NVIDIA con los módulos de `linux-cachyos-nvidia-open`). |
| Snapper | config `root` + snapshot de instalación si está `cachyos-snapper-support`. |
| Locale/teclado | `es_ES.UTF-8`, `KEYMAP=es` en `/etc/vconsole.conf`, `Europe/Madrid`. |
| Servicios | los de Calamares (NetworkManager, ufw, …). `ModemManager` pendiente. |
| `default.target` | `multi-user.target` (sin escritorio). |

## A. Base + Hyprland de CachyOS

Lo que instalaría nuestro instalador si el escritorio fuera el oficial de
CachyOS. Se toma **el de Calamares** (`cachyos-staging`), que es la
referencia de sistema resultante, y se corrigen los dos fallos comunes a
ambos oficiales.

### Qué se añade

| Elemento | Estado final | Origen |
|---|---|---|
| Paquetes | `hyprland dolphin kitty sddm cachyos-hypr-noctalia` **dentro del `pacstrap` único** (Calamares: grupo netinstall crítico, `netinstall.yaml:565-584`). | Cal-H H1 |
| Shell del escritorio | Noctalia (barra, lanzador, notificaciones), lanzada desde la config de Hyprland. | Cal-H H2 |
| Config del usuario | dotfiles de `cachyos-hypr-noctalia` en `/etc/skel` (Hyprland en Lua, `uwsm/env`, Noctalia, kitty, GTK/Qt, cursor Bibata) que copia `useradd -m`, porque el usuario se crea después del `pacstrap`. No hace falta la recopia de `/etc/skel` de Calamares. | Cal-H H3 |
| DM | `systemctl enable sddm`. Sin `/etc/sddm.conf` de Calamares (su `[Autologin] Session=hyprland` sin `User=` no hace nada) y sin el enlace roto `ly@tty2.service` de `dmcheck`. | Cal-H H4, R-restos |
| Autologin | no (como ambos oficiales). Con LUKS se podría activar como Omarchy (la frase de LUKS es la frontera); decisión pendiente. | — |
| Teclado en Hyprland | **`es`**. Ninguno de los dos oficiales lo fija (Hyprland queda en `us`). Hay que escribir `kb_layout` en la config Lua del usuario después de `useradd -m` (el fichero de `/etc/skel` es del paquete y no se toca). | corrección |
| Restos del greeter | `/usr/share/noctalia-greeter/config.toml` y `/var/lib/noctalia-greeter/greeter.toml` (`allow_empty_password = true`) llegan con el paquete y no se usan con SDDM. Inofensivos; no se tocan. | Cal-H H5 |
| Plymouth | igual que la base (tema CachyOS). | — |
| `default.target` | `graphical.target` (el de systemd; nada que hacer). | — |

### Qué no cambia

Todo lo de la base: bootloader, initramfs, LUKS, montajes, repos,
`os-release` de CachyOS, `chwd`, snapper. Fish como shell no interfiere con
el escritorio (la sesión arranca por `uwsm`).

### Riesgos

Bajos: es el grupo oficial de Calamares instalado con una técnica distinta
(un `pacstrap`). Lo único nuevo es la línea de `kb_layout` en la config del
usuario, que hay que localizar en la config Lua de `cachyos-hypr-noctalia`
(a verificar en VM).

## B. Base + Omarchy 4.5

Omarchy 4.x no se «aplica» con un script: hay que **replicar lo que hace su
ISO** alrededor de tres comandos del paquete `omarchy`
([auditoria-omarchy.md §1](auditoria-omarchy.md#1-cómo-se-instala-omarchy-45-iso-de-omarchy)).
Secuencia adaptada a nuestro instalador:

1. `pacman.conf` del target: el nuestro (CachyOS) **más `[omarchy]`** y
   `omarchy-keyring` (llavero de su firma).
2. `pacstrap` único: base + `linux-cachyos` + conjunto oficial + las
   listas `install/omarchy-base.packages` (162) y `omarchy`,
   `omarchy-settings`, `omarchy-nvim`. Arrastra `limine`,
   `limine-mkinitcpio-hook`, `limine-snapper-sync`, `snapper`.
3. Ajustes del sistema; `vconsole.conf` con `KEYMAP=es` y `XKBLAYOUT=es`.
4. Crear el usuario (`useradd -m` copia el `/etc/skel` de
   `omarchy-settings`).
5. `chwd -a` (con NVIDIA, ver [B.4](#b4-nvidia)).
6. `omarchy-apply-system --install-user <u> --first-install` en chroot.
7. **Restaurar nuestro `pacman.conf`** (el paso 6 lo sustituye).
8. Bootloader ([B.1](#b1-arranque-el-conflicto-que-hay-que-decidir)).
9. `omarchy-provision-user --force --first-install` como el usuario.
10. Lo que hace la fase *Configuring login* de la ISO: tema y recordatorio
    en `/etc/sddm.conf.d/99-omarchy-login.conf`, autologin con LUKS,
    `/var/lib/sddm/state.conf`.
11. `/etc/resolv.conf` → stub de resolved (desde fuera del chroot).
12. Opcional: snapshot «de fábrica».

No se usaría: la imagen raíz, archinstall, `linux-omarchy`, la hibernación
(su `resume=` va a un drop-in de Limine) ni el aprovisionamiento diferido.

### B.1 Arranque: el conflicto que hay que decidir

El paquete `omarchy` exige en x86_64 la pila Limine
(`pkgs:pkgbuilds/omarchy/PKGBUILD:73-78`), y al instalarse
`limine-mkinitcpio-hook` **sustituye el hook de pacman de mkinitcpio**, pone
un envoltorio interactivo en `/usr/local/bin/mkinitcpio` y despliega Limine
en la ESP ([auditoria-omarchy.md §4](auditoria-omarchy.md#4-arranque-limine-y-mkinitcpio)).
Opciones:

| Opción | Cómo | A favor | En contra |
|---|---|---|---|
| **B1a. Adoptar Limine** | Bootloader Limine con `limine-entry-tool` (UKI) y `limine-snapper-sync`, como Omarchy. | Es **también un camino oficial de CachyOS**: Calamares con `limine` instala `limine limine-entry-tool snapper btrfs-assistant limine-snapper-sync` ([auditoria-calamares-base.md](auditoria-calamares-base.md), rama limine), y esta misma máquina (`cachyhos`) arranca así. Omarchy funciona entero (menú de snapshots, `omarchy-refresh-limine`, Plymouth, kernels). | Revierte la decisión «ISO y sistema con systemd-boot». gpt-auto necesita `LoaderDevicePartUUID`: **a verificar** que Limine lo exporta; si no, vuelven `root=` y los UUID en las unidades `.mount`. El rollback pasaría a ser el de `limine-snapper-sync` (arrancar el snapshot y restaurar), no `snapper rollback` + `set-default`. |
| **B1b. systemd-boot y Limine neutralizado** | Un paquete local de compatibilidad con `provides=(limine limine-mkinitcpio-hook limine-snapper-sync)` para que `omarchy` no los arrastre. | Mantiene todo el diseño actual (gpt-auto, cmdline sin `root=`, `set-default`). | Paquete propio que mantener. Dejan de funcionar los comandos de Omarchy que llaman a Limine (`omarchy-refresh-limine`, `omarchy-plymouth-set`, `omarchy-kernel`, `omarchy-snapshot`, hibernación, restablecer de fábrica) y sus entradas de menú. Si Omarchy añade otra dependencia de arranque, hay que volver a mirar. |
| B1c. Instalar Limine pero arrancar con systemd-boot | — | — | **Descartada**: el hook sustituido deja sin initramfs nuevos a systemd-boot en cada actualización del kernel, y `limine-install` crea su propia entrada EFI. |

### B.2 initramfs

`omarchy-settings` instala `/etc/mkinitcpio.conf.d/00-omarchy-hooks.conf`
con `HOOKS` busybox (`udev … keymap consolefont … encrypt … btrfs-overlayfs`).
Con eso:

- el desbloqueo pasa a `encrypt` + `cryptdevice=` en la cmdline, y **se
  pierden gpt-auto y `sd-encrypt`** (y con ellos el TPM2 de la Fase 5 con
  `/etc/crypttab` con `x-initrd.attach`);
- nuestro drop-in de `HOOKS` solo gana si se ordena **después** de todos los
  de Omarchy: nombre que empiece por letra mayor que `t` (p. ej.
  `zz-pixmatic-hooks.conf`), no `90-…`.

Propuesta en ambos casos (B1a o B1b): mantener nuestros HOOKS con systemd
en `zz-pixmatic-hooks.conf`, conservando lo que aporta Omarchy que tenga
equivalente systemd: `plymouth`, `sd-vconsole` y, con B1a,
`sd-btrfs-overlayfs` (lo trae `limine-mkinitcpio-hook`) en lugar de
`btrfs-overlayfs`. `omarchy_hooks.conf` (quita `kms` con solo NVIDIA) y
`omarchy_vconsole.conf` siguen aplicando porque leen `HOOKS`/`FILES` ya
fijados.

### B.3 Repositorios

`omarchy-apply-system` copia la plantilla de Omarchy sobre
`/etc/pacman.conf` y el mirrorlist (solo `[omarchy]` + Arch desde
`stable-mirror.omarchy.org`). Hay que restaurar el nuestro justo después
(paso 7) y saber que **`omarchy-refresh-pacman`, `omarchy-reinstall-pkgs` y
*Update → Channel* del menú lo vuelven a hacer**.

Orden de repos (pacman usa el primero que tenga el paquete):

> **Corregido (2026-11-16)** con la base de datos real del repo estable
> x86_64 ([auditoria-omarchy.md §5](auditoria-omarchy.md#5-repositorios-y-pacmanconf)):
> `[omarchy]` **no publica** `hyprland` ni `nvidia-utils`/`nvidia-open-dkms`
> para x86_64, así que el orden de repos no los afecta. La versión anterior
> de este apartado (Hyprland y NVIDIA de `[omarchy]`) se sacó de los
> PKGBUILDs y era errónea.

- `omarchy-hyprland-titlebars` publicado depende de `hyprland=0.56.2`;
  con el Hyprland de CachyOS (0.57.2) **no se puede instalar** hasta que
  Omarchy publique una versión para 0.57.2.
- Solapes reales: `quickshell` (git en `[omarchy]`), `yay`, `walker`,
  `localsend`, `yt-dlp`, `limine-*` (mismas versiones). Ninguno crítico.
- **Decisión final** (2026-11-16, ver [decisiones.md §6](decisiones.md#6-repositorios-y-llaveros)): `[omarchy]` **detrás**
  de los repos de CachyOS y Arch y `[chaotic-aur]` el último; `[omarchy]`
  solo con la personalización «omarchy» activada.

### B.4 NVIDIA

`install/hardware/nvidia.sh` instala `nvidia-open-dkms` (o la rama 580xx)
y sus drop-ins de modprobe/mkinitcpio; `chwd` instalaría
`linux-cachyos-nvidia-open` con `nvidia-utils` de CachyOS. No pueden
convivir. Con `[omarchy]` delante, lo coherente es **no dejar que `chwd`
instale el perfil NVIDIA** y usar el de Omarchy (DKMS contra los headers de
`linux-cachyos`, que ya están). Sin GPU NVIDIA el punto no aplica.

### B.5 Ficheros que Omarchy reescribe en cada actualización

| Fichero | Efecto | Qué hacer |
|---|---|---|
| `/etc/os-release` | `ID=omarchy`, `ID_LIKE=arch` | Aceptarlo (a verificar que `chwd` y los kernels no lo usan). Si molesta, no hay forma limpia de evitarlo: el scriptlet lo repone en cada actualización. |
| `/etc/plymouth/plymouthd.conf` | tema `omarchy` | Aceptarlo: el tema de Omarchy sustituye al de CachyOS. |
| `/etc/nsswitch.conf`, `/etc/security/faillock.conf`, `cups*` | valores de Omarchy | Aceptarlo. |
| `/etc/skel/.bashrc` | bashrc de Omarchy | Irrelevante con fish. |
| `/etc/pam.d/system-auth`, `sddm-autologin`, `/etc/security/pam_env.conf` | `sed` en la instalación | Generará `.pacnew` cuando se actualicen `pambase`/`sddm`/`pam`. Aceptarlo y documentarlo. |

Con etckeeper (Fase 6) todos estos cambios quedan registrados en git.

### B.6 Shell

Omarchy 4.x **no exige fish** (la nota anterior venía de
`omarchy-on-cachyos`): su entorno llega por `/etc/profile.d/omarchy.sh`,
`.bashrc` y `uwsm/env.d`, y no hay ninguna referencia a fish en su código.
Con fish como shell (decisión de la base) hace falta el paquete opcional
`omarchy-fish` para tener en la terminal sus alias, mise, zoxide y starship.
Alternativa: bash, como Omarchy. Decisión pendiente.

### B.7 Lo que encaja sin trabajo

NetworkManager (Omarchy desactiva iwd y networkd, como ya está CachyOS),
resolved en modo stub, ufw activo, PipeWire, zram (drop-in propio de
Omarchy), snapper sin timeline (plantilla de Omarchy en lugar de la de
CachyOS), ESP en `/boot`, locale (con `es_ES.UTF-8` no lo toca), teclado
(`default/hypr/input.lua:12-15` lee `XKBLAYOUT` de `/etc/vconsole.conf`, así
que Hyprland queda en `es` sin más), usuario creado tras los paquetes
(igual que nuestro diseño).

### B.8 Paquetes y servicios añadidos

- ≈160 paquetes de `omarchy-base.packages` (escritorio Quickshell,
  Chromium, LibreOffice, Docker, fcitx5, Obsidian, mise, etc.); 27 solo
  existen en `[omarchy]`.
- Servicios activados: `sddm`, `docker.socket`, `cups`, `avahi-daemon`,
  `power-profiles-daemon`, `systemd-oomd`, `systemd-resolved`,
  `bluetooth`, `ufw`, `snapper-cleanup.timer` (+ `limine-snapper-sync` con
  B1a); `NetworkManager-wait-online` enmascarado.
- Usuario fuera del grupo `docker`; `sshd` desactivado.

## Comparación por área

| Área | Base | A | B (B1a: Limine) | B (B1b: systemd-boot) |
|---|---|---|---|---|
| Bootloader | systemd-boot | = | Limine + UKI | systemd-boot |
| Montaje de la raíz | gpt-auto, sin `root=` | = | `root=` probable (a verificar `LoaderDevicePartUUID`) | gpt-auto |
| HOOKS | systemd, `sd-encrypt` | = | systemd por drop-in `zz-` (+ `sd-btrfs-overlayfs`) | systemd por drop-in `zz-` |
| Rollback | `snapper rollback` + `set-default` | = | `limine-snapper-sync` | `snapper rollback` |
| Repos | CachyOS | = | `[omarchy]` + CachyOS, restaurado tras `apply-system` | igual |
| Hyprland | — | CachyOS 0.57.2-1.1 | el de los repos de Arch/CachyOS (`[omarchy]` no lo publica en x86_64) | igual |
| Escritorio | — | Noctalia | Quickshell de Omarchy | igual |
| DM / autologin | — | SDDM / no | SDDM tema `omarchy` / con LUKS | igual |
| Plymouth | tema CachyOS | = | tema Omarchy | igual |
| NVIDIA | `chwd` | = | DKMS (`nvidia-open-dkms` de Arch) por el script de Omarchy | igual |
| `os-release` | CachyOS | = | Omarchy | Omarchy |
| Teclado Hyprland | — | `es` (ajuste en la config del usuario) | `es` (de `vconsole.conf`) | igual |
| Comandos de Omarchy rotos | — | — | ninguno conocido | los de Limine |

## Decisiones pendientes

1. **¿A o B?** A es el sistema más fiel a CachyOS (objetivo 3 del
   proyecto). B es lo que pedía el objetivo 4 («Hyprland adaptando lo que
   hacen los instaladores oficiales y Omarchy»), pero mezcla dos
   distribuciones y cada actualización de `omarchy-settings` reescribe
   ficheros del sistema.
2. **Si B, el arranque.** Recomendación: **B1a (Limine)**. Es un camino
   oficial de CachyOS además del de Omarchy, deja Omarchy completo y evita
   mantener un paquete de compatibilidad. Coste: revisar las decisiones de
   systemd-boot, cmdline sin `root=` y rollback con `set-default`.
   Antes de decidir, comprobar en VM si Limine exporta
   `LoaderDevicePartUUID`. Si se quiere conservar el diseño actual tal cual,
   B1b.
3. **Si B, el orden de repos**: `[omarchy]` delante (recomendado) o detrás,
   con sus consecuencias para Hyprland y NVIDIA ([B.3](#b3-repositorios)).
4. **Shell**: fish + `omarchy-fish`, o bash como Omarchy.
5. **Autologin con LUKS** también en A (como Omarchy).
6. Si B: ¿se replican la hibernación y el snapshot «de fábrica» de la ISO?

## Pendiente de verificar en VM

- A: que el `hl.config({ input = { kb_layout = ... } })` añadido al final
  de `~/.config/hypr/hyprland.lua` deja Hyprland en `es` (decisiones §7).
- B: que `omarchy-apply-system` y `omarchy-provision-user` terminan bien
  sobre CachyOS (sin `linux-omarchy`, con fish).
- B: sonames de `hyprutils`/`aquamarine` de CachyOS frente al Hyprland de
  Omarchy.
- B1a: `LoaderDevicePartUUID` con Limine; gpt-auto y `sd-encrypt` con UKI
  de `limine-entry-tool`.
- B: uso de `ID` de `os-release` por `chwd` y herramientas de CachyOS.
