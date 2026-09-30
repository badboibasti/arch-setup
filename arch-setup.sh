#!/usr/bin/env bash

set -e

echo "==> Updating system..."
sudo pacman -Syu --noconfirm

echo "==> Installing packages..."
# --- Hyprland / Wayland ---
sudo pacman -S --needed --noconfirm \
    hyprland \
    hyprpaper \
    hyprlauncher \
    hyprlock \
    hypridle \
    hyprsunset \
    brightnessctl \
    xdg-desktop-portal-hyprland \
    xdg-desktop-portal-gtk \
    wl-clipboard

# --- Audio ---
sudo pacman -S --needed --noconfirm \
    pipewire \
    pipewire-pulse \
    wireplumber

# --- Terminal / Fonts ---
sudo pacman -S --needed --noconfirm \
    kitty \
    ttf-hack

# --- CLI / Development ---
sudo pacman -S --needed --noconfirm \
    vim \
    fzf \
    ripgrep \
    fastfetch \
    git \
    unzip \
    wget \
    curl

# --- Networking ---
sudo pacman -S --needed --noconfirm \
    networkmanager \
    network-manager-applet

# --- Bluetooth ---
sudo pacman -S --needed --noconfirm \
    bluez \
    bluez-utils \
    blueman

# --- Desktop / Authentication ---
sudo pacman -S --needed --noconfirm \
    polkit-gnome

# --- File Synchronization ---
sudo pacman -S --needed --noconfirm \
    syncthing

# --- Virtualization / QEMU-KVM ---
sudo pacman -S --needed --noconfirm \
    qemu-desktop \
    libvirt \
    virt-manager \
    virt-viewer \
    dnsmasq \
    edk2-ovmf

echo "==> Enabling services..."
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
sudo systemctl enable --now libvirtd
systemctl --user enable --now syncthing.service

echo "==> Configuring libvirt..."
sudo usermod -aG libvirt "$USER"
sudo virsh net-autostart default
sudo virsh net-start default || true

echo "==> Setting up dotfiles..."
mkdir -p "$HOME/.config"

if [ ! -d "$HOME/.dotfiles" ]; then
    git clone https://github.com/badboibasti/dotfiles.git "$HOME/.dotfiles"
fi

ln -sfn "$HOME/.dotfiles/hypr" "$HOME/.config/hypr"
ln -sfn "$HOME/.dotfiles/kitty" "$HOME/.config/kitty"
ln -sfn "$HOME/.dotfiles/fastfetch" "$HOME/.config/fastfetch"
ln -sfn "$HOME/.dotfiles/bash/.bashrc" "$HOME/.bashrc"
ln -sfn "$HOME/.dotfiles/vim/.vimrc" "$HOME/.vimrc"

echo "==> Arch setup complete!"
echo "==> Rebooting to apply group membership and system changes..." 
sleep 3 
sudo reboot

