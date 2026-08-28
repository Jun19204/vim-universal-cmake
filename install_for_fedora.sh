#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# Fedora Vim / C++ Development Environment
# ==========================================

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

# 설치/자동화에는 일반 Vim 사용
INSTALL_VIM=(vim)

# 실제 터미널에서 사용하는 Vim
# Fedora vim-X11의 GVim terminal mode
VIM_CMD=(gvim -v)


# ==========================================
# 1. Fedora 시스템 패키지 설치
# ==========================================

echo "==> [1/5] Fedora 시스템 패키지 설치 (dnf)"

if ! command -v dnf >/dev/null 2>&1; then
    echo "❌ dnf 패키지 매니저를 찾지 못했습니다."
    echo "   Fedora 환경인지 확인해주세요."
    exit 1
fi

sudo dnf install -y \
    gcc \
    gcc-c++ \
    clang \
    clang-tools-extra \
    cmake \
    ninja-build \
    gdb \
    valgrind \
    git \
    curl \
    ripgrep \
    fzf \
    vim-enhanced \
    vim-X11 \
    nodejs \
    nodejs-npm


# ==========================================
# Vim 및 npm 실행 파일 검증
# ==========================================

echo "==> Vim 실행 파일 확인"

if ! command -v vim >/dev/null 2>&1; then
    echo "❌ vim 실행 파일을 찾지 못했습니다."
    exit 1
fi

if ! command -v gvim >/dev/null 2>&1; then
    echo "❌ gvim 실행 파일을 찾지 못했습니다."
    echo "   vim-X11 패키지가 정상적으로 설치되었는지 확인해주세요."
    exit 1
fi

echo "    ✓ vim:  $(command -v vim)"
echo "    ✓ gvim: $(command -v gvim)"


# ==========================================
# GVim clipboard 지원 확인
# ==========================================

echo "==> GVim clipboard 지원 확인"

# 주의:
# set -o pipefail 환경에서
#
#     gvim --version | grep -q ...
#
# 형태를 사용하면 grep이 먼저 종료한 뒤
# gvim이 SIGPIPE(141)를 받을 수 있다.
#
# 따라서 gvim의 전체 출력을 먼저 저장한 다음 검사한다.

GVIM_VERSION="$(gvim --version)"

if ! grep -qw '+clipboard' <<< "$GVIM_VERSION"; then
    echo "❌ 현재 gvim은 +clipboard 기능을 지원하지 않습니다."
    echo
    echo "현재 gvim clipboard 관련 feature:"
    grep -E 'clipboard|wayland|X11|xterm' <<< "$GVIM_VERSION" || true
    exit 1
fi

echo "    ✓ gvim +clipboard 지원 확인"


# ==========================================
# npm 설치 확인
# ==========================================

echo "==> npm 설치 확인"

if ! command -v npm >/dev/null 2>&1; then
    echo "❌ npm 실행 파일을 찾지 못했습니다."
    exit 1
fi

echo "    ✓ npm: $(command -v npm)"


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


ln -sfn \
    "$VIMRC_SOURCE" \
    "$HOME/.vimrc"

ln -sfn \
    "$COC_SETTINGS_SOURCE" \
    "$VIM_DIR/coc-settings.json"

ln -sfn \
    "$UNIVERSAL_CMAKE_AUTOLOAD_SOURCE" \
    "$AUTOLOAD_DIR/universal_cmake.vim"

ln -sfn \
    "$UNIVERSAL_CMAKE_PLUGIN_SOURCE" \
    "$PLUGIN_DIR/universal_cmake.vim"

echo "    ✓ 심볼릭 링크 설정 완료"


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

echo "    ✓ vim-plug 확인"


echo "==> Vim 플러그인 설치"

"${INSTALL_VIM[@]}" +PlugInstall +qall


# ==========================================
# coc.nvim 설치 검증
# ==========================================

echo "==> coc.nvim 설치 확인"

if [[ ! -d "$COC_DIR" ]]; then
    echo "❌ coc.nvim 디렉토리를 찾지 못했습니다."
    echo "   vim-plug 플러그인 설치가 정상적으로 완료되었는지 확인해주세요."
    exit 1
fi

if [[ ! -f "$COC_DIR/plugin/coc.vim" ]]; then
    echo "❌ coc.nvim 설치가 올바르지 않습니다."
    echo "   다음 파일을 찾지 못했습니다:"
    echo "   $COC_DIR/plugin/coc.vim"
    exit 1
fi

echo "    ✓ coc.nvim 설치 확인"


# ==========================================
# 5. CoC 확장 모듈 설치
# ==========================================

echo "==> [5/5] CoC 확장 모듈 (coc-clangd) 설치"

"${INSTALL_VIM[@]}" \
    -c 'CocInstall -sync coc-clangd' \
    +qall


# ==========================================
# 최종 설치 검증
# ==========================================

echo
echo "==> 최종 설치 검증"

if [[ ! -f "$HOME/.vimrc" ]]; then
    echo "❌ ~/.vimrc 링크를 찾지 못했습니다."
    exit 1
fi

if [[ ! -f "$VIM_DIR/coc-settings.json" ]]; then
    echo "❌ ~/.vim/coc-settings.json 링크를 찾지 못했습니다."
    exit 1
fi

if [[ ! -f "$AUTOLOAD_DIR/universal_cmake.vim" ]]; then
    echo "❌ universal_cmake.vim autoload 파일을 찾지 못했습니다."
    exit 1
fi

if [[ ! -f "$PLUGIN_DIR/universal_cmake.vim" ]]; then
    echo "❌ universal_cmake.vim plugin 파일을 찾지 못했습니다."
    exit 1
fi

if [[ ! -d "$COC_DIR" ]]; then
    echo "❌ coc.nvim 설치를 확인할 수 없습니다."
    exit 1
fi

echo "    ✓ ~/.vimrc"
echo "    ✓ ~/.vim/coc-settings.json"
echo "    ✓ universal_cmake autoload"
echo "    ✓ universal_cmake plugin"
echo "    ✓ coc.nvim"
echo "    ✓ gvim +clipboard"


# ==========================================
# 완료
# ==========================================

echo
echo "=========================================="
echo "    설치가 성공적으로 완료되었습니다!     "
echo "=========================================="
echo
echo "터미널 Vim 실행:"
echo "    gvim -v"
echo
echo "Vim clipboard 확인:"
echo "    :version"
echo
echo "CoC 확인:"
echo "    :CocInfo"
echo
echo "Universal CMake:"
echo "    F5  Build"
echo "    F6  Run"
echo "    F7  Test"
echo "    F8  GDB"
echo
