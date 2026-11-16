# Documentación de pixmatic_autoinstall

Resultados de la auditoría de los instaladores oficiales de CachyOS y decisiones
derivadas para el instalador propio.

- Fase 2: instalación base (sin escritorio), Calamares vs New-Cli-Installer.
  - [auditoria-calamares-base.md](auditoria-calamares-base.md): secuencia de
    Calamares (UEFI, systemd-boot, borrar disco con btrfs + LUKS, sin escritorio)
    traducida a comandos de bajo nivel.
  - [auditoria-new-cli-installer-base.md](auditoria-new-cli-installer-base.md):
    secuencia de New-Cli-Installer `0.12.4` en headless (UEFI, systemd-boot,
    borrar disco con btrfs, sin escritorio) traducida a comandos de bajo nivel;
    el cifrado solo existe en el modo avanzado (LUKS1) y se documenta como delta.
  - [comparacion-base-resultante.md](comparacion-base-resultante.md):
    diferencias en el sistema instalado que deja cada uno (solo el estado
    final, no el orden de los pasos) y puntos de decisión.
- Fase 3: Hyprland, instaladores oficiales vs Omarchy (`omarchy-on-cachyos`).
  - [anexo-hyprland-calamares.md](anexo-hyprland-calamares.md): qué cambia
    respecto a la base de Calamares al elegir Hyprland (grupo netinstall con
    greetd + noctalia-greeter + `cachyos-hypr-noctalia`, `displaymanager`,
    `dmcheck`, `shellprocess@greetd`, recopia del skel).
  - [anexo-hyprland-new-cli-installer.md](anexo-hyprland-new-cli-installer.md):
    qué cambia respecto a la base de NCI `0.12.4` con `desktop: hyprland`
    (perfil `[desktop.hyprland]` con SDDM, plymouth, activación del DM).

- Seguimiento de upstream:
  - [impacto-upstream-26.11.md](impacto-upstream-26.11.md): CachyOS 26.11
    cambia lo que se empaqueta (Calamares rama `cachyos-staging`, NCI
    `0.13.0`); deltas respecto a lo auditado y documentos afectados.
- [sincronizacion-upstream.md](sincronizacion-upstream.md): protocolo para
  fusionar upstream en `pixmatic_iso`.

Cada documento indica las versiones auditadas (rama/tag y commit).
