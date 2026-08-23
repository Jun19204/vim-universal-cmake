# Vim for Modern C++ Project Template

C++20/23, CMake, CMake Presets, CTest, GoogleTest, ASan/UBSan, Valgrind 및 GDB를 사용하는 현대적인 C++ 프로젝트 템플릿에서 사용 가능한 Vim 커스텀 설정입니다.

이 프로젝트 템플릿은 핵심 구현을 라이브러리 Target으로 분리하고, 애플리케이션·예제·테스트를 독립적인 실행 Target으로 구성합니다. 또한 `CMakePresets.json`을 통해 ASan/UBSan 개발 환경과 Valgrind 검사 환경을 분리합니다.

## 주요 기능

- C++20/23 기반 프로젝트
- CMake 기반 빌드 시스템
- `CMakePresets.json` 기반 Build Profile 관리
- ASan + UBSan 지원
- Valgrind 전용 Debug 빌드
- CTest 기반 테스트 실행
- GoogleTest + `FetchContent` 기반 테스트 의존성 관리
- `gtest_discover_tests()` 기반 개별 테스트 자동 등록
- 공통 경고 옵션을 `INTERFACE` Target으로 관리
- Sanitizer 옵션을 `INTERFACE` Target으로 관리
- `compile_commands.json` 생성
- clangd 등 C/C++ Language Server 연동 지원
- 여러 실행 파일과 테스트 Target으로 쉽게 확장 가능한 구조

---

## 프로젝트 구조

```text
MyProject/
├── CMakeLists.txt
├── CMakePresets.json
├── .gitignore
│
├── cmake/
│   ├── CompilerWarnings.cmake
│   └── Sanitizers.cmake
│
├── include/
│   └── myproject/
│       ├── calculator.hpp
│       └── string_utils.hpp
│
├── src/
│   ├── CMakeLists.txt
│   ├── calculator.cpp
│   ├── string_utils.cpp
│   ├── main.cpp
│   │
│   └── examples/
│       ├── CMakeLists.txt
│       ├── vector_example.cpp
│       └── algorithm_example.cpp
│
├── tests/
│   ├── CMakeLists.txt
│   ├── calculator_test.cpp
│   └── string_utils_test.cpp
│
├── build-asan/
│
├── build-valgrind/
│
└── compile_commands.json
```

빌드 디렉터리와 `compile_commands.json`은 생성 파일이므로 Git에서 관리하지 않습니다.

---

## Target 구조

프로젝트는 다음과 같은 Target 구조를 사용합니다.

```text
project_warnings
        │
        ▼
project_sanitizers
        │
        ▼
    myproject
        │
        ├── myproject_app
        │
        ├── vector_example
        │
        ├── algorithm_example
        │
        ├── calculator_test
        │
        └── string_utils_test
```

### `project_warnings`

공통 컴파일 경고 옵션을 제공하는 `INTERFACE` 라이브러리입니다.

대표적으로 다음 경고 옵션을 사용합니다.

```text
-Wall
-Wextra
-Wpedantic

-Wshadow
-Wconversion
-Wsign-conversion

-Wcast-qual
-Wcast-align

-Wformat=2
-Wnull-dereference

-Wdouble-promotion
```

### `project_sanitizers`

ASan과 UBSan 옵션을 관리하는 `INTERFACE` 라이브러리입니다.

ASan Profile에서는 다음 옵션이 적용됩니다.

```text
-fsanitize=address,undefined
-fno-omit-frame-pointer
```

Valgrind Profile에서는 Sanitizer를 비활성화합니다.

### `myproject`

실제 프로젝트 구현을 포함하는 핵심 라이브러리입니다.

애플리케이션, 예제 프로그램 및 테스트 프로그램은 모두 이 라이브러리를 링크합니다.

이 구조를 사용하면 핵심 구현을 재사용하면서 여러 실행 프로그램과 테스트를 독립적으로 구성할 수 있습니다.

---

## 요구 사항

다음 도구가 필요합니다.

| 도구 | 용도 |
|---|---|
| CMake | 프로젝트 Configure 및 Build |
| C++20/23 Compiler | C++ 코드 컴파일 |
| GoogleTest | 단위 테스트 |
| Git | GoogleTest FetchContent 다운로드 |
| Valgrind | 메모리 오류 및 누수 검사 |
| GDB | 디버깅 |
| Ninja 또는 Make | CMake Build Backend |
| clangd | C/C++ Language Server |

