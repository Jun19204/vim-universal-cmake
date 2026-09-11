# vim-universal-cmake

> A unified CMake workflow for modern C and C++ development in Vim.

**CMake remains the Source of Truth. Vim becomes the interface.**

`vim-universal-cmake` provides a consistent workflow for configuring, building, running, testing, debugging, and analyzing CMake projects without hardcoding compiler commands or executable paths in `.vimrc`.

```text
F5   Configure + Build
F6   Configure + Build + Run
F7   Configure + Build + CTest
F8   Configure + Build + GDB
```

## Demo

![vim-universal-cmake demo](assets/demo.gif)

### Multiple Executable Targets

![Multiple executable targets](assets/multi-target.gif)

### CMake Presets

![CMake Presets and AddressSanitizer](assets/preset-asan.gif)

---

## Why?

A CMake project already describes:

- Compilers
- C and C++ standards
- Include paths
- Compile and link options
- Build configurations
- Targets and artifacts
- Tests
- Sanitizers and coverage options

A Vim configuration should not duplicate this information with project-specific commands such as:

```vim
nnoremap <F5> :!g++ main.cpp -std=c++23 -Iinclude -o app<CR>
nnoremap <F6> :!./app<CR>
```

That approach breaks when projects use different compilers, flags, directories, presets, tests, or multiple executable targets.

`vim-universal-cmake` delegates project knowledge to CMake and provides one Vim interface for driving it.

> **CMake describes the project. Vim drives the workflow.**

---

## Features

- Automatic project-root detection
- `CMakePresets.json` and `CMakeUserPresets.json`
- Preset `include` and `inherits`
- Correct multiple-inheritance priority
- Hidden Configure and Build Preset filtering
- Fallback configuration for projects without active Presets
- Out-of-source fallback build directories
- CMake File API target discovery
- Multiple executable target selection
- CTest integration
- GDB terminal integration
- Current-line breakpoint insertion
- Valgrind integration
- Safe `compile_commands.json` linking
- clangd and CoC integration
- Project-specific session state
- Multi-buffer save before build operations

Sanitizers and coverage are configured by the CMake project or its Presets rather than being hardcoded into Vim.

---

## Quick Start

### Simple CMake project

Open any source file inside the project:

```bash
vim src/main.cpp
```

Then:

```text
F5   Configure and build
F6   Build and run
```

When no Configure Preset is selected, the fallback workflow is used.

### Project using CMake Presets

```text
Space bp   Select Configure Preset
Space bb   Select Build Preset
F5         Configure and build
```

If exactly one Build Preset is associated with the selected Configure Preset, it is selected automatically.

### Project with multiple executables

```text
Space bt   Select executable target
F6         Build and run selected target
```

A project with only one executable target does not require manual target selection.

---

## Installation

Clone the repository:

```bash
git clone https://github.com/Jun19204/vim-universal-cmake ~/vim-universal-cmake
cd ~/vim-universal-cmake
```

### Fedora / RHEL

```bash
bash ./install_for_fedora.sh
```

### Arch Linux

```bash
bash ./install_for_arch.sh
```

### Debian / Ubuntu

```bash
bash ./install_for_debian.sh
```

The main configuration files are:

```text
.vimrc
.vim/
├── coc-settings.json
├── autoload/
│   └── universal_cmake.vim
└── plugin/
    └── universal_cmake.vim
```

Commonly required tools include:

```text
Vim
CMake
GCC or Clang
Ninja
GDB
Valgrind
Node.js
ripgrep
clangd
```

GDB and Valgrind are only required when their respective features are used.

---

## Project-Root Detection

The project root is detected by walking upward from the directory containing the current file.

Detection priority:

1. Nearest `CMakeUserPresets.json` or `CMakePresets.json`
2. Nearest `CMakeLists.txt`
3. Nearest `.git` directory
4. Current Vim working directory

The active root can be inspected with:

```vim
:CMakeStatus
```

or:

```text
Space cs
```

---

## CMake Presets

Supported files:

```text
CMakePresets.json
CMakeUserPresets.json
```

The workflow supports included Preset files and inherited Presets.

```json
{
  "name": "asan",
  "inherits": "base",
  "binaryDir": "${sourceDir}/build/${presetName}"
}
```

