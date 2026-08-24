# C/C++ Vim Development Environment

A Vim-based C/C++ development environment with:

- C++20 / C++23
- CMake
- CMake Presets
- CTest
- clangd + CoC
- CMake File API
- GDB
- Valgrind
- FZF
- NERDTree
- Header / Source switching
- Automatic `compile_commands.json` integration

The goal of this configuration is to provide a lightweight C/C++ development workflow centered around Vim and CMake.

---

# Features

## CMake-based workflow

This configuration provides a unified workflow for:

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

The main workflow is built around CMake rather than individual compiler commands.

This allows the same Vim environment to work with:

- Simple CMake projects
- Multi-target projects
- CMake Presets
- Debug builds
- Release builds
- AddressSanitizer builds
- CTest projects

---

# Installation

Clone the repository anywhere:

```bash
git clone https://github.com/Jun19204/dotfiles.git
cd ~/dotfiles
```

Run the installer:

```bash
chmod +x install_for_fedora.sh
./install_for_fedora.sh
```

The installer automatically detects the repository location and configures:

- `.vimrc`
- `coc-settings.json`
- `universal_cmake.vim`
- vim-plug
- Vim plugins
- coc-clangd
- C/C++ development tools

---

# Project Root Detection

The project root is automatically detected.

The search order is:

```text
CMakeUserPresets.json
        ↓
CMakePresets.json
        ↓
CMakeLists.txt
        ↓
.git
        ↓
Current working directory
```

This allows the configuration to work without manually setting the project directory.

---

# CMake Presets

Both of the following files are supported:

```text
CMakePresets.json
CMakeUserPresets.json
```

Preset files using `include` are also supported.

Preset inheritance using:

```json
{
  "inherits": "base"
}
```

is resolved automatically.

Example configurations:

```text
debug
release
asan
ubsan
coverage
```

Select a Configure Preset:

```text
Space bp
```

Select a Build Preset:

```text
Space bb
```

---

# Fallback CMake Configuration

A project does not need to use CMake Presets.

If no Configure Preset is selected, the configuration automatically uses a fallback CMake command.

```bash
cmake -S <source-dir> \
      -B <build-dir> \
      -DCMAKE_BUILD_TYPE=<config> \
      -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
```

If Ninja is installed, it will automatically be used as the generator.

The fallback build directory is created outside the project.

```text
~/.cache/vim-cmake/
```

Example:

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

The environment uses:

```text
coc.nvim
coc-clangd
clangd
```

CMake-generated `compile_commands.json` is automatically connected to clangd.

For example:

```text
project/
├── build/
│   └── asan/
│       └── compile_commands.json
│
├── src/
└── CMakeLists.txt
```

clangd will use the currently selected build directory.

The Universal CMake integration configures clangd with:

```text
--compile-commands-dir=<current-build-directory>
--background-index
--clang-tidy
```

Additional clangd settings can be configured in:

```text
~/.vim/coc-settings.json
```

Example:

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

Executable targets are discovered using the CMake File API.

Before configuring, Vim creates a query for:

```text
codemodel-v2
```

CMake then generates target information that can be used to detect:

```text
EXECUTABLE
STATIC_LIBRARY
SHARED_LIBRARY
UTILITY
```

Only executable targets with build artifacts are used for running and debugging.

Example:

```text
my_app                                   EXECUTABLE
  -> /home/user/project/build/my_app

unit_tests                               EXECUTABLE
  -> /home/user/project/build/unit_tests

my_library                               STATIC_LIBRARY
  -> /home/user/project/build/libmy_library.a
```

Select an executable target:

```text
Space bt
```

Show all targets:

```text
Space ba
```

---

# AddressSanitizer

AddressSanitizer is supported through CMake or CMake Presets.

This Vim configuration does not manually add sanitizer flags.

Instead, the selected CMake build configuration determines how the project is compiled.

Example:

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

Workflow:

```text
Space bp
    ↓
Select asan

Space bb
    ↓
Select asan build preset

F5
    ↓
Build

F6
    ↓
Run
```

The selected build directory is also automatically connected to clangd.

---

# GDB

GDB runs inside a Vim terminal buffer.

Start GDB:

```text
F8
```

The default commands are:

```gdb
break main
run
```

Debug controls:

| Key | Action |
|---|---|
| `F10` | next |
| `F11` | step |
| `F12` | continue |

You can also set a breakpoint at the current cursor location.

```text
Space bk
```

---

# Valgrind

Valgrind can be executed against the selected executable target.

```text
Space bv
```

The following options are used:

```text
--leak-check=full
--show-leak-kinds=all
--track-origins=yes
```

---

# Header / Source Switching

`vim-fswitch` is configured to switch between common C/C++ source and header files.

Examples:

```text
main.cpp
    ↔
main.hpp
```

```text
example.cc
    ↔
example.h
```

The search paths include:

```text
src/
include/
../src/
../include/
tests/
```

Key:

```text
F4
```

---

# Configuration Files

