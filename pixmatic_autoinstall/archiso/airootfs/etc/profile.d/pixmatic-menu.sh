# pixmatic: abre el menú del instalador (pixmatic-menu) al entrar en el live,
# una vez por sesión: en el login automático de liveuser en tty1 y en las
# sesiones SSH interactivas (con terminal: SSH_TTY), como root o liveuser.
# No en otras consolas ni en "ssh host comando", scp o sftp.
if [ -z "${PIXMATIC_MENU_SHOWN-}" ] && [ -t 0 ] && {
       { [ "$(tty)" = /dev/tty1 ] && [ "$(id -un)" = liveuser ]; } || [ -n "${SSH_TTY-}" ]; }; then
    export PIXMATIC_MENU_SHOWN=1
    if [ "$(id -u)" -eq 0 ]; then
        /usr/local/bin/pixmatic-menu
    else
        sudo /usr/local/bin/pixmatic-menu
    fi
fi
