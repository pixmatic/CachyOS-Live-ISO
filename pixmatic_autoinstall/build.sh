#!/bin/bash
#
# Construye la ISO pixmatic usando el buildiso.sh de upstream sobre una copia
# del repo, sin modificar ningún fichero versionado:
#   1. copia los scripts y archiso/ a build/pixmatic/tree
#   2. elimina las rutas de remove.list y aplica el overlay archiso/
#      (incluye pacman.conf con los repos x86-64-v3)
#   3. añade profiledef.append.sh al final de la copia de profiledef.sh
#   4. hace que la copia de util-iso.sh cargue prepare_profile.sh (sustituye
#      al prepare_profile() de upstream, que es específico del escritorio) y
#      trap_exit.sh (no avisa de error al terminar bien; PR #122 de upstream)
#   5. ejecuta ./buildiso.sh -p pixmatic en la copia y mueve el resultado a
#      out/pixmatic
#
# Uso: sudo ./pixmatic_autoinstall/build.sh [opciones de buildiso.sh salvo -p]

set -e

pix_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src_dir="$(dirname "${pix_dir}")"

source "${src_dir}/util-msg.sh"
import "${src_dir}/util.sh"

tree_dir="${src_dir}/build/pixmatic/tree"
out_dir="${src_dir}/out/pixmatic"
profile="pixmatic"

check_root "$0" "$@"

# Si upstream cambia prepare_profile(), revisar qué hay que llevar a
# prepare_profile.sh antes de actualizar la referencia.
if ! diff -u "${pix_dir}/prepare_profile.upstream" \
        <(awk '/^prepare_profile\(\)/,/^}/' "${src_dir}/util-iso.sh"); then
    error "prepare_profile() ha cambiado en upstream (diff arriba)."
    plain "Revisa si hay que incorporar algo a pixmatic_autoinstall/prepare_profile.sh y actualiza la referencia:"
    plain "awk '/^prepare_profile\\\\(\\\\)/,/^}/' util-iso.sh > pixmatic_autoinstall/prepare_profile.upstream"
    exit 1
fi

# pacman.conf del overlay = el de upstream + repos x86-64-v3. Si upstream lo
# cambia, llevar el cambio al overlay antes de actualizar la referencia.
if ! diff -u "${pix_dir}/pacman.conf.upstream" "${src_dir}/archiso/pacman.conf"; then
    error "archiso/pacman.conf ha cambiado en upstream (diff arriba)."
    plain "Lleva el cambio a pixmatic_autoinstall/archiso/pacman.conf (conservando los repos -v3) y actualiza la referencia:"
    plain "cp archiso/pacman.conf pixmatic_autoinstall/pacman.conf.upstream"
    exit 1
fi

# Los paquetes del live son x86-64-v3 y mkarchiso ejecuta sus scriptlets y
# hooks en el host durante la build: el host tiene que soportar x86-64-v3.
if ! /lib/ld-linux-x86-64.so.2 --help | grep -q 'x86-64-v3 (supported'; then
    die "This host's CPU does not support x86-64-v3, required to build the ISO with -v3 packages"
fi

# trap_exit.sh replica el PR #122 de upstream; si ya está incorporado, sobra.
if grep -q '"$sig" != EXIT' "${src_dir}/util-iso.sh"; then
    warning "util-iso.sh ya incluye el arreglo de trap_exit (PR #122): borra pixmatic_autoinstall/trap_exit.sh y su import en build.sh"
fi

msg "Preparing tree [${tree_dir}]"
rm -rf "${tree_dir}"
mkdir -p "${tree_dir}" "${out_dir}"
cp -a "${src_dir}"/*.sh "${src_dir}/archiso" "${tree_dir}/"

msg2 "Removing paths listed in remove.list"
while read -r path; do
    [[ -z "${path}" || "${path}" == \#* ]] && continue
    rm -rf "${tree_dir:?}/archiso/${path}"
done < "${pix_dir}/remove.list"

msg2 "Applying overlay"
cp -a --remove-destination "${pix_dir}/archiso/." "${tree_dir}/archiso/"
cat "${pix_dir}/profiledef.append.sh" >> "${tree_dir}/archiso/profiledef.sh"
printf '\nimport "%s"\n' "${pix_dir}/prepare_profile.sh" "${pix_dir}/trap_exit.sh" >> "${tree_dir}/util-iso.sh"

# settings.jsonc -> settings.json: solo se eliminan líneas de comentario
# completas, para no tocar valores que contengan // (p. ej. URLs).
msg2 "Generating installer settings.json"
settings="${tree_dir}/archiso/airootfs/etc/pixmatic/settings.json"
mkdir -p "$(dirname "${settings}")"
grep -Ev '^[[:space:]]*//' "${pix_dir}/settings.jsonc" > "${settings}"
if type -P jq > /dev/null; then
    jq empty "${settings}" || die "Invalid JSON generated from settings.jsonc"
elif type -P python3 > /dev/null; then
    python3 -m json.tool "${settings}" > /dev/null || die "Invalid JSON generated from settings.jsonc"
else
    warning "Neither jq nor python3 found: settings.json not validated"
fi

msg "Running buildiso.sh"
cd "${tree_dir}"
# El resultado se comprueba por la ISO generada (el árbol es nuevo), no solo
# por el código de salida.
rc=0
./buildiso.sh "$@" -p "${profile}" || rc=$?

if ! compgen -G "${tree_dir}/out/${profile}/*.iso" > /dev/null; then
    die "buildiso.sh did not produce an ISO (exit code ${rc})"
fi
mv "${tree_dir}/out/${profile}"/* "${out_dir}/"
[[ -n "${SUDO_USER}" ]] && chown -R "${SUDO_USER}:" "${out_dir}"
msg "ISO in [${out_dir}]"
