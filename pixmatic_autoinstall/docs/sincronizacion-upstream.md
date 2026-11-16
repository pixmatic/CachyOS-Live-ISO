# Sincronización con upstream

Protocolo para traer a `pixmatic_iso` los cambios de
[CachyOS/CachyOS-Live-ISO](https://github.com/CachyOS/CachyOS-Live-ISO).

- `master` es un espejo de upstream: solo avanza por fast-forward, nunca lleva
  commits propios (los hooks locales bloquean commits fuera de `pixmatic_iso`).
- Todo lo nuestro vive en `pixmatic_autoinstall/`; no borramos ni modificamos
  ficheros de upstream salvo los listados en *Ficheros de upstream modificados*
  de `CLAUDE.md`. Por eso los conflictos deberían ser raros, pero un merge
  limpio **no garantiza** que nuestra build siga funcionando: hay que hacer
  siempre la revisión del paso 5.

## 1. Partir de `pixmatic_iso`, limpia

```sh
# fetch origin master:master falla si estoy en master
git checkout pixmatic_iso
# no debe mostrar nada
git status --porcelain
```

## 2. Sincronizar `master` con upstream

```sh
# actualiza master del fork en GitHub; falla si master ha divergido (no usar --force)
gh repo sync pixmatic/CachyOS-Live-ISO --source CachyOS/CachyOS-Live-ISO --branch master
# trae master a local; solo fast-forward
git fetch origin master:master
```

## 3. Ver qué trae upstream antes de fusionar

```sh
git log --oneline pixmatic_iso..master
git diff --stat pixmatic_iso...master
```

## 4. Fusionar sin confirmar

```sh
# -X no-renames: sin detección de renombrados; los ficheros nuevos de upstream
# entran como A en vez de emparejarse con otro fichero parecido
git merge --no-commit --no-ff -X no-renames master
```

Revisar el estado:

```sh
git status --porcelain --no-renames | sort
```

Códigos de conflicto (columnas XY: X = nuestro lado, Y = upstream):

| Código | Significado | Qué hacer |
|---|---|---|
| `UU` | ambos modificaron | resolver a mano |
| `UD` | upstream borró un fichero que modificamos | decidir si mantenerlo (`git add`) o borrarlo (`git rm`) y actualizar `CLAUDE.md` |
| `DU` | nosotros borramos, upstream modificó | no debería pasar (no borramos ficheros de upstream): restaurar la versión de upstream con `git checkout master -- ruta` y `git add ruta` |
| `AA` | ambos añadieron la misma ruta | resolver a mano |

Para ver el cambio de un fichero concreto:

```sh
git diff --staged -- ruta/al/archivo
```

Salida de emergencia en cualquier momento antes del commit:

```sh
git merge --abort
```

## 5. Revisión obligatoria (aunque no haya conflictos)

```sh
# a) prepare_profile() de upstream: si hay diff, ver si hay que llevar algo a
#    pixmatic_autoinstall/prepare_profile.sh y regenerar la referencia
diff <(awk '/^prepare_profile\(\)/,/^}/' util-iso.sh) pixmatic_autoinstall/prepare_profile.upstream \
  && echo "prepare_profile sin cambios"
# awk '/^prepare_profile\(\)/,/^}/' util-iso.sh > pixmatic_autoinstall/prepare_profile.upstream

# b) cambios en cómo se construye la ISO
git diff --staged -- buildiso.sh util-iso.sh util.sh util-iso-mount.sh archiso/profiledef.sh

# c) rutas de remove.list (relativas a archiso/) que ya no existen en upstream
#    (-L: algunas son symlinks que apuntan a rutas del live, no del repo)
grep -vE '^\s*(#|$)' pixmatic_autoinstall/remove.list | while read -r p; do
  [ -e "archiso/$p" ] || [ -L "archiso/$p" ] || echo "no existe: $p"
done

# d) paquetes de packages.x86_64 que no están en los repos de esta máquina
#    (requiere los repos de CachyOS configurados; solo muestra los que faltan)
grep -vE '^\s*(#|$)' pixmatic_autoinstall/archiso/packages.x86_64 \
  | xargs pacman -Si 2>&1 >/dev/null | grep -i 'error'

# e) cambios en la lista de paquetes de escritorio (pistas de renombrados)
git diff --staged -- archiso/packages_desktop.x86_64

# f) pacman.conf de build: si hay diff, llevarlo a
#    pixmatic_autoinstall/archiso/pacman.conf (conservando los repos -v3) y
#    regenerar la referencia
diff archiso/pacman.conf pixmatic_autoinstall/pacman.conf.upstream \
  && echo "pacman.conf sin cambios"
# cp archiso/pacman.conf pixmatic_autoinstall/pacman.conf.upstream
```

Comprobar que no queda ningún conflicto sin resolver (no debe mostrar nada):

```sh
git diff --name-only --diff-filter=U
```

## 6. Commit y push

```sh
# firmado automáticamente (commit.gpgsign)
git commit -m "Merge upstream master ($(git rev-parse --short master))"
git push
```

Después, cuando toque, construir la ISO y probarla en VM.
