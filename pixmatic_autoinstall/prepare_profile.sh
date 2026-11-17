# Sustituye a util-iso.sh:prepare_profile() en la copia de build/.
# build.sh añade la carga de este fichero al final de la copia de util-iso.sh,
# así que esta definición prevalece sobre la de upstream.
#
# Basado en el prepare_profile() de upstream guardado en
# prepare_profile.upstream, sin los pasos propios del escritorio
# (packages_desktop, display manager, motd de Calamares) ni la versión en
# grub.cfg (arrancamos con systemd-boot). build.sh se detiene
# si la función de upstream cambia, para revisar si hay que incorporar algo.
#
# packages.x86_64, motd, environment y default.target vienen del overlay.

prepare_profile(){
    profile=$1

    info "Profile: [%s]" "${profile}"

    local _iso_version="$(date +%y%m%d)"
    # Sin change_grub_version: GRUB no se usa (remove.list quita grub/)

    # Fetch up-to-date version of CachyOS repo mirrorlist
    fetch_cachyos_mirrorlist

    # mask cachyos-rate-mirrors timer
    ln -sf /dev/null ${src_dir}/archiso/airootfs/etc/systemd/system/cachyos-rate-mirrors.timer

    rm -f ${src_dir}/archiso/airootfs/etc/systemd/system/display-manager.service

    # Write out version to be able to check ISO version
    echo "${_iso_version}" > ${src_dir}/archiso/airootfs/etc/version-tag

    # Write out edition to be able to check ISO edition
    generate_edition_tag "${profile}"

    iso_file=$(gen_iso_fn).iso
}

# Sustituye a util-iso.sh:gen_iso_fn(): nombre fijo, sin la fecha de upstream
# (cachyos-<perfil>-linux-AAMMDD), para que la ISO y su pkgs.txt tengan
# siempre la misma ruta. build.sh define PIXMATIC_ISO_NAME y comprueba que la
# ISO sale con ese nombre (si upstream deja de usar gen_iso_fn, fallará ahí).
gen_iso_fn(){
    echo "${PIXMATIC_ISO_NAME:?}"
}
