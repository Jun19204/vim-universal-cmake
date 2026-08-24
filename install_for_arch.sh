#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# C/C++ Vim Development Environment Installer for Arch Linux
# ============================================================

readonly SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1
    pwd -P
)"

readonly DOTFILES_DIR="$SCRIPT_DIR"

readonly VIM_DIR="$HOME/.vim"
readonly VIMRC="$HOME/.vimrc"

readonly PLUG_VIM="$VIM_DIR/autoload/plug.vim"

readonly VIM_PLUG_URL="https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"

# ============================================================
# Utility
# ============================================================

info() {
    printf '\n\033[1;34m==> %s\033[0m\n' "$1"
}

success() {
    printf '\033[1;32m[OK]\033[0m %s\n' "$1"
}

warning() {
    printf '\033[1;33m[WARN]\033[0m %s\n' "$1"
}

error() {
    printf '\033[1;31m[ERROR]\033[0m %s\n' "$1" >&2
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ============================================================
# Check Arch Linux
# ============================================================

check_arch() {
    if [[ ! -f /etc/arch-release ]]; then
        warning "This installer is designed for Arch Linux."
        warning "Continuing anyway..."
    fi
}

# ============================================================
# Check Repository Structure
# ============================================================

check_repository() {
    info "Checking repository structure"

    local required_files=(
        "$DOTFILES_DIR/.vimrc"
        "$DOTFILES_DIR/.vim/coc-settings.json"
        "$DOTFILES_DIR/.vim/autoload/universal_cmake.vim"
        "$DOTFILES_DIR/.vim/plugin/universal_cmake.vim"
    )

    local file

    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            error "Required file not found:"
            error "  $file"
            exit 1
        fi
    done

    success "Repository structure is valid"
}

# ============================================================
# Install Required Packages
# ============================================================

install_packages() {
    info "Checking required system packages"

    local packages=(
        vim
        gcc
        cmake
        ninja
        clang
        nodejs
        curl
        git
        gdb
        valgrind
        ripgrep
    )

    local missing=()
    local package

    for package in "${packages[@]}"; do
        if ! pacman -Q "$package" >/dev/null 2>&1; then
            missing+=("$package")
        fi
    done

    if [[ "${#missing[@]}" -eq 0 ]]; then
        success "All required packages are already installed"
        return
    fi

    printf 'The following packages will be installed:\n'

    for package in "${missing[@]}"; do
        printf '  - %s\n' "$package"
    done

    sudo pacman -S --needed --noconfirm "${missing[@]}"

    success "Required packages installed"
}

# ============================================================
# Create Directories
# ============================================================

create_directories() {
    info "Creating Vim directories"

    mkdir -p \
        "$VIM_DIR" \
        "$VIM_DIR/autoload" \
        "$VIM_DIR/plugin"

    success "Vim directories ready"
}

# ============================================================
# Backup
# ============================================================

backup_if_needed() {
    local target="$1"

    if [[ ! -e "$target" && ! -L "$target" ]]; then
        return
    fi

    if [[ -L "$target" ]]; then
        return
    fi

    local backup="${target}.backup.$(date +%Y%m%d_%H%M%S)"

    warning "Existing file found: $target"
    warning "Creating backup: $backup"

    mv "$target" "$backup"

    success "Backup created"
}

# ============================================================
# Create Symbolic Links
# ============================================================

create_symlink() {
    local source="$1"
    local target="$2"

    if [[ -L "$target" ]]; then
        local current_target
        local source_target

        current_target="$(readlink -f "$target" 2>/dev/null || true)"
        source_target="$(readlink -f "$source")"

        if [[ "$current_target" == "$source_target" ]]; then
            success "Already linked: $target"
            return
        fi
    fi

    backup_if_needed "$target"

    ln -sfn "$source" "$target"

    success "Linked: $target"
}

link_dotfiles() {
    info "Linking Vim configuration"

    create_symlink \
        "$DOTFILES_DIR/.vimrc" \
        "$VIMRC"

    create_symlink \
        "$DOTFILES_DIR/.vim/coc-settings.json" \
        "$VIM_DIR/coc-settings.json"

    create_symlink \
        "$DOTFILES_DIR/.vim/autoload/universal_cmake.vim" \
        "$VIM_DIR/autoload/universal_cmake.vim"

    create_symlink \
        "$DOTFILES_DIR/.vim/plugin/universal_cmake.vim" \
        "$VIM_DIR/plugin/universal_cmake.vim"
}

# ============================================================
# Install vim-plug
# ============================================================

install_vim_plug() {
    info "Checking vim-plug"

    if [[ -f "$PLUG_VIM" ]]; then
        success "vim-plug already installed"
        return
    fi

    curl \
        --fail \
        --location \
        --create-dirs \
        --output "$PLUG_VIM" \
        "$VIM_PLUG_URL"

    success "vim-plug installed"
}

# ============================================================
# Install Vim Plugins
# ============================================================

install_vim_plugins() {
    info "Installing Vim plugins"

    vim \
        -u "$VIMRC" \
        +'PlugInstall --sync' \
        +qa

    success "Vim plugins installed"
}

# ============================================================
# Install coc-clangd
# ============================================================

install_coc_clangd() {
    info "Checking coc-clangd"

    if [[ -d "$VIM_DIR/coc/extensions/node_modules/coc-clangd" ]]; then
        success "coc-clangd already installed"
        return
    fi

    vim \
        -u "$VIMRC" \
        +'CocInstall -sync coc-clangd' \
        +qa

    success "coc-clangd installed"
}

# ============================================================
# Verify Environment
# ============================================================

verify_environment() {
    info "Verifying development environment"

    local commands=(
        vim
        g++
        cmake
        ninja
        clangd
        node
        gdb
        valgrind
        rg
    )

    local cmd
    local failed=0

    for cmd in "${commands[@]}"; do
        if command_exists "$cmd"; then
            success "$cmd -> $(command -v "$cmd")"
        else
            error "$cmd was not found"
            failed=1
        fi
    done

    if [[ "$failed" -ne 0 ]]; then
        error "Environment verification failed"
        exit 1
    fi
}

# ============================================================
# Print Summary
# ============================================================

print_summary() {
    printf '\n'
    printf '============================================================\n'
    printf ' C/C++ Vim development environment setup complete\n'
    printf '============================================================\n'

    printf '\nRepository:\n'
    printf '  %s\n' "$DOTFILES_DIR"

    printf '\nConfiguration:\n'
    printf '  ~/.vimrc\n'
    printf '  ~/.vim/coc-settings.json\n'
    printf '  ~/.vim/autoload/universal_cmake.vim\n'
    printf '  ~/.vim/plugin/universal_cmake.vim\n'

    printf '\nVersions:\n'
    printf '  Vim:      %s\n' "$(vim --version | head -n 1)"
    printf '  GCC:      %s\n' "$(g++ --version | head -n 1)"
    printf '  CMake:    %s\n' "$(cmake --version | head -n 1)"
    printf '  clangd:   %s\n' "$(clangd --version | head -n 1)"
    printf '  Node.js:  %s\n' "$(node --version)"

    printf '\nStart Vim with:\n\n'
    printf '  vim\n\n'
}

# ============================================================
# Main
# ============================================================

main() {
    printf '\n'
    printf '============================================================\n'
    printf ' C/C++ Vim Development Environment Setup\n'
    printf '============================================================\n'

    check_arch
    check_repository
    install_packages
    create_directories
    link_dotfiles
    install_vim_plug
    install_vim_plugins
    install_coc_clangd
    verify_environment
    print_summary
}

main "$@"
