#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# 0. 디렉토리 및 환경 변수 설정
# ==========================================
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VIM_DIR="$HOME/.vim"
AUTOLOAD_DIR="$VIM_DIR/autoload"
PLUGIN_DIR="$VIM_DIR/plugin"

echo "==> [1/5] 기본 시스템 패키지 설치 (Fedora/WSL)"
if command -v dnf &> /dev/null; then
    sudo dnf check-update || true

    sudo dnf install -y \
        gcc gcc-c++ clang clang-tools-extra \
        cmake ninja-build \
        gdb valgrind \
        git curl ripgrep fzf \
        vim gvim \
        nodejs npm
else
    echo "⚠️  dnf 패키지 매니저를 찾지 못했습니다. 패키지 수동 설치가 필요할 수 있습니다."
fi

echo "==> [2/5] 디렉토리 구조 생성"
mkdir -p \
    "$AUTOLOAD_DIR" \
    "$PLUGIN_DIR" \
    "$HOME/.cache/vim-cmake"

echo "==> [3/5] 심볼릭 링크 설정"

# .vimrc
ln -sf \
    "$DOTFILES_DIR/.vimrc" \
    "$HOME/.vimrc"

# coc-settings.json
ln -sf \
    "$DOTFILES_DIR/.vim/coc-settings.json" \
    "$VIM_DIR/coc-settings.json"

# universal_cmake.vim (autoload)
if [ -f "$DOTFILES_DIR/.vim/autoload/universal_cmake.vim" ]; then
    ln -sf \
        "$DOTFILES_DIR/.vim/autoload/universal_cmake.vim" \
        "$AUTOLOAD_DIR/universal_cmake.vim"
fi

# universal_cmake.vim (plugin)
if [ -f "$DOTFILES_DIR/.vim/plugin/universal_cmake.vim" ]; then
    ln -sf \
        "$DOTFILES_DIR/.vim/plugin/universal_cmake.vim" \
        "$PLUGIN_DIR/universal_cmake.vim"
fi

echo "==> [4/5] vim-plug 설치 및 플러그인 동기화"

PLUG_VIM="$AUTOLOAD_DIR/plug.vim"

if [ ! -f "$PLUG_VIM" ]; then
    curl -fLo "$PLUG_VIM" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

# Vim 플러그인 자동 설치
vim +PlugInstall +qall

echo "==> [5/5] CoC 확장 모듈(coc-clangd) 설치"

if [ -d "$VIM_DIR/plugged/coc.nvim" ]; then
    vim -c 'CocInstall -sync coc-clangd' +qall
fi

echo "=========================================="
echo "    설치가 성공적으로 완료되었습니다!     "
echo "=========================================="

