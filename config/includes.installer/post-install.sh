#!/bin/sh
set -u
warn() { echo "WARN: $1 -- revisar manualmente" >&2; }

TARGET_USER=$(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd | head -n1)
TARGET_HOME=$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6)
[ -z "$TARGET_USER" ] && warn "No se detectó usuario real, algunas cosas solo quedarán en /etc/skel"

apply_to_user () {
  [ -z "$TARGET_HOME" ] && return 0
  src="/etc/skel/$1"
  dst="$TARGET_HOME/$1"
  [ -e "$src" ] || return 0
  mkdir -p "$(dirname "$dst")"
  cp -rf "$src" "$dst"
  chown -R "$TARGET_USER":"$TARGET_USER" "$dst" 2>/dev/null || true
}

echo "=== [1/9] Dependencias básicas (git, zsh, flatpak, curl) ==="
apt-get update
apt-get install -y --no-install-recommends git zsh flatpak curl gnupg ca-certificates \
  pulseaudio-utils alsa-utils || warn "alguna dependencia básica falló"

echo "=== [2/9] Repos de terceros + paquetes (Brave, Opera, VS Code, GitHub Desktop, OnlyOffice, Claude Desktop, Steam) ==="
curl -fsSL https://brave-browser-apt-release.s3.brave.com/brave-core.asc \
    -o /usr/share/keyrings/brave-browser-archive-keyring.asc \
  && gpg --dearmor -o /usr/share/keyrings/brave-browser-archive-keyring.gpg \
       /usr/share/keyrings/brave-browser-archive-keyring.asc \
  && echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
       > /etc/apt/sources.list.d/brave-browser-release.list \
  || warn "Brave: no se pudo agregar el repo"

curl -fsSL https://deb.opera.com/archive.key \
    -o /usr/share/keyrings/opera-archive-keyring.asc \
  && gpg --dearmor -o /usr/share/keyrings/opera-archive-keyring.gpg \
       /usr/share/keyrings/opera-archive-keyring.asc \
  && echo "deb [signed-by=/usr/share/keyrings/opera-archive-keyring.gpg arch=amd64] https://deb.opera.com/opera-stable/ stable non-free" \
       > /etc/apt/sources.list.d/opera-stable.list \
  || warn "Opera: no se pudo agregar el repo"

curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    -o /usr/share/keyrings/microsoft.asc \
  && gpg --dearmor -o /usr/share/keyrings/microsoft-archive-keyring.gpg \
       /usr/share/keyrings/microsoft.asc \
  && echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/code stable main" \
       > /etc/apt/sources.list.d/vscode.list \
  || warn "VS Code: no se pudo agregar el repo"

curl -fsSL https://apt.packages.shiftkey.dev/gpg.key \
    | gpg --dearmor -o /usr/share/keyrings/shiftkey-packages.gpg \
  && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/shiftkey-packages.gpg] https://apt.packages.shiftkey.dev/ubuntu/ any main" \
       > /etc/apt/sources.list.d/shiftkey-packages.list \
  || warn "GitHub Desktop: no se pudo agregar el repo"

curl -fsSL https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE \
    -o /usr/share/keyrings/onlyoffice.asc \
  && gpg --dearmor -o /usr/share/keyrings/onlyoffice-archive-keyring.gpg \
       /usr/share/keyrings/onlyoffice.asc \
  && echo "deb [signed-by=/usr/share/keyrings/onlyoffice-archive-keyring.gpg] https://download.onlyoffice.com/repo/debian squeeze main" \
       > /etc/apt/sources.list.d/onlyoffice.list \
  || warn "OnlyOffice: no se pudo agregar el repo"

curl -fsSL https://storage.googleapis.com/osprey-downloads-anthropic-com/anthropic-apt/public.gpg \
    -o /usr/share/keyrings/anthropic.asc \
  && gpg --dearmor -o /usr/share/keyrings/anthropic-archive-keyring.gpg \
       /usr/share/keyrings/anthropic.asc \
  && echo "deb [signed-by=/usr/share/keyrings/anthropic-archive-keyring.gpg] https://storage.googleapis.com/osprey-downloads-anthropic-com/anthropic-apt stable main" \
       > /etc/apt/sources.list.d/claude-desktop.list \
  || warn "Claude Desktop: revisar https://code.claude.com/docs/en/desktop-linux"

