
# --- pixmatic_autoinstall: se añade al final de la copia de profiledef.sh ---
# iso_name se mantiene: run_build() espera la ISO como cachyos-<fecha>-x86_64.iso
iso_publisher="pixmatic <https://github.com/pixmatic/CachyOS-Live-ISO>"
iso_application="CachyOS pixmatic autoinstall"

# Ficheros eliminados por remove.list
for _f in calamares-online.sh dmcheck pkexec-wrapper prepare-live-desktop.sh \
          remove-nvidia removeun removeun-online; do
  unset "file_permissions[/usr/local/bin/${_f}]"
done
unset _f
