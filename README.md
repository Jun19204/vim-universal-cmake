# WSL/Linux Modern C/C++ Vim Development Environment

CMake를 중심으로 **Vim + C/C++20/23 + clangd + CoC + CTest + GDB + ASan + Valgrind** 환경을 구성하기 위한 Dotfiles입니다.

이 환경의 핵심 목표는 Vim이 직접 컴파일 명령이나 실행 파일 경로를 관리하지 않고, **CMake를 프로젝트 설정의 Source of Truth로 사용하는 것**입니다.

* CMake Presets 지원
* Preset이 없는 프로젝트를 위한 Fallback CMake 지원
* CMake File API 기반 Target 탐색
* 다중 실행 Target 지원
* `compile_commands.json` 기반 clangd 연동
* CTest
* GDB
* Valgrind
* ASan / UBSan / Coverage 등 CMake Build Configuration 지원

---

## 핵심 구조

```text
Vim
 │
 ▼
Universal CMake
 │
 ├── Configure
 ├── Build
 ├── CMake File API
 │
 ├── clangd
 ├── Run
 ├── CTest
 ├── GDB
 └── Valgrind
```

Vim은 다음과 같은 명령을 직접 조립하지 않습니다.

```bash
g++ main.cpp -std=c++23 ...
```

대신 프로젝트의 CMake 설정을 사용합니다.

```text
CMake
 ├── Compiler
 ├── C++ Standard
 ├── Include Paths
 ├── Compile Options
 ├── Link Options
 ├── Sanitizers
 ├── Targets
 └── Tests
```

따라서 프로젝트마다 Vim 설정을 변경하지 않고, 다양한 CMake 기반 C/C++ 프로젝트를 동일한 인터페이스로 사용할 수 있습니다.

---

# 주요 기능

| 구성 요소          | 역할                      |
| -------------- | ----------------------- |
| C++20 / C++23  | 현대적인 C++ 프로젝트 개발        |
| CMake          | 빌드 시스템 및 프로젝트 설정        |
| CMake Presets  | Configure / Build 구성 선택 |
| CMake File API | 실제 Target과 Artifact 탐색  |
| clangd + CoC   | 자동완성, 진단, 코드 탐색         |
| CTest          | 프로젝트 테스트                |
| GDB            | 터미널 기반 디버깅              |
| Valgrind       | 메모리 오류 및 누수 검사          |
| FZF            | 파일 검색                   |
| NERDTree       | 파일 탐색                   |
| ripgrep        | 코드 검색                   |

지원하는 프로젝트:

* 단순한 단일 실행 파일 CMake 프로젝트
* 여러 실행 파일을 포함하는 다중 Target 프로젝트
* `CMakePresets.json` 프로젝트
* `CMakeUserPresets.json` 프로젝트
* Debug / Release 빌드
* ASan / UBSan / Coverage 구성
* CTest 기반 테스트 프로젝트
* 모노레포 내부의 독립적인 CMake 프로젝트

---

# 설치

먼저 저장소를 클론합니다.

```bash
git clone https://github.com/Jun19204/dotfiles.git
cd ~/dotfiles
```

## Fedora / RHEL

```bash
chmod +x install_for_fedora.sh
./install_for_fedora.sh
```

## Arch Linux

```bash
chmod +x install_for_arch.sh
./install_for_arch.sh
```

## Debian / Ubuntu

```bash
chmod +x install_for_debian.sh
./install_for_debian.sh
```

설치 스크립트는 필요한 패키지와 Vim 개발 환경을 구성합니다.

주요 구성:

* `.vimrc`
* `coc-settings.json`
* `universal_cmake.vim`
* vim-plug
* Vim 플러그인
* coc-clangd
* C/C++ 개발 도구

WSL/Linux 환경에서는 일반적으로 다음과 같은 도구가 필요합니다.

* GCC / Clang
* CMake
* Ninja
* GDB
* Valgrind
* Node.js
* ripgrep

---

# 설정 파일 구조

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

## `.vimrc`

Vim의 일반적인 개발 환경을 설정합니다.

* 기본 UI
* Vim 플러그인
* 일반 단축키
* CoC
* 코드 편집 환경

## `universal_cmake.vim`

C/C++ 프로젝트용 Universal CMake Workflow를 담당합니다.

주요 기능:

* 프로젝트 루트 탐색
* CMake Presets 탐색 및 선택
* Fallback CMake Configure
* Build Directory 관리
* CMake File API Query
* 실행 Target 탐색
* `compile_commands.json` 링크
* CTest
* GDB
* Valgrind

---

# 전체 워크플로우

```text
현재 파일
    │
    ▼
Project Root Detection
    │
    ▼
현재 선택된 Configure Preset 확인
    │
    ├── Configure Preset 선택됨
    │       │
    │       ▼
    │   Preset Configure / Build Preset 사용
    │
    └── Configure Preset 미선택
            │
            ▼
        Fallback CMake
            │
            ▼
         Configure
            │
            ▼
           Build
            │
      ┌─────┼─────────┐
      ▼     ▼         ▼
     Run  CTest      File API
                         │
                   ┌─────┴─────┐
                   ▼           ▼
              Executable     clangd
                   │
             ┌─────┼─────┐
             ▼     ▼     ▼
            Run   GDB Valgrind
```

일반적인 개발 흐름:

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

---

# 프로젝트 루트 자동 탐색

현재 열려 있는 파일의 위치에서 상위 디렉터리 방향으로 프로젝트 루트를 탐색합니다.

탐색 우선순위:

```text
현재 파일 위치
      │
      ▼
CMakeUserPresets.json
      │
      ▼
CMakePresets.json
      │
      ▼
CMakeLists.txt
      │
      ▼
.git
      │
      ▼
현재 Vim 작업 디렉터리
```

이 방식은 모노레포 환경에서도 현재 파일과 가장 가까운 CMake 프로젝트를 우선합니다.

예:

```text
monorepo/
├── .git/
├── engine/
│   ├── CMakeLists.txt
│   ├── CMakePresets.json
│   └── src/
│       └── renderer.cpp
│
└── tools/
    └── CMakeLists.txt
```

`engine/src/renderer.cpp`를 편집하면 프로젝트 루트로 다음 경로가 선택됩니다.

```text
monorepo/engine
```

---

# CMake Presets

다음 파일을 사용할 수 있습니다.

```text
CMakePresets.json
CMakeUserPresets.json
```

Preset의 `include`와 `inherits` 구조도 사용할 수 있습니다.

예:

```json
{
  "name": "asan",
  "inherits": "base",
  "binaryDir": "${sourceDir}/build/asan"
}
```

대표적인 구성:

```text
debug
release
asan
ubsan
coverage
```

Sanitizer나 Coverage 옵션은 Vim 설정에 하드코딩하지 않고 프로젝트의 CMake 또는 CMake Presets에서 관리합니다.

## Configure Preset 선택

```text
Space bp
```

## Build Preset 선택

```text
Space bb
```

대표적인 흐름:

```text
Space bp
    ↓
Configure Preset 선택
    ↓
Space bb
    ↓
Build Preset 선택
    ↓
F5
    ↓
Build
```

예를 들어 `asan` Preset을 선택하면 해당 Preset에 정의된:

* `binaryDir`
* 컴파일러 설정
* 컴파일 옵션
* Linker 옵션
* Sanitizer 설정

등을 그대로 사용합니다.

예:

```json
{
  "name": "asan",
  "inherits": "base",
  "cacheVariables": {
    "CMAKE_BUILD_TYPE": "Debug",
    "CMAKE_CXX_FLAGS":
      "-fsanitize=address -fno-omit-frame-pointer",
    "CMAKE_EXE_LINKER_FLAGS":
      "-fsanitize=address"
  }
}
```

---

# 중요한 Preset 동작 원칙

`CMakePresets.json`이 프로젝트에 존재한다고 해서 자동으로 Preset 방식으로 전환하지 않습니다.

**현재 Vim 세션에서 Configure Preset을 직접 선택한 경우에만 Preset을 사용합니다.**

```text
Configure Preset 선택됨
    ↓
Preset의 binaryDir 사용
```

반대로 Preset 파일이 존재하더라도 Configure Preset을 선택하지 않았다면:

```text
Configure Preset 미선택
    ↓
Fallback CMake 사용
```

이 원칙을 통해 동일한 프로젝트에서 필요에 따라 Preset 기반 빌드와 기본 Fallback 빌드를 선택할 수 있습니다.

---

# Fallback CMake

모든 프로젝트가 CMake Presets를 사용할 필요는 없습니다.