The expected repository structure is:

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
│
└── README.md
```

The installation script creates symbolic links for:

```text
~/.vimrc
~/.vim/coc-settings.json
~/.vim/autoload/universal_cmake.vim
~/.vim/plugin/universal_cmake.vim
```

---

# Keybindings

The Leader key is set to:

```text
Space
```

---

## Files and Search

| Key | Action |
|---|---|
| `Ctrl+n` | Toggle NERDTree |
| `Ctrl+p` | FZF file search |
| `Space rg` | ripgrep search |
| `F4` | Switch header/source |

---

## clangd / CoC

| Key | Action |
|---|---|
| `gd` | Go to definition |
| `gy` | Go to type definition |
| `gi` | Go to implementation |
| `gr` | Find references |
| `K` | Show hover information |
| `Space rn` | Rename symbol |
| `Space cf` | Format code |
| `F1` | Toggle inlay hints |

If an LSP formatter is not available:

```text
gg=G
```

is used as a fallback.

---

## Build / Run / Test / Debug

| Key | Action |
|---|---|
| `F5` | Save and build |
| `F6` | Save, build, and run |
| `F7` | Save, build, and run CTest |
| `F8` | Save, build, and start GDB |

---

## CMake Configuration

| Key | Action |
|---|---|
| `Space bc` | Configure project |
| `Space bp` | Select Configure Preset |
| `Space bb` | Select Build Preset |

---

## Targets

| Key | Action |
|---|---|
| `Space bt` | Select executable target |
| `Space br` | Build and run |
| `Space ba` | Show CMake targets |

---

## Testing

| Key | Action |
|---|---|
| `Space tb` | Run CTest |
| `Space tc` | Run current test |
| `Space bv` | Run Valgrind |

---

## Debugging

| Key | Action |
|---|---|
| `Space bd` | Start GDB |
| `Space bk` | Set breakpoint at current line |
| `F10` | GDB next |
| `F11` | GDB step |
| `F12` | GDB continue |

---

## Project / clangd

| Key | Action |
|---|---|
| `Space cs` | Show CMake status |
| `Space cr` | Reset current project state |
| `Space cl` | Create compile_commands.json symlink |

---

# Vim Commands

## Project

```vim
:CMakeRoot
:CMakeStatus
:CMakeReset
```

---

## Configure and Build

```vim
:CMakeConfigure
:CMakeBuild
:CMakeRun
```

---

## Presets

```vim
:CMakeSelectConfigurePreset
:CMakeSelectBuildPreset
```

---

## Targets

```vim
:CMakeSelectTarget
:CMakeTargets
```

---

## Testing

```vim
:CMakeTest
```

Run a specific test:

```vim
:CMakeTest <test-name>
```

Run a test based on the current file:

```vim
:CMakeTestCurrent
```

---

## Debugging

```vim
:CMakeGDB
```

Send a command to the active GDB session:

```vim
:CMakeGDBSend next
```

Set a breakpoint at the current cursor position:

```vim
:CMakeBreakpoint
```

---

## clangd

Update the clangd configuration:

```vim
:CMakeUpdateClangd
```

Create a symbolic link to the current build's `compile_commands.json`:

```vim
:CMakeLinkCompileCommands
```

---

# Typical Workflow

## Simple CMake Project

Open a source file:

```bash
vim src/main.cpp
```

Build:

```text
F5
```

If no CMake Preset is selected, the fallback configuration is used.

Run:

```text
F6
```

---

## Project with CMake Presets

Select a Configure Preset:

```text
Space bp
```

Select a Build Preset:

```text
Space bb
```

Build:

```text
F5
```

Run:

```text
F6
```

---

## Multiple Executables

If a project contains multiple executable targets:

```text
app
server
client
unit_tests
```

Select one:

```text
Space bt
```

Then:

```text
F6
```

will build and run the selected target.

---

## Debugging Workflow

Start GDB:

```text
F8
```

Execution controls:

```text
F10    next
F11    step
F12    continue
```

Set a breakpoint:

```text
Space bk
```

---

# compile_commands.json

The active build directory is used directly by clangd.

For tools that expect `compile_commands.json` in the project root, create a symbolic link:

```text
Space cl
```

Example:

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

# Example Project

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

A typical workflow:

```text
Open main.cpp
        ↓
Space bp
        ↓
Select debug
        ↓
F5
        ↓
Build
        ↓
F6
        ↓
Run
```

For debugging:

```text
F8
```

For memory analysis:

```text
Space bv
```

---

# Design Overview

```text
                    ┌─────────────┐
                    │    Vim      │
                    └──────┬──────┘
                           │
                           ▼
                ┌────────────────────┐
                │ Universal CMake    │
                └─────────┬──────────┘
                          │
          ┌───────────────┼────────────────┐
          │               │                │
          ▼               ▼                ▼
      Configure          Build          File API
          │               │                │
          ▼               ▼                ▼
 compile_commands      Executables       Targets
          │               │
          ▼               ▼
        clangd         Run / Test
          │               │
          ▼               ▼
       CoC / LSP        GDB / Valgrind
```

The configuration is designed around the idea that CMake should be the source of truth for:

- Build configuration
- Compiler flags
- Sanitizers
- Include paths
- Executable targets
- `compile_commands.json`

Vim acts as the interface for controlling that workflow.

---

# License

This repository contains a personal Vim configuration for C/C++ development.

You are free to study, modify, and adapt it for your own development environment.
