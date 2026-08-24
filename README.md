# C/C++ Vim 개발 환경

Vim과 CMake를 중심으로 구성한 경량 C/C++ 개발 환경입니다.

## 주요 구성

* C++20 / C++23
* CMake
* CMake Presets
* CTest
* clangd + CoC
* CMake File API
* GDB
* Valgrind
* FZF
* NERDTree
* 헤더 / 소스 파일 전환
* `compile_commands.json` 자동 연동

이 설정의 목표는 **Vim과 CMake를 중심으로 한 일관된 C/C++ 개발 워크플로우**를 제공하는 것입니다.

---

# 설치

저장소를 원하는 위치에 클론합니다.

```bash
git clone https://github.com/Jun19204/dotfiles.git
cd ~/dotfiles
```

사용 중인 Linux 배포판에 맞는 설치 스크립트를 실행합니다.

### Fedora / RHEL

```bash
chmod +x install_for_fedora.sh
./install_for_fedora.sh
```

### Arch Linux

```bash
chmod +x install_for_arch.sh
./install_for_arch.sh
```

### Debian / Ubuntu

```bash
chmod +x install_for_debian.sh
./install_for_debian.sh
```

설치 스크립트는 저장소 위치를 자동으로 감지하고 필요한 패키지를 설치한 뒤 다음 파일 및 도구들을 구성합니다.

* `.vimrc`
* `coc-settings.json`
* `universal_cmake.vim`
* vim-plug
* Vim 플러그인
* coc-clangd
* C/C++ 개발 도구

---

# 주요 기능

## CMake 기반 워크플로우

전체 개발 워크플로우를 CMake를 중심으로 구성합니다.

```text
Configure
    ↓
Build
    ↓
Run
    ↓
Test
    ↓
Debug
```

개별 컴파일러 명령어를 직접 관리하는 대신 **CMake를 Source of Truth로 사용**합니다.

따라서 동일한 Vim 환경에서 다음과 같은 프로젝트를 처리할 수 있습니다.

* 단일 / 단순 CMake 프로젝트
* 다중 타겟 프로젝트
* CMake Presets 프로젝트
* Debug 빌드
* Release 빌드
* AddressSanitizer 빌드
* UndefinedBehaviorSanitizer 빌드
* Coverage 빌드
* CTest 프로젝트

---

# 프로젝트 루트 자동 감지

프로젝트 루트 디렉토리를 자동으로 탐색합니다.

탐색 순서는 다음과 같습니다.

```text
CMakeUserPresets.json
        ↓
CMakePresets.json
        ↓
CMakeLists.txt
        ↓
.git
        ↓
현재 작업 디렉토리
```

따라서 프로젝트 디렉토리를 별도로 지정하지 않아도 바로 작업할 수 있습니다.

---

# CMake Presets

다음 두 파일을 모두 지원합니다.

```text
CMakePresets.json
CMakeUserPresets.json
```

`include`를 사용하는 프리셋 파일과 프리셋 상속도 지원합니다.

예:

```json
{
  "inherits": "base"
}
```

일반적으로 다음과 같은 빌드 구성을 사용할 수 있습니다.

```text
debug
release
asan
ubsan
coverage
```

## Configure Preset 선택

```text
Space bp
```

## Build Preset 선택

```text
Space bb
```

---

# Fallback CMake 설정

프로젝트에서 CMake Presets를 사용하지 않아도 됩니다.

Configure Preset이 선택되지 않은 경우 다음과 같은 기본 CMake 명령을 사용합니다.

```bash
cmake -S <source-dir> \
      -B <build-dir> \
      -DCMAKE_BUILD_TYPE=<config> \
      -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
```

Ninja가 설치되어 있다면 빌드 제너레이터로 Ninja를 자동으로 사용합니다.

기본 빌드 디렉토리는 프로젝트 외부의 다음 위치에 생성됩니다.

```text
~/.cache/vim-cmake/
```

예:

```text
~/.cache/vim-cmake/
└── <project-hash>/
    ├── debug/
    ├── release/
    ├── relwithdebinfo/
    └── minsizerel/
```

---

# clangd + CoC

LSP 환경은 다음 구성 요소를 사용합니다.