When multiple parents are listed in `inherits`, the earlier parent has precedence, matching CMake Preset semantics.

Hidden Configure and Build Presets are excluded from selection menus.

### Select Configure Preset

```text
Space bp
```

or:

```vim
:CMakeSelectConfigurePreset
```

Selecting a Configure Preset:

- Records the active Configure Preset
- Resolves its `binaryDir`
- Clears the previous executable target
- Finds associated Build Presets
- Automatically selects the Build Preset when only one exists

### Select Build Preset

```text
Space bb
```

or:

```vim
:CMakeSelectBuildPreset
```

Only Build Presets associated with the active Configure Preset are shown.

### Explicit activation

The existence of a Preset file does not automatically enable Preset mode.

```text
Preset file exists
        ≠
Preset is active
```

A Configure Preset is used only after it has been explicitly selected in the current Vim session.

If no Configure Preset is selected, the fallback workflow is used.

### Preset condition scope

CMake ultimately validates Preset `condition` fields.

The internal selection interface filters hidden Presets but does not fully reimplement CMake’s condition-expression evaluator. A conditionally disabled Preset may therefore be rejected when CMake executes it.

---

## Fallback Configuration

When no Configure Preset is active, the workflow asks for one of the following configurations:

```text
Debug
Release
RelWithDebInfo
MinSizeRel
```

The generated command is conceptually equivalent to:

```bash
cmake -S <project-root> \
      -B <fallback-build-dir> \
      -DCMAKE_BUILD_TYPE=<configuration> \
      -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
```

If Ninja is available, it is selected as the generator.

Fallback builds are stored outside the source tree:

```text
~/.cache/vim-cmake/
└── <project-hash>/
    ├── debug/
    ├── release/
    ├── relwithdebinfo/
    └── minsizerel/
```

This prevents build artifacts from polluting the project and keeps different projects isolated.

---

## Build

```text
F5
```

or:

```vim
:CMakeBuild
```

Workflow:

```text
Save all modified buffers
        ↓
Detect project root
        ↓
Configure with selected Preset or fallback
        ↓
Build with selected Build Preset or build directory
        ↓
Update compile_commands.json integration
```

F5 uses `:wall`, so every modified writable buffer is saved before building.

---

## CMake File API and Target Discovery

Executable paths are not guessed.

Before Configure, the workflow creates a CMake File API `codemodel-v2` query. After Configure, it reads the generated reply and discovers:

- Target names
- Target types
- Artifact paths

Typical target types include:

```text
EXECUTABLE
STATIC_LIBRARY
SHARED_LIBRARY
MODULE_LIBRARY
OBJECT_LIBRARY
UTILITY
```

Only `EXECUTABLE` targets with artifacts are considered runnable.

The selected executable is used by:

- Run
- GDB
- Valgrind

### Select executable target

```text
Space bt
```

or:

```vim
:CMakeSelectTarget
```

### Show all CMake targets

```text
Space ba
```

or:

```vim
:CMakeTargets
```

### Multi-configuration generators

The primary workflow targets Linux and WSL with single-configuration generators such as Ninja.

CMake File API codemodels from multi-configuration generators can contain separate Debug, Release, and other configurations. Full configuration-specific artifact selection is outside the current primary scope.

---

## Run

```text
F6
```

or:

```text
Space br
```

or:

```vim
:CMakeRun
```

Workflow:

```text
Save all modified buffers
        ↓
Configure and build
        ↓
Discover executable targets
        ↓
Select target if necessary
        ↓
Run resolved artifact
```

---

## CTest

### Run all tests

```text
F7
```

or:

```text
Space tb
```

or:

```vim
:CMakeTest
```

CTest is executed in the active build directory:

```bash
ctest --test-dir <build-dir> --output-on-failure
```

### Run tests related to the current file

```text
Space tc
```

or:

```vim
:CMakeTestCurrent
```

The filter is derived from the current file name.

```text
query_test.cpp
      ↓
query_test
      ↓
query
      ↓
ctest -R query
```

If the file name does not end with `_test`, its stem is used directly.

This feature follows a naming convention; it does not analyze source code or CMake test definitions.

---

## GDB

### Start GDB

```text
F8
```