dpkg --add-architecture i386 || warn "no se pudo agregar i386"
apt-get update

apt-get install -y --no-install-recommends brave-browser || warn "brave-browser"
apt-get install -y --no-install-recommends opera-stable || warn "opera-stable"
apt-get install -y --no-install-recommends code || warn "code (VS Code)"
apt-get install -y --no-install-recommends github-desktop || warn "github-desktop"
apt-get install -y --no-install-recommends onlyoffice-desktopeditors || warn "onlyoffice-desktopeditors"
apt-get install -y --no-install-recommends claude-desktop || warn "claude-desktop"
apt-get install -y --no-install-recommends steam-installer || warn "steam-installer"

echo "=== [3/9] Navegador por defecto (Brave) + purgar Firefox y LibreOffice ==="
apt-get purge -y firefox-esr || warn "firefox-esr no estaba o no se pudo purgar"
apt-get purge -y 'libreoffice*' || warn "libreoffice no estaba o no se pudo purgar"
apt-get autoremove -y || true

mkdir -p /etc/skel/.config
cat > /etc/skel/.config/mimeapps.list << 'EOF'
[Default Applications]
text/html=brave-browser.desktop
x-scheme-handler/http=brave-browser.desktop
x-scheme-handler/https=brave-browser.desktop
x-scheme-handler/about=brave-browser.desktop
x-scheme-handler/unknown=brave-browser.desktop
EOF
apply_to_user .config/mimeapps.list
xdg-settings set default-web-browser brave-browser.desktop || true

echo "=== [4/9] Accesos web (Figma, Notion Calendar, ChatGPT, WhatsApp) ==="
mkdir -p /usr/share/icons/uva-webapps
curl -fsSL "https://www.google.com/s2/favicons?domain=figma.com&sz=128" -o /usr/share/icons/uva-webapps/figma.png || warn "ícono Figma"
curl -fsSL "https://www.google.com/s2/favicons?domain=notion.so&sz=128" -o /usr/share/icons/uva-webapps/notion-calendar.png || warn "ícono Notion Calendar"
curl -fsSL "https://www.google.com/s2/favicons?domain=chatgpt.com&sz=128" -o /usr/share/icons/uva-webapps/chatgpt.png || warn "ícono ChatGPT"
curl -fsSL "https://www.google.com/s2/favicons?domain=whatsapp.com&sz=128" -o /usr/share/icons/uva-webapps/whatsapp.png || warn "ícono WhatsApp"

make_webapp () {
  name="$1"; url="$2"; icon="$3"; file="$4"
  cat > "/usr/share/applications/${file}.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=${name}
Comment=${name} (acceso web, vía Brave)
Exec=brave-browser --app=${url}
Icon=${icon}
Terminal=false
Categories=Network;WebBrowser;
EOF
}
make_webapp "Figma" "https://www.figma.com" "/usr/share/icons/uva-webapps/figma.png" "figma-webapp"
make_webapp "Notion Calendar" "https://calendar.notion.so" "/usr/share/icons/uva-webapps/notion-calendar.png" "notion-calendar-webapp"
make_webapp "ChatGPT" "https://chatgpt.com" "/usr/share/icons/uva-webapps/chatgpt.png" "chatgpt-webapp"
make_webapp "WhatsApp" "https://web.whatsapp.com" "/usr/share/icons/uva-webapps/whatsapp.png" "whatsapp-webapp"

