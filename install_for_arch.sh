#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# 0. 디렉토리 및 환경 변수 설정
# ==========================================

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VIM_DIR="$HOME/.vim"
AUTOLOAD_DIR="$VIM_DIR/autoload"
PLUGIN_DIR="$VIM_DIR/plugin"
CACHE_DIR="$HOME/.cache/vim-cmake"

VIMRC_SOURCE="$DOTFILES_DIR/.vimrc"
COC_SETTINGS_SOURCE="$DOTFILES_DIR/.vim/coc-settings.json"

UNIVERSAL_CMAKE_AUTOLOAD_SOURCE=\
"$DOTFILES_DIR/.vim/autoload/universal_cmake.vim"

UNIVERSAL_CMAKE_PLUGIN_SOURCE=\
"$DOTFILES_DIR/.vim/plugin/universal_cmake.vim"

PLUG_VIM="$AUTOLOAD_DIR/plug.vim"
COC_DIR="$VIM_DIR/plugged/coc.nvim"

# ==========================================
# 1. Arch Linux 시스템 패키지 설치
# ==========================================

echo "==> [1/5] Arch Linux 시스템 패키지 설치 (pacman)"

if ! command -v pacman >/dev/null 2>&1; then
    echo "❌ pacman 패키지 매니저를 찾지 못했습니다."
    echo "   Arch Linux 환경인지 확인해주세요."
    exit 1
fi

sudo pacman -Syu --needed --noconfirm \
    base-devel \
    gcc \
    clang \
    cmake \
    ninja \
    gdb \
    valgrind \
    git \
    curl \
    ripgrep \
    fzf \
    gvim \
    nodejs \
    npm

# ==========================================
# Vim clipboard 기능 검증
# ==========================================

echo "==> Vim clipboard 지원 확인"

if ! command -v vim >/dev/null 2>&1; then
    echo "❌ vim 실행 파일을 찾지 못했습니다."
    exit 1
fi

if ! vim --version | grep -q '^+clipboard'; then
    echo "❌ 현재 vim은 +clipboard 기능을 지원하지 않습니다."
    echo
    echo "현재 Vim clipboard 관련 feature:"
    vim --version | grep -E 'clipboard|wayland|X11|xterm' || true
    exit 1
fi

echo "    ✓ Vim +clipboard 지원 확인"

# ==========================================
# 2. 디렉토리 구조 생성
# ==========================================

echo "==> [2/5] 디렉토리 구조 생성"

mkdir -p \
    "$AUTOLOAD_DIR" \
    "$PLUGIN_DIR" \
    "$CACHE_DIR"

# ==========================================
# 3. 필수 파일 검증 및 심볼릭 링크 설정
# ==========================================

echo "==> [3/5] 필수 파일 검증 및 심볼릭 링크 설정"

REQUIRED_FILES=(
    "$VIMRC_SOURCE"
    "$COC_SETTINGS_SOURCE"
    "$UNIVERSAL_CMAKE_AUTOLOAD_SOURCE"
    "$UNIVERSAL_CMAKE_PLUGIN_SOURCE"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "❌ 필수 파일을 찾을 수 없습니다:"
        echo "   $file"
        exit 1
    fi
done

echo "    ✓ 필수 설정 파일 확인"

# .vimrc
ln -sfn \
    "$VIMRC_SOURCE" \
    "$HOME/.vimrc"

# coc-settings.json
ln -sfn \
    "$COC_SETTINGS_SOURCE" \
    "$VIM_DIR/coc-settings.json"

# universal_cmake.vim (autoload)
ln -sfn \
    "$UNIVERSAL_CMAKE_AUTOLOAD_SOURCE" \
    "$AUTOLOAD_DIR/universal_cmake.vim"

# universal_cmake.vim (plugin)
ln -sfn \
    "$UNIVERSAL_CMAKE_PLUGIN_SOURCE" \
    "$PLUGIN_DIR/universal_cmake.vim"

# ==========================================
# 4. vim-plug 설치 및 플러그인 동기화
# ==========================================

echo "==> [4/5] vim-plug 설치 및 플러그인 동기화"

if [[ ! -f "$PLUG_VIM" ]]; then
    echo "==> vim-plug 다운로드"

    curl \
        --fail \
        --location \
        --retry 3 \
        --create-dirs \
        --output "$PLUG_VIM" \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

if [[ ! -f "$PLUG_VIM" ]]; then
    echo "❌ vim-plug 설치에 실패했습니다."
    exit 1
fi

echo "==> Vim 플러그인 설치"

vim +PlugInstall +qall

# ==========================================
# 5. CoC 확장 모듈 설치
# ==========================================

echo "==> [5/5] CoC 확장 모듈 (coc-clangd) 설치"

if [[ ! -d "$COC_DIR" ]]; then
    echo "❌ coc.nvim 디렉토리를 찾지 못했습니다."
    echo "   vim-plug 플러그인 설치가 정상적으로 완료되었는지 확인해주세요."
    exit 1
fi

vim -c 'CocInstall -sync coc-clangd' +qall

echo
echo "=========================================="
echo "    설치가 성공적으로 완료되었습니다!     "
echo "=========================================="
