#!/usr/bin/env bash

set -Eeuo pipefail

trap 'printf "\n[ERROR] Line %s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR

log()  { printf '\n==> %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die()  { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

# Run as a regular user with sudo privileges, not as root.
(( EUID != 0 )) || die 'Run this script as your normal user, without sudo.'
[[ -f /etc/arch-release ]] || die 'This script is intended for Arch Linux.'
command -v pacman >/dev/null || die 'pacman is not available.'
command -v sudo >/dev/null || die 'sudo is not available.'

DOTFILES_URL='https://github.com/badboibasti/dotfiles.git'
DOTFILES_DIR="$HOME/.dotfiles"

# Ask for sudo credentials before starting the installation.
sudo -v

log 'Installing/updating packages...'
packages=(
    # Hyprland / Wayland
    hyprland
    hyprpaper
    hyprlauncher
    hyprlock
    hypridle
    hyprsunset
    brightnessctl
    xdg-desktop-portal
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    wl-clipboard
    waybar
    xorg-xwayland

    # Audio / media
    pipewire
    pipewire-alsa
    pipewire-pulse
    wireplumber
    spotify-launcher
    pavucontrol

    # Terminal / fonts
    kitty
    ttf-hack
    terminus-font
    noto-fonts
    noto-fonts-emoji

    # CLI / development
    vim
    fzf
    ripgrep
    fastfetch
    git
    unzip
    wget
    curl
    man-db
    man-pages
    tree

    # Networking / VPN
    networkmanager
    network-manager-applet
    proton-vpn-cli
    gnome-keyring

    # Desktop apps
    qbittorrent
    keepassxc
    firefox
    swayimg
    polkit-gnome
    syncthing

    # Bluetooth
    bluez
    bluez-utils
    blueman

    # Screenshots
    flameshot

    # Tasks
    task
    taskwarrior-tui

    # Virtualization / QEMU-KVM
    qemu-desktop
    libvirt
    virt-manager
    virt-viewer
    dnsmasq
    edk2-ovmf
)

# One transaction reduces unnecessary pacman calls and avoids partial upgrades.
sudo pacman -Syu --needed "${packages[@]}"

log 'Configuring the TTY font (preserving your keyboard layout)...'
if sudo grep -q '^FONT=' /etc/vconsole.conf 2>/dev/null; then
    sudo sed -i 's/^FONT=.*/FONT=ter-v32b/' /etc/vconsole.conf
else
    printf 'FONT=ter-v32b\n' | sudo tee -a /etc/vconsole.conf >/dev/null
fi

log 'Enabling system services...'
sudo systemctl enable --now NetworkManager.service
sudo systemctl enable --now bluetooth.service
sudo systemctl enable --now libvirtd.service

log 'Enabling Syncthing for your user...'
if ! systemctl --user enable --now syncthing.service; then
    warn 'Could not start the Syncthing user service in this session.'
    warn 'Log in normally, then run: systemctl --user enable --now syncthing.service'
fi

log 'Configuring libvirt...'
sudo usermod -aG libvirt "$USER"

if ! sudo virsh -c qemu:///system net-info default >/dev/null 2>&1; then
    if [[ -f /usr/share/libvirt/networks/default.xml ]]; then
        sudo virsh -c qemu:///system net-define /usr/share/libvirt/networks/default.xml
    else
        warn 'libvirt default network definition not found; configure it manually.'
    fi
fi

if sudo virsh -c qemu:///system net-info default >/dev/null 2>&1; then
    sudo virsh -c qemu:///system net-autostart default
    if ! sudo virsh -c qemu:///system net-list --name | grep -Fxq default; then
        if ! sudo virsh -c qemu:///system net-start default; then
            warn 'The default libvirt network could not be started.'
            warn 'Check: sudo virsh -c qemu:///system net-list --all'
        fi
    fi
fi

log 'Setting up dotfiles...'
mkdir -p "$HOME/.config"

if [[ ! -e "$DOTFILES_DIR" && ! -L "$DOTFILES_DIR" ]]; then
    git clone -- "$DOTFILES_URL" "$DOTFILES_DIR"
elif [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    die "$DOTFILES_DIR exists but is not a Git checkout; refusing to overwrite it."
else
    log 'Using existing dotfiles checkout (not pulling automatically).'
fi

link_dotfile() {
    local source=$1
    local target=$2

    if [[ ! -e "$source" ]]; then
        warn "Missing dotfile source: $source (skipping)"
        return 0
    fi

    # Replace regular files or symlinks without keeping backups.
    # Never delete existing directories and their contents automatically.
    if [[ -d "$target" && ! -L "$target" ]]; then
        warn "Existing directory: $target (skipping; remove it manually if needed)"
        return 0
    fi

    ln -sfnT -- "$source" "$target"
}

link_dotfile "$DOTFILES_DIR/hypr" "$HOME/.config/hypr"
link_dotfile "$DOTFILES_DIR/kitty" "$HOME/.config/kitty"
link_dotfile "$DOTFILES_DIR/fastfetch" "$HOME/.config/fastfetch"
link_dotfile "$DOTFILES_DIR/bash/.bashrc" "$HOME/.bashrc"
link_dotfile "$DOTFILES_DIR/vim/.vimrc" "$HOME/.vimrc"

log 'Installing vim-plug...'
if [[ ! -f "$HOME/.vim/autoload/plug.vim" ]]; then
    plug_tmp=$(mktemp)
    if ! curl --fail --location --show-error --retry 3 \
        --output "$plug_tmp" \
        'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'; then
        rm -f -- "$plug_tmp"
        die 'Failed to download vim-plug.'
    fi
    install -Dm644 -- "$plug_tmp" "$HOME/.vim/autoload/plug.vim"
    rm -f -- "$plug_tmp"
fi

if [[ -f "$HOME/.vimrc" ]] && grep -q 'plug#begin' "$HOME/.vimrc"; then
    log 'Installing Vim plugins...'
    vim -Nu "$HOME/.vimrc" -n -es -i NONE '+PlugInstall --sync' '+qa'
else
    warn 'No vim-plug configuration found in ~/.vimrc; skipping PlugInstall.'
fi

log 'Setup complete!'
printf '%s\n' 'Log out and back in to activate libvirt group membership.'
printf '%s\n' 'Hyprland needs to start your polkit agent/keyring app from your session config.'
printf '%s\n' 'Screenshot tool: flameshot gui'

if [[ -t 0 ]]; then
    read -r -p 'Reboot now? [y/N] ' answer
    case "$answer" in
        [Yy]|[Yy][Ee][Ss]) sudo reboot ;;
        *) printf '%s\n' 'Reboot skipped.' ;;
    esac
fi

