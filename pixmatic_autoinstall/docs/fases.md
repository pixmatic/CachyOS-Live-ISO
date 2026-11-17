# Fases del proyecto

Plan y estado de cada fase. El trabajo avanza fase a fase; las decisiones que
salen de cada una están en [decisiones.md](decisiones.md).

## Fase 0: preparación — hecha

Base `master`, rama de trabajo `pixmatic_iso`, remote `upstream`, directorio
propio `pixmatic_autoinstall/`.

## Fase 1: ISO de consola mínima

Construida desde `pixmatic_autoinstall/` (ver [build.md](build.md)).

- [x] `build.sh` como envoltorio de `buildiso.sh` con `prepare_profile` propio.
- [x] `packages.x86_64` propio (~50 paquetes): sin Plasma, Calamares,
      herramientas de VM ni de rescate. Quitados también `cachyos-hooks` y
      `cachyos-settings` (verificar en la prueba que no hacían falta).
- [x] `default.target` → `multi-user.target`; motd propio.
- [x] `settings.jsonc` completo y comentado; generación y validación en el build.
- [ ] **Construir y arrancar en VM**: build, arranque, `settings.jsonc`
      presente. (`cachyos-installer` ya no va en la ISO: la prueba de
      instalación es la de `pixmatic-install`, Fase 4.)

## Fase 2: auditoría de la instalación base (Calamares vs New-Cli-Installer)

- [x] Código de referencia clonado en `pixmatic_autoinstall/upstream-src/`
      ([codigo-referencia.md](codigo-referencia.md)).
- [x] Secuencia de Calamares (`cachyos-staging`):
      [auditoria-calamares-base.md](auditoria-calamares-base.md). Quedan
      puntos a verificar en VM.
- [x] Secuencia de New-Cli-Installer `0.13.0`:
      [auditoria-new-cli-installer-base.md](auditoria-new-cli-installer-base.md).
      Quedan puntos a verificar en VM.
- [x] Comparación del sistema resultante y decisión de referencia:
      [comparacion-base-resultante.md](comparacion-base-resultante.md).
- [x] Auditorías rehechas para lo que se empaqueta desde CachyOS 26.11
      (2026-11-16, [impacto-upstream-26.11.md](impacto-upstream-26.11.md)).
      Revisar Calamares otra vez cuando `cachyos-staging` se reunifique con
      `cachyos-dev`.
- [x] Puntos de decisión de la comparación cerrados (2026-11-16).
- [ ] Opcional: validar empíricamente instalando con ambos en VM y
      comparando los sistemas resultantes (paquetes, `/etc`, servicios).

## Fase 3: Hyprland

Instaladores oficiales (Calamares con Hyprland, `cachyos-installer` con
`desktop: hyprland`) frente a Omarchy 4.x.

- [x] Anexos de los oficiales:
      [anexo-hyprland-calamares.md](anexo-hyprland-calamares.md) y
      [anexo-hyprland-new-cli-installer.md](anexo-hyprland-new-cli-installer.md).
      Son dos escritorios distintos aunque ambos usan SDDM (Calamares:
      `cachyos-hypr-noctalia` con Noctalia y dotfiles; NCI: wofi, sin
      dotfiles).
- [x] Auditoría de Omarchy `v4.5.0`: [auditoria-omarchy.md](auditoria-omarchy.md).
- [x] Sistema resultante sin y con Omarchy:
      [sistema-resultante-hyprland.md](sistema-resultante-hyprland.md).
- [x] Decidido: **no aplicar Omarchy**; escenario A + aplicaciones y tema
      visual de Omarchy (2026-11-16).
- [ ] Lista de aplicaciones de Omarchy a añadir.
- [ ] Auditar el tema visual (Tokyo Night, `default/themed/*.tpl`,
      `config/hypr/looknfeel.lua`, Quickshell) y decidir cómo aplicarlo sin
      depender de los paquetes de Omarchy (`/etc/skel` o chezmoi).
- [x] Teclado de Hyprland: `kb_layout` = `xkbmap` (decisiones §7).
- [ ] Pendientes: shell (fish o bash), autologin con LUKS.

## Fase 4: instalador propio automático y desatendido