echo "=== [5/9] Flatpak (Notion, Proton Mail, Proton Pass, Dopamine) ==="
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || warn "Flathub remote"
flatpak install -y --system flathub io.github.mrfoto.NotionApp || warn "Notion flatpak (revisar ID en flathub.org)"
flatpak install -y --system flathub me.proton.Mail || warn "Proton Mail flatpak"
flatpak install -y --system flathub me.proton.Pass || warn "Proton Pass flatpak"
flatpak install -y --system flathub org.dopamine_player.Dopamine || warn "Dopamine flatpak (revisar ID)"

echo "=== [6/9] Tema Dracula + fuentes (Nunito Sans, Sora, JetBrains Mono) ==="
TMP=/tmp/dracula
mkdir -p "$TMP"
git clone --depth=1 https://github.com/dracula/gtk.git "$TMP/gtk" \
  && mkdir -p /usr/share/themes \
  && cp -r "$TMP/gtk" "/usr/share/themes/Dracula" \
  || warn "Dracula GTK theme: no se pudo clonar"

mkdir -p /etc/dconf/profile /etc/dconf/db/local.d
cat > /etc/dconf/profile/user << 'EOF'
user-db:user
system-db:local
EOF
cat > /etc/dconf/db/local.d/00-dracula << 'EOF'
[org/gnome/desktop/interface]
gtk-theme='Dracula'
icon-theme='Dracula'
color-scheme='prefer-dark'
EOF
command -v dconf >/dev/null 2>&1 && dconf update || true
rm -rf "$TMP"

FONT_DIR=/usr/share/fonts/truetype/custom
mkdir -p "$FONT_DIR"
TMPF=/tmp/fonts
mkdir -p "$TMPF"
if ! fc-list | grep -qi "Nunito Sans"; then
  git clone --depth=1 --filter=blob:none --sparse https://github.com/google/fonts.git "$TMPF/gfonts" 2>/dev/null
  [ -d "$TMPF/gfonts" ] && ( cd "$TMPF/gfonts" && git sparse-checkout set ofl/nunitosans ) \
    && cp "$TMPF/gfonts/ofl/nunitosans"/*.ttf "$FONT_DIR"/ 2>/dev/null
fi
if ! fc-list | grep -qi "Sora"; then
  git clone --depth=1 --filter=blob:none --sparse https://github.com/google/fonts.git "$TMPF/gfonts2" 2>/dev/null
  [ -d "$TMPF/gfonts2" ] && ( cd "$TMPF/gfonts2" && git sparse-checkout set ofl/sora ) \
    && cp "$TMPF/gfonts2/ofl/sora"/*.ttf "$FONT_DIR"/ 2>/dev/null
fi
rm -rf "$TMPF"
fc-cache -f "$FONT_DIR" || true

mkdir -p /etc/skel/.config/gtk-3.0
cat > /etc/skel/.config/gtk-3.0/settings.ini << 'EOF'
[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Dracula
gtk-font-name=Nunito Sans 10
EOF
apply_to_user .config/gtk-3.0/settings.ini

if command -v code >/dev/null 2>&1; then
  HOME=/etc/skel code --user-data-dir=/etc/skel/.config/Code \
    --install-extension dracula-theme.theme-dracula \
    || warn "VS Code: extensión Dracula"
  apply_to_user .config/Code
fi

echo "=== [7/9] oh-my-zsh ==="
export RUNZSH=no CHSH=no KEEP_ZSHRC=no
git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git /etc/skel/.oh-my-zsh || warn "oh-my-zsh clone"
if [ -d /etc/skel/.oh-my-zsh ]; then
  cp /etc/skel/.oh-my-zsh/templates/zshrc.zsh-template /etc/skel/.zshrc
  sed -i 's/^ZSH_THEME=.*/ZSH_THEME="agnoster"/' /etc/skel/.zshrc
  sed -i 's/^plugins=(git)/plugins=(git sudo history-substring-search)/' /etc/skel/.zshrc
  echo 'export ZSH="$HOME/.oh-my-zsh"' | cat - /etc/skel/.zshrc > /tmp/zshrc.tmp && mv /tmp/zshrc.tmp /etc/skel/.zshrc
  apply_to_user .oh-my-zsh
  apply_to_user .zshrc