Configure Preset이 선택되지 않은 경우 기본적인 CMake Configure를 사용합니다.

개념적으로 다음과 같은 명령을 수행합니다.

```bash
cmake -S <source-dir> \
      -B <build-dir> \
      -DCMAKE_BUILD_TYPE=<config> \
      -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
```

Ninja가 설치되어 있다면 가능한 경우 Ninja Generator를 사용할 수 있습니다.

지원하는 Fallback Build Type:

```text
debug
release
relwithdebinfo
minsizerel
```

따라서 다음과 같은 단순한 프로젝트도 별도의 Preset 없이 사용할 수 있습니다.

```text
project/
├── CMakeLists.txt
└── src/
    └── main.cpp
```

```text
vim src/main.cpp
    ↓
F5
    ↓
Fallback Configure
    ↓
Build
```

---

# 빌드 디렉터리 관리

Fallback 방식에서는 프로젝트 내부에 임의의 빌드 디렉터리를 생성하지 않습니다.

기본 위치:

```text
~/.cache/vim-cmake/
```

개념적인 구조:

```text
~/.cache/vim-cmake/
└── <project-hash>/
    ├── debug/
    ├── release/
    ├── relwithdebinfo/
    └── minsizerel/
```

프로젝트마다 Hash 기반 디렉터리를 사용하므로 서로 다른 프로젝트의 빌드 결과가 충돌하지 않습니다.

---

# CMake File API와 Target 탐색

실행 파일 이름을 단순히 추측하거나 빌드 디렉터리를 검색하지 않습니다.

CMake File API를 사용하여 실제 CMake Target과 Artifact 정보를 확인합니다.

동작 흐름:

```text
Query 생성
    ↓
CMake Configure
    ↓
codemodel-v2 Reply
    ↓
Target JSON 분석
    ↓
Artifact 확인
```

대표적인 Target 종류:

```text
EXECUTABLE
STATIC_LIBRARY
SHARED_LIBRARY
UTILITY
```

실행 가능한 대상은 실제 `EXECUTABLE` Target입니다.

예:

```text
my_app
└── EXECUTABLE

unit_tests
└── EXECUTABLE

my_library
└── STATIC_LIBRARY
```

따라서 Run, GDB, Valgrind는 실제 실행 가능한 CMake Target을 기준으로 동작합니다.

---

# 실행 Target 관리

실행 가능한 Target이 하나라면 해당 Target을 바로 사용할 수 있습니다.

여러 개라면 실행 Target을 선택합니다.

## 실행 Target 선택

```text
Space bt
```

## 전체 CMake Target 확인

```text
Space ba
```

예:

```text
1. app
2. server
3. client
4. unit_tests
```

선택된 실행 Target은 다음 작업에 사용됩니다.

* Run
* GDB
* Valgrind

다중 Target 프로젝트에서는 먼저 실행 대상을 명확하게 선택하는 것을 권장합니다.

```text
Space bt
```

---

# clangd와 compile_commands.json

C/C++ LSP 환경은 다음 구조를 사용합니다.

```text
coc.nvim
    ↓
coc-clangd
    ↓
clangd
```

clangd가 정확한 정보를 제공하려면 컴파일 데이터가 필요합니다.

CMake 프로젝트에서는 일반적으로 다음 파일을 사용합니다.

```text
compile_commands.json
```

예:

```text
project/
├── build/
│   └── debug/
│       └── compile_commands.json
│
├── src/
└── CMakeLists.txt
```

이 환경은 clangd 프로세스에 `--compile-commands-dir`를 직접 전달하거나 CoC/clangd를 재시작하는 방식이 아니라, 활성 Build Directory의 컴파일 데이터를 기준으로 프로젝트 루트에 심볼릭 링크를 생성하는 방식을 사용합니다.

동작 흐름:

```text
현재 세션 build_dir 확인
        ↓
없으면 프로젝트 루트의 compile_commands.json 확인
        ↓
없으면 기존 fallback build directory 확인
        ↓
없으면 선택된 Configure Preset의 binaryDir 확인
        ↓
없으면 Configure만 실행
        ↓
현재 build_dir의 compile_commands.json 확인
        ↓
프로젝트 루트에 compile_commands.json 심볼릭 링크 생성
```

핵심은 다음과 같습니다.

> 현재 활성 Build Directory의 `compile_commands.json`이 실제 컴파일 설정의 Source of Truth입니다.

