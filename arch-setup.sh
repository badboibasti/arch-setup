#!/usr/bin/env bash

set -euo pipefail

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
    wireplumber \
    spotify-launcher

# --- Terminal / Fonts ---
sudo pacman -S --needed --noconfirm \
    kitty \
    ttf-hack \
    terminus-font

echo "==> Configuring TTY font..."

sudo tee /etc/vconsole.conf > /dev/null <<EOF
FONT=ter-v32b
EOF

# --- CLI / Development ---
sudo pacman -S --needed --noconfirm \
    vim \
    fzf \
    ripgrep \
    fastfetch \
    git \
    unzip \
    wget \
    curl \
    man-db \
    man-pages \
    tree

# --- Networking ---
sudo pacman -S --needed --noconfirm \
    networkmanager \
    network-manager-applet

# --- Proton VPN ---
sudo pacman -S --needed --noconfirm \
    proton-vpn-cli \
    gnome-keyring

# --- Password Manager ---
sudo pacman -S --needed --noconfirm \
    keepassxc

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

# --- Browser ---
sudo pacman -S --needed --noconfirm \
    firefox

# --- Image Viewer ---
sudo pacman -S --needed --noconfirm \
    swayimg

# --- ToDo List ---
sudo pacman -S --needed --noconfirm
    task \
    taskwarrior-tui

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

echo "==> Installing vim-plug..."
if [ ! -f "$HOME/.vim/autoload/plug.vim" ]; then
    curl -fLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

echo "==> Installing Vim plugins..."
vim +PlugInstall +qall

echo
echo "======================================"
echo "   Arch Linux setup complete!"
echo "======================================"
echo
echo "Rebooting in 3 seconds..."
sleep 3
sudo reboot

