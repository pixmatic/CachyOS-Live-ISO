# Documentación de pixmatic_autoinstall

Resultados de la auditoría de los instaladores oficiales de CachyOS y decisiones
derivadas para el instalador propio.

- Fase 2: instalación base (sin escritorio), Calamares vs New-Cli-Installer.
  - [auditoria-calamares-base.md](auditoria-calamares-base.md): secuencia de
    Calamares rama `cachyos-staging` (UEFI, systemd-boot, borrar disco con
    btrfs + LUKS, sin escritorio) traducida a comandos de bajo nivel, con los
    cambios respecto a `cachyos-dev`.
  - [auditoria-new-cli-installer-base.md](auditoria-new-cli-installer-base.md):
    secuencia de New-Cli-Installer `0.13.0` en headless (UEFI, systemd-boot,
    borrar disco con btrfs + LUKS2, sin escritorio) traducida a comandos de
    bajo nivel, con los cambios respecto a `0.12.4`.
  - [comparacion-base-resultante.md](comparacion-base-resultante.md):
    diferencias en el sistema instalado que deja cada uno (solo el estado
    final, no el orden de los pasos), ambos con LUKS2, y puntos de decisión.
- Fase 3: Hyprland, instaladores oficiales vs Omarchy 4.x.
  - [anexo-hyprland-calamares.md](anexo-hyprland-calamares.md): qué cambia
    respecto a la base de Calamares `cachyos-staging` al elegir Hyprland
    (grupo netinstall con SDDM + `cachyos-hypr-noctalia`, `displaymanager`,
    `dmcheck`), y en qué se diferencia del greetd de `cachyos-dev`.
  - [anexo-hyprland-new-cli-installer.md](anexo-hyprland-new-cli-installer.md):
    qué cambia respecto a la base de NCI `0.13.0` con `desktop: hyprland`
    (perfil `[desktop.hyprland]` con SDDM, plymouth, activación del DM).
  - [auditoria-omarchy.md](auditoria-omarchy.md): Omarchy `v4.5.0` (y su
    ISO, rama `v4-5-0`): cómo se instala (imagen raíz + comandos
    `omarchy-apply-system`/`omarchy-provision-user`), qué deja en el sistema
    y qué choca con CachyOS (Limine obligatorio, HOOKS busybox,
    `pacman.conf`, `os-release`, NVIDIA), con la lista de conflictos de
    `omarchy-on-cachyos` comprobada en 4.x.
  - [sistema-resultante-hyprland.md](sistema-resultante-hyprland.md): cómo
    queda el sistema de nuestro instalador con el Hyprland de CachyOS (A) y
    con Omarchy (B), opciones para el arranque y decisiones pendientes.

- Seguimiento de upstream:
  - [impacto-upstream-26.11.md](impacto-upstream-26.11.md): CachyOS 26.11
    cambia lo que se empaqueta (Calamares rama `cachyos-staging`, NCI
    `0.13.0`); deltas respecto a lo auditado y documentos afectados.
- [sincronizacion-upstream.md](sincronizacion-upstream.md): protocolo para
  fusionar upstream en `pixmatic_iso`.

Cada documento indica las versiones auditadas (rama/tag y commit).