fi
if [ -f /etc/adduser.conf ]; then
  sed -i 's#^DSHELL=.*#DSHELL=/usr/bin/zsh#' /etc/adduser.conf
  grep -q '^DSHELL=' /etc/adduser.conf || echo 'DSHELL=/usr/bin/zsh' >> /etc/adduser.conf
fi
[ -n "$TARGET_USER" ] && chsh -s /usr/bin/zsh "$TARGET_USER" || true
chsh -s /usr/bin/zsh root || true
cp -r /etc/skel/.oh-my-zsh /root/.oh-my-zsh 2>/dev/null || true
cp /etc/skel/.zshrc /root/.zshrc 2>/dev/null || true

echo "=== [8/9] Sonido de inicio de sesión + Wallpaper claro/oscuro ==="
mkdir -p /usr/share/sounds/uva
if [ -f /tmp/assets/uva-login.wav ]; then
  cp /tmp/assets/uva-login.wav /usr/share/sounds/uva/login.wav
  mkdir -p /etc/xdg/autostart
  cat > /etc/xdg/autostart/uva-login-sound.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=UVa Login Sound
Exec=sh -c "paplay /usr/share/sounds/uva/login.wav 2>/dev/null || aplay /usr/share/sounds/uva/login.wav 2>/dev/null"
X-GNOME-Autostart-enabled=true
NoDisplay=true
Terminal=false
EOF
else
  warn "No se encontró /tmp/assets/uva-login.wav, se saltea el sonido de login"
fi

mkdir -p /usr/share/backgrounds/uva
if [ -f /tmp/assets/wallpaper-light.jpg ] && [ -f /tmp/assets/wallpaper-dark.jpg ]; then
  cp /tmp/assets/wallpaper-light.jpg /usr/share/backgrounds/uva/
  cp /tmp/assets/wallpaper-dark.jpg /usr/share/backgrounds/uva/

  mkdir -p /usr/share/gnome-background-properties
  cat > /usr/share/gnome-background-properties/uva.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">
<wallpapers>
  <wallpaper deleted="false">
    <name>UVa</name>
    <filename>/usr/share/backgrounds/uva/wallpaper-light.jpg</filename>
    <filename-dark>/usr/share/backgrounds/uva/wallpaper-dark.jpg</filename-dark>
    <options>zoom</options>
  </wallpaper>
</wallpapers>
EOF

  cat >> /etc/dconf/db/local.d/01-uva-background << 'EOF'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/uva/wallpaper-light.jpg'
picture-uri-dark='file:///usr/share/backgrounds/uva/wallpaper-dark.jpg'
picture-options='zoom'
EOF
  command -v dconf >/dev/null 2>&1 && dconf update || true

  mkdir -p /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml
  cat > /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitorVNC-0" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/uva/wallpaper-light.jpg"/>
        </property>
      </property>
    </property>
  </property>
</channel>
EOF
  apply_to_user .config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml
else
  warn "No se encontraron los wallpapers en /tmp/assets/, se saltea"
fi

echo "=== [9/9] Nombre de la distro (os-release + GRUB) ==="
cat > /etc/os-release << 'EOF'
PRETTY_NAME="UltraVioleta OS"
NAME="UltraVioleta OS"
VERSION_ID="1.0"
VERSION="1.0 (trixie)"
VERSION_CODENAME=trixie
ID=uva
ID_LIKE=debian
HOME_URL="https://midistro.example.org"
SUPPORT_URL="https://midistro.example.org/soporte"
BUG_REPORT_URL="https://midistro.example.org/issues"
EOF
sed -i 's/^#GRUB_DISTRIBUTOR/GRUB_DISTRIBUTOR="UltraVioleta OS"/' /etc/default/grub 2>/dev/null \
  || echo 'GRUB_DISTRIBUTOR="UltraVioleta OS"' >> /etc/default/grub
update-grub || grub-mkconfig -o /boot/grub/grub.cfg || warn "no se pudo regenerar grub.cfg"

echo "=== Listo ==="
exit 0
