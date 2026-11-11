#!/bin/bash
#
# Construye la ISO pixmatic usando el buildiso.sh de upstream sobre una copia
# del repo, sin modificar ningún fichero versionado:
#   1. copia los scripts y archiso/ a build/pixmatic/tree
#   2. elimina las rutas de remove.list y aplica el overlay archiso/
#   3. añade profiledef.append.sh al final de la copia de profiledef.sh
#   4. hace que la copia de util-iso.sh cargue prepare_profile.sh (sustituye
#      al prepare_profile() de upstream, que es específico del escritorio)
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
printf '\nimport "%s"\n' "${pix_dir}/prepare_profile.sh" >> "${tree_dir}/util-iso.sh"

msg "Running buildiso.sh"
cd "${tree_dir}"
# El trap EXIT de buildiso.sh avisa de error incluso al terminar bien, así
# que el resultado se comprueba por la ISO generada (el árbol es nuevo).
rc=0
./buildiso.sh "$@" -p "${profile}" || rc=$?

if ! compgen -G "${tree_dir}/out/${profile}/*.iso" > /dev/null; then
    die "buildiso.sh did not produce an ISO (exit code ${rc})"
fi
mv "${tree_dir}/out/${profile}"/* "${out_dir}/"
[[ -n "${SUDO_USER}" ]] && chown -R "${SUDO_USER}:" "${out_dir}"
msg "ISO in [${out_dir}]"