- [x] Primera versión de pruebas (2026-11-16):
      `archiso/airootfs/usr/local/bin/pixmatic-install`, ejecución manual
      (`sudo pixmatic-install [settings.jsonc]`; desde §10, desde el menú). Sistema base sin escritorio,
      LUKS2 con contraseña vacía, con `[chaotic-aur]`, ufw sin activar y sin
      borrado seguro NVMe; configuración desde `settings.jsonc`. Decisiones de esta versión en
      [decisiones.md §9](decisiones.md#9-primera-versión-del-instalador-2026-11-16).
- [x] Primera prueba en VM (2026-11-17, VirtualBox): arranca sin pedir
      clave, montajes y una sola entrada correctos, sin `.pacnew`,
      `[chaotic-aur]` presente, Hyprland con teclado `es`. Fallos
      corregidos: la entrada de `sdboot-manage` 21 ignoraba
      `/etc/kernel/cmdline` (sin compresión ni rollback) y
      `crypttab.initramfs` obsoleto en mkinitcpio 42.
- [ ] Probar en VM y depurar (el usuario): arranque sin pedir clave, montajes
      por gpt-auto y unidades `.mount`, initramfs generado una vez con el tema
      de Plymouth, entradas de systemd-boot sin duplicados, `[chaotic-aur]`
      en el `pacman.conf` instalado, sin `.pacnew`.
- [x] Grupo "Hyprland" de `additional_packages`: si `sddm` queda instalado,
      `systemctl enable sddm` (como `dmcheck` de Calamares) y `kb_layout` de
      `xkbmap` al final del `hyprland.lua` del usuario.
- [ ] Decidir: disco real, hostname/usuario. Shell: fish fija (hecho).
- [x] `settings.jsonc` con esquema propio (sin `cachyos-installer`, que sale
      de la ISO): claves actuales y futuras comentadas
      ([decisiones.md §8](decisiones.md#8-configuración-del-instalador-settingsjsonc)).
- [x] Programas adicionales (`extra_packages`), grupos y paquetes de
      netinstall de Calamares (`additional_packages`; Firefox e Hyprland
      activos), `console_keymap`, `firewall`, `user_fullname`.
- [ ] Claves de la personalización «omarchy» (activar/desactivar;
      aplicaciones y temas, todos comentados), tras cerrar la Fase 3.
- [x] Instalador sin preguntas (2026-11-17): sin confirmación y con las
      contraseñas tal cual de `settings.jsonc`.
- [x] `ssh_server`: sshd activo en el sistema instalado con usuario y
      contraseña, también root (para depurar en VM; quitar al terminar).
- [ ] Inyección de contraseñas sin publicarlas (el repo es público).
- [x] Menú al entrar en el live, en tty1 y por SSH (2026-11-17,
      `pixmatic-menu`,
      [decisiones.md §10](decisiones.md#10-menú-del-live-2026-11-17)):
      instalar (elegir disco de la lista con nombre y tamaño + confirmar
      borrado; al terminar, reiniciar, apagar o consola; si falla, a la
      consola), editar `settings.jsonc` con nano, modo consola, apagar.
      Sustituye al servicio de instalación automática con salvaguarda. Fuera
      `device` y `on_finish` de `settings.jsonc`.
- [x] Menú probado en VM por el usuario (2026-11-18): tty1 y SSH, lista
      de discos, confirmación con particiones, instalación, diálogo final y
      salida a consola al fallar. Arreglos de la prueba: flechas por SSH
      (`xterm-noapp`), motivo visible cuando la lista de paquetes no se
      resuelve, y `geo-mirror` + `cdn-mirror` para `[chaotic-aur]` en el
      `pacstrap` (decisiones §9 y §10).
- [ ] Red: el menú no configura wifi; hoy, *Modo consola* → `nmtui` →
      `sudo pixmatic-menu`.
- [x] Teclado de consola: español en el live (`vconsole.conf` del overlay);
      el del sistema instalado, configurable (`console_keymap`).
- [x] SSH al live como `root`/`liveuser` sin contraseña ni claves (para
      depurar).

## Fase 5: TPM2 para el LUKS2 de la base

El cifrado ya no es una fase aparte: el instalador hace `cryptsetup
luksFormat` (LUKS2) al particionar y la raíz se desbloquea en el initrd por
gpt-auto ([decisiones.md §4](decisiones.md#4-disco-cifrado-y-montajes)). El
plan anterior (cifrar en sitio con `cryptsetup reencrypt` desde el
`post_install` de `cachyos-installer`) queda descartado.

- Esquema: formatear con **clave vacía** (keyfile de 0 bytes) para que el
  primer arranque abra sin preguntar; en ese primer arranque, servicio
  one-shot `systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7
  --unlock-key-file=<vacío>`, `--recovery-key` y `--wipe-slot=empty`; luego
  se desactiva. Inscribir en el primer arranque (no desde el live) para que el
  TPM selle el arranque real.
- Con gpt-auto no hay línea de `crypttab` por defecto: las opciones
  (`try-empty-password=yes`, `tpm2-device=auto`) irían en `rd.luks.options=`
  de `/etc/kernel/cmdline` o en `/etc/crypttab.initramfs`. Resuelto en el
  código: línea de `/etc/crypttab` con `x-initrd.attach` ([decisiones.md §9](decisiones.md#9-primera-versión-del-instalador-2026-11-16)).
- Riesgos: hasta inscribir el TPM el disco se abre sin clave; añadir o quitar
  keyslots no cambia la clave maestra (opcional: `cryptsetup reencrypt` en
  caliente tras inscribir, para rotarla); cambios de firmware o de Secure Boot
  alteran PCR 7 y obligan a usar la clave de recuperación.
- [ ] Decidir qué hacer con la clave de recuperación (mostrarla, guardarla en
      un fichero…).
- [ ] Confirmar en VM con `swtpm` el manejo de la clave vacía (keyfile de
      0 bytes, `try-empty-password`, `--wipe-slot=empty`).

## Fase 6: restauración de la configuración

- [ ] `/etc` con **etckeeper** (repositorio git de `/etc`).
- [ ] `$HOME` con **chezmoi** (dotfiles).
