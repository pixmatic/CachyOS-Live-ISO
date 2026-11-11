# pixmatic_autoinstall

Modificaciones propias del fork `pixmatic/CachyOS-Live-ISO` (rama `pixmatic_iso`).

Objetivo: ISO mínima de CachyOS, sin interfaz gráfica, que instala el sistema de
forma desatendida con `cachyos-installer` (modo headless) y después restaura la
configuración con etckeeper (`/etc`) y chezmoi (`$HOME`).

Todo el trabajo propio vive en este directorio para minimizar los conflictos al
fusionar periódicamente con upstream (`CachyOS/CachyOS-Live-ISO`).