```text
coc.nvim
    ↓
coc-clangd
    ↓
clangd
```

CMake에서 생성된 `compile_commands.json`을 clangd와 자동으로 연결합니다.

예:

```text
project/
├── build/
│   └── asan/
│       └── compile_commands.json
│
├── src/
└── CMakeLists.txt
```

현재 선택된 빌드 디렉토리를 clangd가 직접 참조합니다.

Universal CMake 연동 기능은 clangd를 다음과 같은 방식으로 구성합니다.

```text
--compile-commands-dir=<현재-빌드-디렉토리>
--background-index
--clang-tidy
```

추가 clangd 설정은 다음 파일에서 변경할 수 있습니다.

```text
~/.vim/coc-settings.json
```

예:

```json
{
  "clangd.arguments": [
    "--completion-style=detailed",
    "--header-insertion=iwyu",
    "--fallback-style=llvm",
    "-query-driver=/usr/bin/g++"
  ]
}
```

---

# CMake File API

CMake File API를 사용하여 프로젝트의 타겟 정보를 자동으로 탐색합니다.

Configure 실행 전에 `codemodel-v2` 쿼리를 생성하고, CMake가 생성한 타겟 정보를 읽어 다음과 같이 분류합니다.

```text
EXECUTABLE
STATIC_LIBRARY
SHARED_LIBRARY
UTILITY
```

이 중 실제 아티팩트가 생성되는 `EXECUTABLE` 타겟만 실행 및 디버깅 대상으로 사용합니다.

예:

```text
my_app
  EXECUTABLE
  -> /home/user/project/build/my_app

unit_tests
  EXECUTABLE
  -> /home/user/project/build/unit_tests

my_library
  STATIC_LIBRARY
  -> /home/user/project/build/libmy_library.a
```

## 실행 타겟 선택

```text
Space bt
```

## 전체 타겟 보기

```text
Space ba
```

---

# AddressSanitizer (ASan)

AddressSanitizer는 CMake 또는 CMake Presets를 통해 지원합니다.

Vim 설정 자체에서 Sanitizer 플래그를 직접 주입하지 않고, **선택된 CMake 빌드 설정에 따라 컴파일 옵션을 결정**합니다.

예:

```json
{
  "name": "asan",
  "inherits": "base",
  "binaryDir": "${sourceDir}/build/asan",
  "cacheVariables": {
    "CMAKE_BUILD_TYPE": "Debug",
    "CMAKE_CXX_FLAGS": "-fsanitize=address -fno-omit-frame-pointer",
    "CMAKE_EXE_LINKER_FLAGS": "-fsanitize=address",
    "CMAKE_EXPORT_COMPILE_COMMANDS": "ON"
  }
}
```

워크플로우:

```text
Space bp
    ↓
asan 선택

Space bb
    ↓
asan 빌드 프리셋 선택

F5
    ↓
빌드

F6
    ↓
실행
```

선택된 빌드 디렉토리는 clangd에도 자동으로 연결됩니다.

---

# GDB

GDB는 Vim의 터미널 버퍼 내부에서 실행됩니다.

## GDB 시작

```text
F8
```

기본적으로 다음 명령을 사용하여 프로그램을 시작합니다.

```gdb
break main
run
```

## 디버깅 제어

| 단축키   | 동작         |
| ----- | ---------- |
| `F10` | `next`     |
| `F11` | `step`     |
| `F12` | `continue` |

현재 커서 위치에 중단점을 설정할 수도 있습니다.

```text
Space bk
```

---

# Valgrind

선택된 실행 타겟에 대해 Valgrind를 실행합니다.

```text
Space bv
```

다음 옵션이 기본적으로 적용됩니다.

```text
--leak-check=full
--show-leak-kinds=all
--track-origins=yes
```

---

# 헤더 / 소스 전환

`vim-fswitch`를 사용하여 C/C++ 소스 파일과 헤더 파일 사이를 빠르게 전환할 수 있습니다.

예:

```text
main.cpp
    ↕
main.hpp
```

또는:

```text
example.cc
    ↕
example.h
```

탐색 경로:

```text
src/
include/
../src/
../include/
tests/
```

## 단축키

```text
F4
```

---

# 설정 파일 구조

