1. Readme: User and Dev
2. Others licences, cambiar licencia
3. Credits: internos y externos

# Esqueleto básico de live-build (Debian)

Estructura mínima para armar una ISO live de Debian con `live-build`.

## Estructura

```
.
├── auto/
│   ├── config    # define las opciones de "lb config" (arch, distro, tipo de imagen, etc.)
│   ├── build     # dispara "lb build"
│   └── clean     # limpia artefactos con "lb clean"
└── config/
    ├── archives/           # claves/listas .list para repos de terceros
    ├── hooks/
    │   ├── normal/         # hooks .hook.chroot / .hook.binary (se ordenan por nombre)
    │   └── live/           # hooks específicos del sistema live
    ├── includes.chroot/    # archivos que se copian TAL CUAL dentro del sistema instalado
    ├── includes.binary/    # archivos que se copian a la imagen binaria (fuera del chroot)
    ├── includes.installer/ # archivos para el instalador (si lo usás)
    ├── package-lists/      # listas .list.chroot con los paquetes a instalar
    └── preseed/            # respuestas preseed para debconf
```

## Uso básico

Necesitás Debian/Ubuntu con el paquete `live-build` instalado (ideal: correr esto dentro de una VM
o contenedor Debian, con privilegios de root, NO en macOS/Windows):

```sh
sudo apt update
sudo apt install live-build

cd live-build-skeleton
sudo lb clean --purge   # opcional, por las dudas
sudo ./auto/config      # genera config/ real a partir del script
sudo ./auto/build       # arma la ISO (puede tardar bastante)
```

Al terminar, la ISO queda en la raíz del proyecto (algo como `live-image-amd64.hybrid.iso`).

## Notas

- Editá `auto/config` para cambiar distro (`bookworm`, `trixie`, etc.), arquitectura,
  tipo de imagen (`iso-hybrid`, `hdd`, `netboot`, etc.) y demás opciones de `lb config`.
- Los archivos en `config/hooks/normal/*.hook.chroot` deben tener permiso de ejecución
  (`chmod +x`) y se ejecutan en orden alfabético.
- `live-build` requiere Linux real (o una VM Debian/Ubuntu). No compila en macOS/Windows nativo.