Fedora Linux에서는 예를 들어 다음과 같이 설치할 수 있습니다.

```bash
sudo dnf install \
  gcc-c++ \
  clang \
  clang-tools-extra \
  cmake \
  ninja-build \
  gdb \
  valgrind \
  git \
  ripgrep \
  nodejs \
  python3
```

---

# Build Profiles

이 프로젝트는 두 개의 주요 Build Profile을 제공합니다.

| Profile | Build Directory | Sanitizer | 용도 |
|---|---|---|---|
| `asan` | `build-asan/` | ASan + UBSan | 일반 개발 및 런타임 오류 검사 |
| `valgrind` | `build-valgrind/` | OFF | Valgrind 기반 메모리 검사 |

ASan/UBSan이 적용된 실행 파일과 Valgrind 검사용 실행 파일은 분리하는 것을 기본 원칙으로 합니다.

```text
ASan Profile
    │
    └── build-asan/
        └── ASan + UBSan

Valgrind Profile
    │
    └── build-valgrind/
        └── Sanitizer OFF
```

---

# ASan / UBSan 빌드

프로젝트를 Configure합니다.

```bash
cmake --preset asan
```

빌드합니다.

```bash
cmake --build --preset asan
```

처음부터 순서대로 실행하려면 다음과 같습니다.

```bash
cmake --preset asan
cmake --build --preset asan
```

빌드 결과는 기본적으로 다음 디렉터리에 생성됩니다.

```text
build-asan/
```

ASan과 UBSan을 통해 다음과 같은 런타임 오류를 탐지할 수 있습니다.

- Heap buffer overflow
- Stack buffer overflow
- Use-after-free
- Double free
- Undefined behavior
- 기타 Sanitizer가 탐지 가능한 런타임 오류

---

# 테스트 실행

전체 테스트는 다음 명령으로 실행합니다.

```bash
ctest --preset asan
```

또는 테스트 디렉터리를 직접 지정할 수도 있습니다.

```bash
ctest \
  --test-dir build-asan \
  --output-on-failure
```

테스트 목록을 확인하려면 다음 명령을 사용할 수 있습니다.

```bash
ctest \
  --test-dir build-asan \
  -N
```

이 프로젝트는 `gtest_discover_tests()`를 사용합니다.

따라서 GoogleTest 실행 파일 전체가 하나의 CTest 항목으로 등록되는 것이 아니라, 개별 GoogleTest 테스트가 CTest에 자동 등록됩니다.

예를 들어 다음과 같은 테스트가 있다고 가정합니다.

```cpp
TEST(
  CalculatorTest,
  Add
)
```

CTest는 해당 테스트를 개별 테스트 항목으로 관리할 수 있습니다.

특정 이름 패턴의 테스트만 실행하려면 다음과 같이 사용할 수 있습니다.

```bash
ctest \
  --preset asan \
  -R Calculator
```

---

# Valgrind 빌드

Valgrind용 빌드 환경을 Configure합니다.

```bash
cmake --preset valgrind
```

빌드합니다.

```bash
cmake --build --preset valgrind
```

전체 과정은 다음과 같습니다.

```bash
cmake --preset valgrind
cmake --build --preset valgrind
```

Valgrind Profile에서는 Sanitizer를 비활성화합니다.

실행 파일은 다음과 같이 검사할 수 있습니다.

```bash
valgrind \
  --leak-check=full \
  --show-leak-kinds=all \
  --track-origins=yes \
  ./build-valgrind/src/myproject_app
```

프로젝트에 여러 실행 Target이 존재하는 경우 원하는 실행 파일을 직접 지정하면 됩니다.

예를 들어 예제 프로그램을 검사하려면 다음과 같이 실행할 수 있습니다.

```bash
valgrind \
  --leak-check=full \
  --show-leak-kinds=all \
  --track-origins=yes \
  ./build-valgrind/src/examples/vector_example
```

---

# 실행 파일

메인 애플리케이션은 다음 Target입니다.

```text
myproject_app
```

ASan Profile에서 빌드한 후 실행할 수 있습니다.

```bash
./build-asan/src/myproject_app
```

예제 프로그램도 각각 독립적인 실행 Target입니다.

