# shellcheck shell=bash
#
# Arranque del sistema instalado (decisiones §9): una UKI en la ESP, cargada
# directamente por el firmware desde una entrada UEFI. Lo usan pixmatic-install
# (al instalar) y pixmatic-rescue (al regenerar el arranque desde el live), así
# que la entrada sale siempre igual. Se carga con ".", no se ejecuta.

# UKI que genera mkinitcpio con el preset que escribe pixmatic-install
# (default_uki): ruta dentro de la ESP y la misma en formato UEFI
pixmatic_uki="EFI/Linux/cachyos-linux-cachyos.efi"
pixmatic_uki_efi='\EFI\Linux\cachyos-linux-cachyos.efi'
pixmatic_boot_label="CachyOS"

# Crea la entrada UEFI de la UKI, primera en BootOrder, tras borrar las
# entradas con la misma etiqueta que apuntan a la misma ruta (de
# instalaciones o regeneraciones anteriores). Sin argumentos: sin Secure
# Boot, systemd-stub usaría los argumentos de la entrada en lugar de la
# cmdline de la UKI.
pixmatic_boot_entry() {  # <disco> <número de partición de la ESP>
    local disk="$1" part="$2" bootnum
    # Líneas "Boot0003* CachyOS<TAB>HD(...)/\EFI\...": "*" si está activa,
    # espacio si no; el firmware puede pasar la ruta a mayúsculas
    while read -r bootnum; do
        efibootmgr -q -b "${bootnum}" -B
    done < <(efibootmgr | grep -iF "${pixmatic_uki_efi}" \
                 | sed -nE "s/^Boot([0-9A-Fa-f]{4})[* ] ${pixmatic_boot_label}\t.*/\1/p")
    efibootmgr -q --create --disk "${disk}" --part "${part}" \
        --label "${pixmatic_boot_label}" --loader "${pixmatic_uki_efi}"
}