예상되는 저장소 구조는 다음과 같습니다.

```text
dotfiles/
├── .vimrc
│
├── .vim/
│   ├── coc-settings.json
│   │
│   ├── autoload/
│   │   └── universal_cmake.vim
│   │
│   └── plugin/
│       └── universal_cmake.vim
│
├── install_for_fedora.sh
├── install_for_arch.sh
├── install_for_debian.sh
│
└── README.md
```

설치 스크립트는 다음 파일들에 대한 심볼릭 링크를 생성합니다.

```text
~/.vimrc
~/.vim/coc-settings.json
~/.vim/autoload/universal_cmake.vim
~/.vim/plugin/universal_cmake.vim
```

---

# 단축키 매핑

Leader 키는 `Space`입니다.

```text
<Leader> = Space
```

## 파일 및 탐색

| 단축키        | 동작            |
| ---------- | ------------- |
| `Ctrl+n`   | NERDTree 토글   |
| `Ctrl+p`   | FZF 파일 검색     |
| `Space rg` | ripgrep 검색    |
| `F4`       | 헤더 / 소스 파일 전환 |

---

## clangd / CoC

| 단축키        | 동작             |
| ---------- | -------------- |
| `gd`       | 정의로 이동         |
| `gy`       | 타입 정의로 이동      |
| `gi`       | 구현으로 이동        |
| `gr`       | 참조 찾기          |
| `K`        | Hover 정보 표시    |
| `Space rn` | 심볼 이름 변경       |
| `Space cf` | 코드 포맷팅         |
| `F1`       | Inlay Hints 토글 |

LSP 포맷터를 사용할 수 없는 경우 기본적으로 다음 명령을 사용합니다.

```vim
gg=G
```

---

## 빌드 / 실행 / 테스트 / 디버깅

| 단축키  | 동작                 |
| ---- | ------------------ |
| `F5` | 저장 후 빌드            |
| `F6` | 저장 후 빌드 및 실행       |
| `F7` | 저장 후 빌드 및 CTest 실행 |
| `F8` | 저장 후 빌드 및 GDB 시작   |

---

## CMake 설정

| 단축키        | 동작                  |
| ---------- | ------------------- |
| `Space bc` | 프로젝트 Configure      |
| `Space bp` | Configure Preset 선택 |
| `Space bb` | Build Preset 선택     |

---

## 타겟 관리

| 단축키        | 동작             |
| ---------- | -------------- |
| `Space bt` | 실행 가능 타겟 선택    |
| `Space br` | 빌드 및 실행        |
| `Space ba` | 전체 CMake 타겟 보기 |

---

## 테스트

| 단축키        | 동작              |
| ---------- | --------------- |
| `Space tb` | CTest 실행        |
| `Space tc` | 현재 파일 관련 테스트 실행 |
| `Space bv` | Valgrind 실행     |

---

## 디버깅

| 단축키        | 동작             |
| ---------- | -------------- |
| `Space bd` | GDB 시작         |
| `Space bk` | 현재 줄에 중단점 설정   |
| `F10`      | GDB `next`     |
| `F11`      | GDB `step`     |
| `F12`      | GDB `continue` |

---

## 프로젝트 / clangd

| 단축키        | 동작                                |
| ---------- | --------------------------------- |
| `Space cs` | CMake 상태 표시                       |
| `Space cr` | 현재 프로젝트 상태 초기화                    |
| `Space cl` | `compile_commands.json` 심볼릭 링크 생성 |

---

# Vim 명령어

## 프로젝트

```vim
:CMakeRoot
:CMakeStatus
:CMakeReset
```

---

## Configure 및 빌드

```vim
:CMakeConfigure
:CMakeBuild
:CMakeRun
```

---

## Preset

```vim
:CMakeSelectConfigurePreset
:CMakeSelectBuildPreset
```

---

## 타겟

```vim
:CMakeSelectTarget
:CMakeTargets
```

---

## 테스트

CTest 전체 실행:

```vim
:CMakeTest
```

특정 테스트 실행:

```vim
:CMakeTest <test-name>
```

현재 파일 기반 테스트 실행:

```vim
:CMakeTestCurrent
```

---

## 디버깅

GDB 시작:

```vim
:CMakeGDB
```

