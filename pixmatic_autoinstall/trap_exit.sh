# Sustituye a util-iso.sh:trap_exit() en la copia de build/ (build.sh añade
# la carga de este fichero al final de la copia de util-iso.sh).
#
# El trap EXIT de buildiso.sh se ejecuta también al terminar bien, y el
# trap_exit() de upstream siempre muestra "An unknown error has occurred".
# Aquí solo se muestra si el código de salida no es 0.
#
# Mismo cambio que el PR https://github.com/CachyOS/CachyOS-Live-ISO/pull/122.
# Cuando upstream lo incorpore, build.sh avisa: borrar este fichero y su import.

trap_exit() {
    local rc=$? sig=$1; shift
    # The EXIT trap also runs on success: only report an error if the exit status is non-zero
    [[ "$sig" != EXIT || "$rc" -ne 0 ]] && error "$@"
    umount_fs
    trap -- "$sig"
    kill "-$sig" "$$"
}