or:

```text
Space bd
```

or:

```vim
:CMakeGDB
```

The workflow:

1. Saves all modified buffers
2. Configures and builds
3. Resolves the active executable
4. Opens GDB in a bottom terminal split
5. Sets a breakpoint at `main`
6. Starts the program

Conceptually:

```bash
gdb -q <resolved-executable>
```

```gdb
break main
run
```

Only one managed GDB session may run at a time. Starting another session while the current one is alive is rejected.

### GDB commands

Commands are entered directly in the GDB terminal.

| Command | Action |
| --- | --- |
| `n` | Execute the next line without entering a function |
| `s` | Step into a function |
| `c` | Continue until the next breakpoint |
| `finish` | Continue until the current function returns |
| `bt` | Show the call stack |
| `p expression` | Evaluate and print an expression |
| `info locals` | Show local variables |
| `q` | Quit GDB |

### Breakpoint at the current source line

```text
Space bk
```

or:

```vim
:CMakeBreakpoint
```

Recommended workflow:

```text
F8
    ↓
GDB stops at main
    ↓
Move to a source line
    ↓
Space bk
    ↓
Return to GDB
    ↓
c
```

`Space bk` sends a breakpoint command to the existing managed GDB session. It does not start GDB.

---

## Valgrind

```text
Space bv
```

or:

```vim
:CMakeValgrind
```

Valgrind runs against the active executable artifact with:

```text
--leak-check=full
--show-leak-kinds=all
--track-origins=yes
```

The executable is resolved through CMake File API data rather than a hardcoded path.

For useful source locations, use a Debug or RelWithDebInfo configuration.

---

## clangd and compile_commands.json

The C/C++ language-server workflow is:

```text
coc.nvim
    ↓
coc-clangd
    ↓
clangd
    ↓
compile_commands.json
```

The compilation database is discovered in this order:

1. Build directory recorded in the current session
2. Project-root `compile_commands.json`
3. Existing fallback build directory
4. Selected Configure Preset’s `binaryDir`

Opening a C or C++ file does not automatically run Configure. Automatic `BufEnter` handling only discovers an existing compilation database and updates its link.

Configure remains an explicit operation performed through F5, F6, F7, F8, or `:CMakeConfigure`.

### Link the active compilation database

```text
Space cl
```

or:

```vim
:CMakeLinkCompileCommands
```

The project-root link is handled conservatively:

- A new symbolic link is created only when the destination does not exist
- An existing regular file is never overwritten
- An existing symbolic link to another target is never replaced
- A correct existing symbolic link is kept

The workflow does not automatically install CoC extensions or modify `coc-settings.json`.

---

## Project State

Each detected project keeps independent session state:

```text
Configure Preset
Build Preset
Build Directory
Executable Target
Fallback Configuration
clangd Compilation Database
```

### Show state

```text
Space cs
```

or:

```vim
:CMakeStatus
```

Displayed fields:

```text
root=
configure=
build=
dir=
clangd=
target=
```

### Reset state

```text
Space cr
```

or:

```vim
:CMakeReset
```

Reset removes only the current Vim session’s stored state for the project.

It does not delete:

- Source files
- Build directories
- CMake caches
- Preset files
- `compile_commands.json`

---

## Keybindings

`Space` represents the configured `<leader>` key.

### Build, Run, Test, and Debug

| Key | Action |
| --- | --- |
| `F5` | Save all modified buffers, configure, and build |
| `F6` | Save all modified buffers, build, and run |
| `F7` | Save all modified buffers, build, and run CTest |
| `F8` | Save all modified buffers, build, and start GDB |

### CMake

| Key | Action |
| --- | --- |
| `Space bc` | Configure |
| `Space bp` | Select Configure Preset |
| `Space bb` | Select Build Preset |
| `Space bt` | Select executable target |
| `Space br` | Build and run |
| `Space ba` | Show all CMake targets |
| `Space cs` | Show project state |
| `Space cr` | Reset project state |
| `Space cl` | Link `compile_commands.json` |

### Test, Debug, and Analysis

| Key | Action |
| --- | --- |
| `Space tb` | Run all CTest tests |
| `Space tc` | Run tests related to the current file |
| `Space bd` | Start GDB |
| `Space bk` | Add a breakpoint at the current line |
| `Space bv` | Run Valgrind |