실행 중인 GDB 세션으로 명령 전달:

```vim
:CMakeGDBSend next
```

현재 커서 위치에 중단점 설정:

```vim
:CMakeBreakpoint
```

---

## clangd

clangd 설정 업데이트:

```vim
:CMakeUpdateClangd
```

현재 빌드의 `compile_commands.json`을 프로젝트 루트로 심볼릭 링크:

```vim
:CMakeLinkCompileCommands
```

---

# 일반적인 워크플로우

## 단순 CMake 프로젝트

소스 파일을 엽니다.

```bash
vim src/main.cpp
```

빌드:

```text
F5
```

CMake Preset이 선택되어 있지 않다면 Fallback 설정이 사용됩니다.

실행:

```text
F6
```

---

## CMake Presets 프로젝트

Configure Preset 선택:

```text
Space bp
```

Build Preset 선택:

```text
Space bb
```

빌드:

```text
F5
```

실행:

```text
F6
```

---

## 다중 실행 타겟 프로젝트

예를 들어 다음과 같은 실행 타겟이 있다고 가정합니다.

```text
app
server
client
unit_tests
```

실행 타겟 선택:

```text
Space bt
```

이후:

```text
F6
```

선택한 타겟을 빌드하고 실행합니다.

---

## 디버깅 워크플로우

GDB 시작:

```text
F8
```

실행 제어:

```text
F10    next
F11    step
F12    continue
```

중단점 설정:

```text
Space bk
```

---

## 메모리 분석

Valgrind 실행:

```text
Space bv
```

---

# compile_commands.json

활성화된 빌드 디렉토리의 `compile_commands.json`을 clangd가 직접 참조합니다.

프로젝트 루트에 `compile_commands.json`이 존재하는 것을 전제로 하는 외부 도구를 위해 심볼릭 링크를 생성할 수도 있습니다.

```text
Space cl
```

예:

```text
project/
├── compile_commands.json
│   -> build/debug/compile_commands.json
│
├── build/
│   └── debug/
│       └── compile_commands.json
│
├── src/
└── CMakeLists.txt
```

---

# 프로젝트 예시

```text
project/
├── CMakeLists.txt
├── CMakePresets.json
│
├── include/
│   └── example.hpp
│
├── src/
│   ├── main.cpp
│   └── example.cpp
│
└── tests/
    └── example_test.cpp
```

전형적인 개발 흐름:

```text
main.cpp 열기
        ↓
Space bp
        ↓
debug 선택
        ↓
F5
        ↓
빌드
        ↓
F6
        ↓
실행
```

디버깅:

```text
F8
```

메모리 분석:

```text
Space bv
```

---

# 설계 개요

전체 구조는 다음과 같습니다.

```text
                    ┌─────────────┐
                    │     Vim     │
                    └──────┬──────┘
                           │
                           ▼
                ┌────────────────────┐
                │  Universal CMake   │
                └─────────┬──────────┘
                          │
          ┌───────────────┼────────────────┐
          │               │                │
          ▼               ▼                ▼
      Configure         Build           File API
          │               │                │
          ▼               ▼                ▼
 compile_commands     Executables       Targets
          │               │
          ▼               ▼
        clangd         Run / Test
          │               │
          ▼               ▼
       CoC / LSP       GDB / Valgrind
```

이 설정은 **CMake를 단일 진실 공급원(Source of Truth)**으로 사용하는 것을 핵심 설계 원칙으로 합니다.

CMake가 다음 항목을 관리합니다.

* 빌드 설정
* 컴파일러 플래그
* Sanitizer
* Include 경로
* 실행 가능 타겟
* `compile_commands.json`

Vim은 이러한 CMake 기반 워크플로우를 제어하기 위한 인터페이스 역할을 합니다.

즉, Vim에서 별도의 컴파일러 옵션이나 실행 파일 경로를 직접 관리하기보다는 **CMake 프로젝트의 설정을 그대로 활용**하는 것을 목표로 합니다.

---

# 라이선스

이 저장소는 개인용 C/C++ 개발 Vim 설정을 담고 있습니다.

자유롭게 분석, 수정 및 본인의 개발 환경에 맞게 재구성하여 사용할 수 있습니다.