## 링크 생성

```text
Space cl
```

또는:

```vim
:CMakeLinkCompileCommands
```

이 기능은 편의를 위한 것이며, clangd 자체의 CoC 확장 설치나 `coc-settings.json` 설정까지 자동으로 구성한다고 가정해서는 안 됩니다.

---

# Build

## Build

```text
F5
```

동작:

```text
현재 파일 저장
    ↓
Project Root 확인
    ↓
Configure
    ↓
CMake Build
```

`F5`는 Build 전에 Configure를 수행합니다.

---

# Build + Run

```text
F6
```

또는:

```text
Space br
```

동작:

```text
현재 파일 저장
    ↓
Build
    ↓
실행 가능한 Target 탐색
    ↓
Target 선택 또는 기존 선택 사용
    ↓
Run
```

---

# CTest

## Build + CTest

```text
F7
```

동작:

```text
현재 파일 저장
    ↓
Build
    ↓
CTest 실행
```

테스트 구성 자체는 Vim이 아니라 CMake 프로젝트에서 관리합니다.

예:

```cmake
enable_testing()

add_test(
    NAME example_test
    COMMAND example_test
)
```

## CTest 직접 실행

```text
Space tb
```

현재 활성 Build Directory에서 CTest를 실행합니다.

## 현재 파일 관련 테스트

```text
Space tc
```

현재 파일 이름을 기준으로 CTest 테스트 이름을 필터링합니다.

예:

```text
현재 파일: example_test.cpp
    ↓
파일명: example_test
    ↓
끝의 _test 제거
    ↓
example
    ↓
ctest -R example
```

파일명이 `_test`로 끝나지 않는 경우 확장자를 제외한 파일 이름을 그대로 사용합니다.

이 기능은 현재 소스 코드나 CMake Target을 분석하여 테스트를 찾는 방식이 아니라 파일 이름 기반 패턴을 `ctest -R`에 전달하는 방식입니다.

---

# GDB

## GDB 시작

```text
F8
```

또는:

```text
Space bd
```

동작:

```text
현재 파일 저장
    ↓
CMake Build
    ↓
실행 가능한 Target 확인
    ↓
Artifact 확인
    ↓
GDB 시작
    ↓
break main
    ↓
run
```

개념적으로 다음과 같이 실행합니다.

```bash
gdb -q <executable>
```

## GDB 실행 제어

| 키   | GDB 명령     | 기능                    |
| --- | ---------- | --------------------- |
| F10 | `next`     | 현재 함수를 넘어 다음 줄 실행     |
| F11 | `step`     | 함수 내부로 진입하며 한 단계 실행   |
| F12 | `continue` | 다음 Breakpoint까지 계속 실행 |

위 단축키는 이미 실행 중인 GDB 세션에 명령을 전송합니다.

따라서 먼저 GDB를 시작해야 합니다.

## 현재 줄 Breakpoint

```text
Space bk
```

현재 커서 위치를 기준으로 GDB에 Breakpoint를 추가합니다.

개념적으로:

```text
break /absolute/path/to/source.cpp:<current-line>
```

`Space bk`는 새로운 GDB 세션을 시작하지 않습니다.

권장 흐름:

```text
F8 또는 Space bd
        ↓
GDB 시작
        ↓
Space bk
        ↓
Breakpoint 추가
        ↓
F10 / F11 / F12
```

---

# Valgrind

선택된 실행 Target을 대상으로 Valgrind를 실행합니다.

```text
Space bv
```

대표적인 옵션:

```text
--leak-check=full
--show-leak-kinds=all
--track-origins=yes
```

---

# ASan / UBSan / Coverage

Sanitizer나 Coverage 옵션은 Vim 설정에 직접 추가하지 않습니다.

프로젝트의 CMake 또는 CMake Presets에서 관리합니다.

예:

```text
Space bp
    ↓
asan 선택
    ↓
Space bb
    ↓
asan Build Preset 선택
    ↓
F5
    ↓
Build
    ↓
F6
    ↓
Run
```

ASan, UBSan, Coverage는 Universal CMake 위에서 동작하는 **빌드 구성 중 하나**입니다.

---

# Vim 개발 기능

## Source / Header 전환

```text
F4
```

예:

```text
src/example.cpp
        ↕
include/example.hpp
```

대표적인 탐색 경로:

```text
src/
include/
../src/
../include/
tests/
```

## 파일 탐색

| 키          | 기능               |
| ---------- | ---------------- |
| Ctrl + n   | NERDTree 토글      |
| Ctrl + p   | FZF 파일 검색        |
| Space + rg | ripgrep 기반 코드 검색 |

## clangd / CoC

| 키          | 기능            |
| ---------- | ------------- |
| `gd`       | 정의로 이동        |
| `gy`       | 타입 정의         |
| `gi`       | 구현으로 이동       |
| `gr`       | 참조 찾기         |
| `K`        | Hover         |
| `Space rn` | 심볼 이름 변경      |
| `Space cf` | 코드 포맷         |
| `F1`       | Inlay Hint 토글 |

---

# 전체 단축키

## Build / Run / Test / Debug

| 키   | 기능                 |
| --- | ------------------ |
| F5  | 저장 후 Build         |
| F6  | 저장 후 Build + Run   |
| F7  | 저장 후 Build + CTest |
| F8  | 저장 후 Build + GDB   |
| F10 | GDB `next`         |
| F11 | GDB `step`         |
| F12 | GDB `continue`     |

## CMake

| 키        | 기능                  |
| -------- | ------------------- |
| Space bc | Configure           |
| Space bp | Configure Preset 선택 |
| Space bb | Build Preset 선택     |
| Space bt | 실행 Target 선택        |
| Space br | Build + Run         |
| Space ba | 전체 Target 보기        |

## 기타

| 키        | 기능                         |
| -------- | -------------------------- |
| Space tb | CTest                      |
| Space tc | 현재 파일 관련 테스트               |
| Space bv | Valgrind                   |
| Space bd | GDB 시작                     |
| Space bk | 현재 줄 Breakpoint            |
| Space cs | CMake 상태                   |
| Space cr | 프로젝트 상태 초기화                |
| Space cl | `compile_commands.json` 링크 |

---

# 권장 워크플로우

## 단순한 CMake 프로젝트

```text
vim src/main.cpp
      ↓
F5
      ↓
Fallback Configure + Build
      ↓
F6
      ↓
Run
```

## CMake Presets 프로젝트

```text
Space bp
      ↓
debug / release / asan 선택
      ↓
Space bb
      ↓
Build Preset 선택
      ↓
F5
      ↓
Build
      ↓
F6
      ↓
Run
```

## 다중 실행 Target 프로젝트

```text
Space bp
      ↓
Configure Preset 선택
      ↓
F5
      ↓
Build
      ↓
Space bt
      ↓
실행 Target 선택
      ↓
F6
      ↓
Run
```

## 디버깅

```text
F8
 ↓
Build
 ↓
GDB 시작
 ↓
break main
 ↓
run
 ↓
F10 / F11 / F12
```

필요한 위치에 Breakpoint를 추가하려면:

```text
Space bk
```

---

# 핵심 설계 원칙

1. **CMake를 프로젝트 설정의 Source of Truth로 사용한다.**
2. **Vim은 컴파일러 옵션을 직접 중복 관리하지 않는다.**
3. **Configure Preset을 선택한 경우에만 해당 Preset을 사용한다.**
4. **Preset 파일이 존재해도 선택하지 않았다면 Fallback CMake를 사용한다.**
5. **Preset이 없어도 Fallback CMake로 동작한다.**
6. **프로젝트 루트는 현재 파일 위치를 기준으로 탐색한다.**
7. **실행 파일 이름을 추측하지 않고 CMake File API를 사용한다.**
8. **clangd는 현재 활성 Build Directory의 컴파일 정보를 기준으로 사용한다.**
9. **ASan, UBSan, Coverage는 CMake Build Configuration에서 관리한다.**
10. **GDB와 Valgrind는 실제 `EXECUTABLE` Target을 대상으로 동작한다.**

---

# 목표

이 설정의 목적은 특정 프로젝트에 종속된 Vim 설정을 만드는 것이 아닙니다.

다음과 같은 다양한 C/C++ 프로젝트를:

```text
CMake
CMake Presets
Multiple Targets
CTest
Debug / Release
ASan / UBSan
Coverage
Monorepo
```

하나의 Vim 인터페이스로:

```text
Configure
Build
Run
Test
Debug
Analyze
```

할 수 있는 **Universal CMake Workflow**를 제공하는 것입니다.