### CoC and clangd

| Key | Action |
| --- | --- |
| `F1` | Toggle inlay hints |
| `K` | Show hover documentation |
| `gd` | Go to definition |
| `gy` | Go to type definition |
| `gi` | Go to implementation |
| `gr` | Find references |
| `Space rn` | Rename symbol |
| `Space cf` | Format the current buffer |

If an LSP formatter is unavailable, `Space cf` falls back to Vim’s `gg=G` indentation.

Formatting does not automatically save the buffer.

### Files and Search

| Key | Action |
| --- | --- |
| `F4` | Switch between source and header |
| `Ctrl+n` | Toggle NERDTree |
| `Ctrl+p` | Search files with FZF |
| `Space rg` | Search project text with ripgrep |

### Buffers

Open buffers are displayed in the airline tabline.

| Key | Action |
| --- | --- |
| `[b` | Move to the previous buffer |
| `]b` | Move to the next buffer |
| `Space bx` | Delete the current buffer |

### Editing

| Key | Action |
| --- | --- |
| `jk` | Leave Insert mode |
| `kj` | Leave Insert mode |
| `Esc Esc` | Clear search highlighting |

---

## Main Commands

```vim
:CMakeConfigure
:CMakeBuild
:CMakeRun
:CMakeTest
:CMakeTestCurrent
:CMakeGDB
:CMakeBreakpoint
:CMakeValgrind
:CMakeSelectConfigurePreset
:CMakeSelectBuildPreset
:CMakeSelectTarget
:CMakeTargets
:CMakeStatus
:CMakeReset
:CMakeLinkCompileCommands
```

---

## Typical Workflows

### Simple project

```text
Open source file
    ↓
F5
    ↓
F6
```

### Preset project

```text
Space bp
    ↓
Select Configure Preset
    ↓
Space bb, if necessary
    ↓
F5
```

### Multiple executables

```text
F5
    ↓
Space bt
    ↓
F6
```

### Test-driven workflow

```text
Edit implementation and tests
    ↓
Space tc
    ↓
F7
```

### Debugging

```text
F8
    ↓
Use n, s, and c in GDB
    ↓
Space bk for a source-line breakpoint
```

### Memory analysis

```text
Select a Debug or RelWithDebInfo configuration
    ↓
Space bt
    ↓
Space bv
```

---

## Design Principles

1. **CMake is the Source of Truth for project configuration.**
2. **Vim does not duplicate compiler or linker options.**
3. **Preset mode is activated explicitly.**
4. **Projects without active Presets use the fallback workflow.**
5. **Executable paths come from CMake File API artifacts.**
6. **Run, GDB, and Valgrind operate on actual executable targets.**
7. **clangd uses the active compilation database.**
8. **Existing compilation database files and links are not overwritten.**
9. **Opening a source file does not implicitly configure the project.**
10. **All modified buffers are saved before build-driven operations.**
11. **ASan, UBSan, and Coverage remain CMake build configurations.**
12. **Only one managed GDB session runs at a time.**

---

## Current Scope

The primary target environment is:

```text
Linux or WSL
Vim
CMake
Ninja
GCC or Clang
clangd
```

The current implementation intentionally does not attempt to fully reproduce:

- CMake Preset condition-expression evaluation
- Complete multi-configuration generator artifact selection
- Arbitrary runtime-argument management
- Remote or attach-based GDB workflows
- IDE-style graphical debugging

These features can still be used through CMake, GDB, or the terminal when needed.

---

## Philosophy

```text
CMake
    │
    │  Source of Truth
    ▼
Project Configuration
    │
    ├── Compiler
    ├── Language Standard
    ├── Include Paths
    ├── Compile Options
    ├── Link Options
    ├── Targets
    ├── Tests
    └── Build Configurations
    │
    ▼
vim-universal-cmake
    │
    ├── Configure
    ├── Build
    ├── Run
    ├── Test
    ├── Debug
    └── Analyze
```

`vim-universal-cmake` does not replace CMake.

It makes working with existing CMake projects from Vim consistent.

> **CMake describes the project.**
>
> **Vim drives the workflow.**