```text
vector_example
algorithm_example
```

예를 들어 다음과 같이 실행할 수 있습니다.

```bash
./build-asan/src/examples/vector_example
```

```bash
./build-asan/src/examples/algorithm_example
```

---

# 새로운 실행 프로그램 추가

새로운 실행 프로그램을 추가하려면 소스 파일을 생성합니다.

예:

```text
src/examples/
└── ranges_example.cpp
```

그다음 `src/examples/CMakeLists.txt`에 Target을 추가합니다.

```cmake
add_executable(
  ranges_example

  ranges_example.cpp
)

target_link_libraries(
  ranges_example

  PRIVATE

    myproject
    project_warnings
    project_sanitizers
)
```

이후 다시 Configure 및 Build합니다.

```bash
cmake --preset asan
cmake --build --preset asan
```

새로운 실행 Target이 빌드 결과에 추가됩니다.

---

# 새로운 테스트 추가

새로운 테스트 파일을 추가합니다.

```text
tests/
├── calculator_test.cpp
├── string_utils_test.cpp
└── vector_test.cpp
```

`tests/CMakeLists.txt`에 새로운 테스트 실행 Target을 추가합니다.

```cmake
add_executable(
  vector_test

  vector_test.cpp
)

target_link_libraries(
  vector_test

  PRIVATE

    myproject
    project_warnings
    project_sanitizers
    GTest::gtest_main
)

gtest_discover_tests(
  vector_test
)
```

이후 프로젝트를 다시 Configure 및 Build하면 테스트가 CTest에 등록됩니다.

```bash
cmake --preset asan
cmake --build --preset asan
ctest --preset asan
```

---

# `compile_commands.json`

이 프로젝트는 CMake Configure 과정에서 `compile_commands.json`을 생성합니다.

`CMakePresets.json`에는 다음 설정이 포함되어 있습니다.

```json
"CMAKE_EXPORT_COMPILE_COMMANDS": "ON"
```

Configure 이후 각 Build Directory에 파일이 생성됩니다.

```text
build-asan/
└── compile_commands.json

build-valgrind/
└── compile_commands.json
```

clangd와 같은 C/C++ Language Server가 프로젝트의 실제 컴파일 옵션을 일관되게 사용할 수 있도록 프로젝트 루트에 심볼릭 링크를 생성할 수 있습니다.

```bash
ln -sfn \
  build-asan/compile_commands.json \
  compile_commands.json
```

최종 구조는 다음과 같습니다.

```text
MyProject/
├── compile_commands.json
│   ↓ symbolic link
└── build-asan/
    └── compile_commands.json
```

일반적인 개발 환경에서는 ASan Profile의 `compile_commands.json`을 사용하는 것을 기준으로 합니다.

---

# CMake Presets

프로젝트는 `CMakePresets.json`을 통해 빌드 환경을 관리합니다.

주요 Preset은 다음과 같습니다.

```text
asan
valgrind
```

현재 Preset 목록을 확인하려면 다음 명령을 사용할 수 있습니다.

```bash
cmake --list-presets
```

Build Preset 목록은 다음과 같이 확인할 수 있습니다.

```bash
cmake --build --list-presets
```

Test Preset 목록은 다음과 같이 확인할 수 있습니다.

```bash
ctest --list-presets
```

---

# 권장 개발 흐름

## 일반 개발

```text
코드 작성
↓
ASan / UBSan 빌드
↓
실행
↓
오류 확인
```

명령은 다음과 같습니다.

```bash
cmake --preset asan
cmake --build --preset asan
./build-asan/src/myproject_app
```

---

## 테스트 개발

```text
테스트 작성
↓
ASan / UBSan 빌드
↓
특정 테스트 또는 전체 테스트 실행
```

전체 테스트:

```bash
ctest --preset asan
```

특정 이름 패턴:

```bash
ctest \
  --preset asan \
  -R Calculator
```

---

## 메모리 검사

먼저 ASan/UBSan으로 실행합니다.

```text
ASan / UBSan
↓
런타임 오류 확인
```

추가적인 메모리 검사가 필요하면 별도의 Valgrind Profile을 사용합니다.

```text
Valgrind Build
↓
Valgrind 실행
↓
메모리 누수 및 잘못된 메모리 접근 확인
```

