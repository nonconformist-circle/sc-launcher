#!/bin/bash

# System update
sudo dnf update -y

# RPM Fusion setup
sudo dnf install -y \
https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Flatpak & Flathub
sudo dnf install -y flatpak gnome-software-plugin-flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install Steam (RPM Fusion)
sudo dnf install -y steam

# Install ProtonUp-Qt (via Flatpak)
flatpak install -y flathub net.davidotek.pupgui2

# Install CoreCtrl for AMD tuning if you have AMD CPU/GPU
sudo dnf install -y corectrl
sudo usermod -aG video $USER

# Install Gamemode
sudo dnf install -y gamemode libgamemode

# Vulkan tools (optional)
sudo dnf install -y vulkan-tools

# Optional, latest kernel
sudo dnf copr enable @kernel-vanilla/stable
sudo dnf upgrade --refresh 'kernel*'

# Reboot recommendation
Reboot (GPU permissions, Flatpak sync, kernel)."
