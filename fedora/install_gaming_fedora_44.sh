#!/bin/bash -ex

## autodetection
isGnome=false
isKde=false
isNvidia=false
isAmd=false

case "${XDG_CURRENT_DESKTOP,,}" in
    *gnome*)
        echo "Desktop detected: GNOME"
        isGnome=true
        ;;
    *kde*|*plasma*)
        echo "Desktop detected: KDE Plasma"
        isKde=true
        ;;
    *)
        echo "Desktop detected: Other ($XDG_CURRENT_DESKTOP)"
        ;;
esac

## Check lspci output for VGA/3D controllers (case-insensitive)
if lspci | grep -i 'vga\|3d' | grep -i 'nvidia' > /dev/null; then
    echo "GPU detected: NVIDIA"
    isNvidia=true
elif lspci | grep -i 'vga\|3d' | grep -i 'amd\|ati' > /dev/null; then
    echo "GPU detected: AMD"
    isAmd=true
else
    echo "GPU detected: Intel or Other"
fi

## System update
sudo dnf update -y

## RPM Fusion setup
sudo dnf install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

## Flatpak & Flathub
sudo dnf install -y flatpak $( isGnome && echo "gnome-software-plugin-flatpak")
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

## Install Steam (RPM Fusion)
sudo dnf install -y steam

if [ "$isAmd" = true ]; then
  sudo tee /usr/local/bin/steam-wrapper.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
# Minimal wrapper: enforces workaround for crashy steamwebhelper/CEF

exec /usr/bin/steam -cef-disable-gpu "$@"
EOF
  sudo chmod +x /usr/local/bin/steam-wrapper.sh
  mkdir -p ~/.local/share/applications
  cp /usr/share/applications/steam.desktop ~/.local/share/applications/steam.desktop
  sed -i \
      -e 's#/usr/bin/steam#/usr/local/bin/steam-wrapper.sh#g' \
      -e '/^\[Desktop Entry\]$/a X-GNOME-Autostart-Delay=10' \
      -e '/^\[Desktop Entry\]$/a X-KDE-Autostart-Delay=10' \
      ~/.local/share/applications/steam.desktop
  update-desktop-database ~/.local/share/applications
fi

## Install ProtonUp-Qt and ProtonPus (via Flatpak)
flatpak install -y flathub net.davidotek.pupgui2 com.vysp3r.ProtonPlus

## Install Gamemode
sudo dnf install -y gamemode input-remapper


if [ "$isNvidia" = true ]; then
    echo "Installing latest NVIDIA drivers and hardware acceleration..."
    sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda \
                        vulkan-loader.i686 xorg-x11-drv-nvidia-libs.i686
fi

if [ "$isAmd" = true ]; then
    echo "Optimizing AMD drivers and hardware acceleration..."
    sudo dnf install -y mesa-vulkan-drivers.i686 mesa-va-drivers-freeworld \
                        mesa-vulkan-drivers mesa-va-drivers-freeworld.i686 \
                        vulkan-tools
fi

## Install CoreCtrl for AMD tuning
if [ "$isAmd" = true ]; then
    sudo dnf install -y corectrl
    sudo usermod -aG video $USER
    
    # Allow CoreCtrl to manage power profiles without root prompt
    sudo mkdir -p /etc/polkit-1/rules.d
    sudo tee /etc/polkit-1/rules.d/90-corectrl.rules >/dev/null <<'EOF'
polkit.addRule(function(action, subject) {
    if ((action.id == "org.corectrl.helper.init" ||
         action.id == "org.corectrl.helper.set") &&
        subject.isInGroup("video")) {
        return polkit.Result.YES;
    }
});
EOF
fi

# Reboot recommendation
echo "✅ Setup complete. Reboot (GPU permissions, Flatpak sync, kernel)."