```bash
cmake --preset valgrind
cmake --build --preset valgrind

valgrind \
  --leak-check=full \
  --show-leak-kinds=all \
  --track-origins=yes \
  ./build-valgrind/src/myproject_app
```

---

# Vim 개발 환경 연동

이 프로젝트 구조는 별도의 Fedora 43 기반 C/C++ Vim 개발 환경과 함께 사용할 수 있도록 구성되어 있습니다.

Vim 환경에서는 다음과 같은 기능을 사용할 수 있습니다.

| 키 | 기능 |
|---|---|
| `F5` | ASan Preset Build |
| `F6` | ASan Build + 실행 |
| `F8` | Valgrind Preset Build |
| `F9` | Valgrind Build + 실행 |
| `<Space>t` | 전체 CTest 실행 |
| `<Space>f` | 현재 파일 이름 기반 CTest 실행 |
| `<Space>g` | 등록된 테스트 실행 Target 직접 실행 |
| `<Space>d` | GDB 시작 |
| `<Space>b` | 현재 위치에 GDB Breakpoint 설정 |
| `F10` | GDB `next` |
| `F11` | GDB `step` |
| `F12` | GDB `continue` |
| `F4` | Source / Header 전환 |
| `<Space>cf` | 코드 포맷 |
| `<Space>rg` | ripgrep + FZF 검색 |

Vim 설정은 CMake Preset의 `binaryDir`를 기준으로 실제 빌드 디렉터리를 확인하고, CMake File API를 이용해 실행 가능한 `EXECUTABLE` Target을 탐색하는 구조를 사용할 수 있습니다.

따라서 실행 파일 이름이나 빌드 디렉터리 구조를 직접 추측하는 방식에 의존하지 않고 CMake가 생성한 실제 메타데이터를 기준으로 실행 및 디버깅할 수 있습니다.

---

# 핵심 설계 원칙

1. 핵심 구현은 `myproject`와 같은 라이브러리 Target으로 구성합니다.
2. 애플리케이션, 예제 및 테스트는 독립적인 `EXECUTABLE` Target으로 구성합니다.
3. 공통 경고 옵션은 `project_warnings` `INTERFACE` Target으로 관리합니다.
4. Sanitizer 옵션은 `project_sanitizers` `INTERFACE` Target으로 관리합니다.
5. 빌드 환경은 `CMakePresets.json`으로 관리합니다.
6. ASan/UBSan과 Valgrind는 별도의 Build Directory를 사용합니다.
7. GoogleTest는 `FetchContent`를 통해 프로젝트 의존성으로 관리합니다.
8. `gtest_discover_tests()`를 통해 GoogleTest를 CTest에 등록합니다.
9. `compile_commands.json`은 실제 CMake Configure 결과를 사용합니다.
10. 새로운 실행 파일은 `add_executable()`로 추가합니다.
11. 새로운 테스트는 실행 Target과 `gtest_discover_tests()`를 추가하여 확장합니다.
12. 실행 Target과 테스트는 가능하면 파일 이름 추측이 아닌 CMake와 CTest의 실제 메타데이터를 기준으로 관리합니다.

---

# 전체 구조 요약

```text
CMake Project
│
├── Build Profiles
│   ├── asan
│   │   └── build-asan/
│   │       └── ASan + UBSan
│   │
│   └── valgrind
│       └── build-valgrind/
│           └── Sanitizer OFF
│
├── Common Targets
│   ├── project_warnings
│   └── project_sanitizers
│
├── Core Library
│   └── myproject
│
├── Executables
│   ├── myproject_app
│   ├── vector_example
│   └── algorithm_example
│
└── Tests
    ├── calculator_test
    └── string_utils_test
```

이 구조의 핵심은 **프로젝트 구현과 실행 프로그램, 테스트를 분리하고 CMake Target을 중심으로 프로젝트를 구성하는 것​**입니다.

빌드 환경은 CMake Presets로 관리하며, 일반적인 개발과 런타임 오류 탐지는 ASan/UBSan Profile에서 수행하고, Valgrind 검사가 필요한 경우 별도의 Sanitizer 비활성화 Profile을 사용합니다.

이를 통해 단일 실행 파일 프로젝트에서 시작하더라도 라이브러리, 여러 예제 프로그램, 단위 테스트 및 다양한 실행 Target을 자연스럽게 확장할 수 있습니다.
