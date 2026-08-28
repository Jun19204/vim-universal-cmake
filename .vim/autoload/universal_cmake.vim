if exists('g:loaded_universal_cmake_autoload')
  finish
endif
let g:loaded_universal_cmake_autoload = 1

let s:projects = {}
let s:gdb_job = -1
let s:clangd_dirs = {}

" ============================================================
" Project Root / State
" ============================================================
function! s:FindProjectRoot() abort
  let l:start = expand('%:p:h')
  if empty(l:start) || !isdirectory(l:start)
    let l:start = getcwd()
  endif
  let l:start = resolve(fnamemodify(l:start, ':p'))
  " 1. 가장 가까운 CMakePresets.json / CMakeUserPresets.json
  let l:dir = l:start
  while 1
    if filereadable(l:dir . '/CMakeUserPresets.json')
          \ || filereadable(l:dir . '/CMakePresets.json')
      return l:dir
    endif
    let l:parent = fnamemodify(l:dir, ':h')
    if l:parent ==# l:dir
      break
    endif
    let l:dir = l:parent
  endwhile
  " 2. 가장 가까운 CMakeLists.txt
  let l:cmake =
        \ findfile(
        \ 'CMakeLists.txt',
        \ l:start . ';')
  if !empty(l:cmake)
    return resolve(
          \ fnamemodify(
          \ l:cmake,
          \ ':p:h'))
  endif
  " 3. Git root
  let l:git =
        \ finddir(
        \ '.git',
        \ l:start . ';')
  if !empty(l:git)
    return resolve(
          \ fnamemodify(
          \ l:git,
          \ ':p:h'))
  endif
  " 4. 현재 작업 디렉터리
  return resolve(getcwd())
endfunction

function! universal_cmake#root() abort
  return s:FindProjectRoot()
endfunction

function! s:Project() abort
  let l:root = universal_cmake#root()

  if !has_key(s:projects, l:root)
    let s:projects[l:root] = {
          \ 'configure_preset': '',
          \ 'build_preset': '',
          \ 'build_dir': '',
          \ 'target': '',
          \ 'config': 'Debug'
          \ }
  endif

  return s:projects[l:root]
endfunction

" ============================================================
" Common Utility
" ============================================================
function! s:CacheRoot() abort
  return expand('~/.cache/vim-cmake')
endfunction

function! s:ProjectHash() abort
  return sha256(universal_cmake#root())[:15]
endfunction

function! s:FallbackBuildDir(config) abort
  return s:CacheRoot()
        \ . '/'
        \ . s:ProjectHash()
        \ . '/'
        \ . tolower(a:config)
endfunction

function! s:Shell(cmd) abort
  return 'cd '
        \ . shellescape(universal_cmake#root())
        \ . ' && '
        \ . a:cmd
endfunction

function! s:Run(cmd) abort
  execute '!' . s:Shell(a:cmd)
  return v:shell_error == 0
endfunction

function! s:ReadJSON(file) abort
  if !filereadable(a:file)
    return {}
  endif
  try
    return json_decode(join(readfile(a:file), "\n"))
  catch
    echoerr 'JSON 파싱 실패: ' . a:file
    return {}
  endtry
endfunction

function! s:Choose(items, title, current) abort
  if empty(a:items)
    return ''
  endif
  if len(a:items) == 1
    return a:items[0]
  endif
  let l:menu = [a:title]
  for l:i in range(len(a:items))
    let l:mark =
          \ a:items[l:i] ==# a:current
          \ ? '* '
          \ : ''
    call add(
          \ l:menu,
          \ printf(
          \ '%d. %s%s',
          \ l:i + 1,
          \ l:mark,
          \ a:items[l:i]))
  endfor
  let l:n = inputlist(l:menu)
  return l:n >= 1 && l:n <= len(a:items)
        \ ? a:items[l:n - 1]
        \ : ''
endfunction

" ============================================================
" CMake Presets
" ============================================================
function! s:PresetFiles() abort
  let l:root = universal_cmake#root()
  let l:files = []
  for l:name in [
        \ 'CMakePresets.json',
        \ 'CMakeUserPresets.json'
        \ ]
    let l:file = l:root . '/' . l:name
    if filereadable(l:file)
      call add(
            \ l:files,
            \ resolve(fnamemodify(l:file, ':p')))
    endif
  endfor
  return l:files
endfunction

function! s:CollectPresetFile(file, seen) abort
  let l:file = resolve(fnamemodify(a:file, ':p'))
  if has_key(a:seen, l:file)
        \ || !filereadable(l:file)
    return []
  endif
  let a:seen[l:file] = 1
  let l:data = s:ReadJSON(l:file)
  if empty(l:data)
    return []
  endif
  let l:result = []
  let l:base = fnamemodify(l:file, ':h')
  for l:include in get(l:data, 'include', [])
    if l:include =~# '^/'
      let l:path = l:include
    else
      let l:path = l:base . '/' . l:include
    endif
    call extend(
          \ l:result,
          \ s:CollectPresetFile(
          \ l:path,
          \ a:seen))
  endfor
  call add(l:result, {
        \ 'file': l:file,
        \ 'dir': l:base,
        \ 'data': l:data
        \ })
  return l:result
endfunction

function! s:AllPresetData() abort
  let l:seen = {}
  let l:result = []
  for l:file in s:PresetFiles()
    call extend(
          \ l:result,
          \ s:CollectPresetFile(
          \ l:file,
          \ l:seen))
  endfor
  return l:result
endfunction

function! s:PresetMap(kind) abort
  let l:key =
        \ a:kind ==# 'configure'
        \ ? 'configurePresets'
        \ : 'buildPresets'
  let l:result = {}
  for l:item in s:AllPresetData()
    for l:preset in get(l:item.data, l:key, [])
      let l:name = get(l:preset, 'name', '')
      if empty(l:name)
        continue
      endif
      let l:copy = copy(l:preset)
      let l:copy.__file = l:item.file
      let l:copy.__dir = l:item.dir
      let l:result[l:name] = l:copy
    endfor
  endfor
  return l:result
endfunction

function! s:MergePreset(parent, child) abort
  let l:result = copy(a:parent)
  for [l:key, l:value] in items(a:child)
    if l:key !~# '^__'
      let l:result[l:key] = l:value
    endif
  endfor
  let l:result.__file =
        \ get(
        \ a:child,
        \ '__file',
        \ get(a:parent, '__file', ''))
  let l:result.__dir =
        \ get(
        \ a:child,
        \ '__dir',
        \ get(a:parent, '__dir', ''))
  return l:result
endfunction

function! s:ResolvePreset(map, name, stack) abort
  if !has_key(a:map, a:name)
    return {}
  endif
  if index(a:stack, a:name) >= 0
    echoerr 'CMake preset inherits 순환 감지: ' . a:name
    return {}
  endif
  let l:preset = copy(a:map[a:name])
  let l:parents = get(l:preset, 'inherits', [])
  if type(l:parents) == v:t_string
    let l:parents = [l:parents]
  endif
  let l:result = {}
  for l:parent_name in l:parents
    let l:parent =
          \ s:ResolvePreset(
          \ a:map,
          \ l:parent_name,
          \ a:stack + [a:name])
    if !empty(l:parent)
      let l:result =
            \ s:MergePreset(
            \ l:result,
            \ l:parent)
    endif
  endfor
  return s:MergePreset(l:result, l:preset)
endfunction

function! s:ConfigurePresetMap() abort
  let l:raw = s:PresetMap('configure')
  let l:result = {}
  for l:name in keys(l:raw)
    let l:resolved =
          \ s:ResolvePreset(
          \ l:raw,
          \ l:name,
          \ [])
    if !empty(l:resolved)
      let l:result[l:name] = l:resolved
    endif
  endfor
  return l:result
endfunction

function! s:BuildPresetMap() abort
  let l:raw = s:PresetMap('build')
  let l:result = {}
  for l:name in keys(l:raw)
    let l:resolved =
          \ s:ResolvePreset(
          \ l:raw,
          \ l:name,
          \ [])
    if !empty(l:resolved)
      let l:result[l:name] = l:resolved
    endif
  endfor
  return l:result
endfunction

function! s:VisibleConfigurePresets() abort
  let l:raw = s:PresetMap('configure')
  let l:result = []
  for [l:name, l:preset] in items(l:raw)
    if !get(l:preset, 'hidden', v:false)
      call add(l:result, l:name)
    endif
  endfor
  return sort(l:result)
endfunction

function! s:BuildPresetsFor(configure_name) abort
  let l:result = []
  for [l:name, l:preset]
        \ in items(s:BuildPresetMap())
    if get(
          \ l:preset,
          \ 'configurePreset',
          \ '') ==# a:configure_name
      call add(l:result, l:name)
    endif
  endfor
  return sort(l:result)
endfunction

function! universal_cmake#select_configure_preset() abort
  let l:p = s:Project()
  let l:presets = s:VisibleConfigurePresets()
  if empty(l:presets)
    echo '사용 가능한 configure preset이 없습니다.'
    return
  endif
  let l:selected =
        \ s:Choose(
        \ l:presets,
        \ 'Configure Preset 선택:',
        \ l:p.configure_preset)
  if empty(l:selected)
    return
  endif
  let l:p.configure_preset = l:selected
  let l:p.build_dir =
        \ s:PresetBinaryDir(
        \ l:p.configure_preset)
  let l:p.target = ''
  let l:build_presets =
        \ s:BuildPresetsFor(l:selected)
  if len(l:build_presets) == 1
    let l:p.build_preset = l:build_presets[0]
  elseif len(l:build_presets) > 1
    let l:p.build_preset =
          \ s:Choose(
          \ l:build_presets,
          \ '연결된 Build Preset 선택:',
          \ l:p.build_preset)
  else
    let l:p.build_preset = ''
  endif
  echo 'Configure: '
        \ . l:p.configure_preset
        \ . (
        \ empty(l:p.build_preset)
        \ ? ''
        \ : ' | Build: ' . l:p.build_preset)
endfunction

function! universal_cmake#select_build_preset() abort
  let l:p = s:Project()
  if empty(l:p.configure_preset)
    echoerr '먼저 Configure Preset을 선택하십시오.'
    return
  endif
  let l:presets =
        \ s:BuildPresetsFor(
        \ l:p.configure_preset)
  if empty(l:presets)
    let l:p.build_preset = ''
    echo '연결된 Build Preset이 없습니다.'
    return
  endif
  let l:selected =
        \ s:Choose(
        \ l:presets,
        \ 'Build Preset 선택:',
        \ l:p.build_preset)
  if !empty(l:selected)
    let l:p.build_preset = l:selected
    echo 'Build: ' . l:p.build_preset
  endif
endfunction

function! s:ExpandPresetValue(value, preset) abort
  let l:root = universal_cmake#root()
  let l:source = l:root
  let l:generator = get(a:preset, 'generator', '')
  let l:name = get(a:preset, 'name', '')
  let l:value = a:value
  let l:value =
        \ substitute(
        \ l:value,
        \ '\${sourceDir}',
        \ escape(l:source, '\&'),
        \ 'g')
  let l:value =
        \ substitute(
        \ l:value,
        \ '\${sourceParentDir}',
        \ escape(
        \ fnamemodify(l:source, ':h'),
        \ '\&'),
        \ 'g')
  let l:value =
        \ substitute(
        \ l:value,
        \ '\${presetName}',
        \ escape(l:name, '\&'),
        \ 'g')
  let l:value =
        \ substitute(
        \ l:value,
        \ '\${generator}',
        \ escape(l:generator, '\&'),
        \ 'g')
  return l:value
endfunction

function! s:PresetBinaryDir(name) abort
  let l:presets = s:ConfigurePresetMap()
  if !has_key(l:presets, a:name)
    return ''
  endif
  let l:preset = l:presets[a:name]
  let l:binary = get(l:preset, 'binaryDir', '')
  if empty(l:binary)
    return ''
  endif
  let l:binary =
        \ s:ExpandPresetValue(
        \ l:binary,
        \ l:preset)
  if l:binary !~# '^/'
    let l:binary =
          \ universal_cmake#root()
          \ . '/'
          \ . l:binary
  endif
  return simplify(
        \ fnamemodify(
        \ l:binary,
        \ ':p'))
endfunction

function! s:SyncPresetState() abort
  let l:p = s:Project()
  if empty(l:p.configure_preset)
    return
  endif
  let l:presets = s:ConfigurePresetMap()
  if !has_key(l:presets, l:p.configure_preset)
    let l:p.configure_preset = ''
    let l:p.build_preset = ''
    let l:p.build_dir = ''
    let l:p.target = ''
    return
  endif
  let l:p.build_dir =
        \ s:PresetBinaryDir(
        \ l:p.configure_preset) 
  let l:build_presets =
        \ s:BuildPresetsFor(
        \ l:p.configure_preset)
  if empty(l:build_presets)
    let l:p.build_preset = ''
  elseif index(
        \ l:build_presets,
        \ l:p.build_preset) < 0
    if len(l:build_presets) == 1
      let l:p.build_preset = l:build_presets[0]
    else
      let l:p.build_preset = ''
    endif
  endif
endfunction

" ============================================================
" CMake File API
" ============================================================
function! s:PrepareFileAPI(build_dir) abort
  let l:query =
        \ a:build_dir
        \ . '/.cmake/api/v1/query/client-vim'
  call mkdir(l:query, 'p')
  call writefile([], l:query . '/codemodel-v2')
endfunction

" ============================================================
" CMake Configure
" ============================================================
function! s:ConfigurePreset() abort
  let l:p = s:Project()
  if empty(l:p.configure_preset)
    return 0
  endif
  let l:build_dir =
        \ s:PresetBinaryDir(
        \ l:p.configure_preset)
  if !empty(l:build_dir)
    call mkdir(l:build_dir, 'p')
    call s:PrepareFileAPI(l:build_dir)
  endif
  let l:cmd =
        \ 'cmake --preset '
        \ . shellescape(l:p.configure_preset)
  if !s:Run(l:cmd)
    echoerr 'CMake preset configure 실패'
    return 0
  endif
  if empty(l:build_dir)
    echoerr 'Preset의 binaryDir를 확인할 수 없습니다.'
    return 0
  endif
  let l:p.build_dir = l:build_dir
  return 1
endfunction

function! s:ChooseFallbackConfig() abort
  let l:p = s:Project()
  let l:configs = [
        \ 'Debug',
        \ 'Release',
        \ 'RelWithDebInfo',
        \ 'MinSizeRel'
        \ ]
  let l:selected =
        \ s:Choose(
        \ l:configs,
        \ 'Build Configuration 선택:',
        \ l:p.config)
  if !empty(l:selected)
    let l:p.config = l:selected
  endif
  return l:p.config
endfunction

function! s:ConfigureFallback() abort
  let l:p = s:Project()
  let l:root = universal_cmake#root()
  let l:config = s:ChooseFallbackConfig()
  let l:build =
        \ s:FallbackBuildDir(l:config)
  call mkdir(l:build, 'p')
  call s:PrepareFileAPI(l:build)
  let l:cmd =
        \ 'cmake -S '
        \ . shellescape(l:root)
        \ . ' -B '
        \ . shellescape(l:build)
        \ . ' -DCMAKE_BUILD_TYPE='
        \ . shellescape(l:config)
        \ . ' -DCMAKE_EXPORT_COMPILE_COMMANDS=ON'
  if executable('ninja')
    let l:cmd .= ' -G Ninja'
  endif
  if !s:Run(l:cmd)
    echoerr 'CMake fallback configure 실패'
    return 0
  endif
  let l:p.build_dir =
        \ simplify(
        \ fnamemodify(
        \ l:build,
        \ ':p'))
  return 1
endfunction

function! universal_cmake#configure() abort
  let l:p = s:Project()
  if !empty(l:p.configure_preset)
    let l:ok = s:ConfigurePreset()
  else
    let l:ok = s:ConfigureFallback()
  endif
  if l:ok
    echo 'Configure 성공: ' . l:p.build_dir
  endif
  return l:ok
endfunction

" ============================================================
" CMake Build
" ============================================================
function! s:BuildCurrent() abort
  let l:p = s:Project()
  call s:SyncPresetState()
  if !empty(l:p.build_preset)
    return s:Run(
          \ 'cmake --build --preset '
          \ . shellescape(l:p.build_preset))
  endif
  if empty(l:p.build_dir)
    echoerr 'Build directory가 없습니다.'
    return 0
  endif
  return s:Run(
        \ 'cmake --build '
        \ . shellescape(l:p.build_dir))
endfunction

function! universal_cmake#build() abort
  if !universal_cmake#configure()
    return 0
  endif
  if !s:BuildCurrent()
    echoerr 'CMake build 실패'
    return 0
  endif
  call universal_cmake#update_clangd()
  echo 'CMake build 성공'
  return 1
endfunction

" ============================================================
" compile_commands.json
" ============================================================
function! universal_cmake#compile_commands() abort
  let l:p = s:Project()
  if !empty(l:p.build_dir)
        \ && filereadable(l:p.build_dir . '/compile_commands.json')
    return simplify(
          \ fnamemodify(
          \ l:p.build_dir . '/compile_commands.json',
          \ ':p'))
  endif
  let l:root = universal_cmake#root()
  let l:root_cc = l:root . '/compile_commands.json'
  if filereadable(l:root_cc)
    return simplify(fnamemodify(l:root_cc, ':p'))
  endif
  return ''
endfunction

function! universal_cmake#link_compile_commands() abort
  let l:source =
        \ universal_cmake#compile_commands()
  if empty(l:source)
        \ || !filereadable(l:source)
    echoerr 'compile_commands.json을 찾을 수 없습니다.'
    return
  endif
  let l:root = universal_cmake#root()
  let l:dest = l:root . '/compile_commands.json'
  " 목적지가 존재하지 않으면 새 symbolic link 생성.
  if getftype(l:dest) ==# ''
    call system(
          \ 'ln -s '
          \ . shellescape(
          \ fnamemodify(l:source, ':p'))
          \ . ' '
          \ . shellescape(l:dest))
    if v:shell_error != 0
      echoerr 'compile_commands.json 링크 생성 실패'
      return
    endif
    echo 'compile_commands.json linked'
    return
  endif
  " 기존 일반 파일은 절대 수정하지 않는다.
  if getftype(l:dest) !=# 'link'
    echo '기존 compile_commands.json 유지: ' . l:dest
    return
  endif
  " 이미 동일한 compile_commands.json을 가리키면 유지.
  let l:current = resolve(l:dest)
  let l:expected =
        \ fnamemodify(
        \ l:source,
        \ ':p')
  if l:current ==# l:expected
    return
  endif
  " 다른 symbolic link도 소유권을 알 수 없으므로 수정하지 않는다.
  echo '기존 compile_commands.json 심볼릭 링크 유지: ' . l:dest
endfunction

" ============================================================
" clangd / CoC
" ============================================================
function! universal_cmake#clangd_dir() abort
  let l:p = s:Project()
  if !empty(l:p.build_dir)
        \ && filereadable(
        \ l:p.build_dir . '/compile_commands.json')
    return l:p.build_dir
  endif
  return ''
endfunction

function! universal_cmake#update_clangd() abort
  let l:root = universal_cmake#root()
  let l:p = s:Project()
  let l:dir = ''
  " 1. 현재 세션에서 알고 있는 build directory
  if !empty(l:p.build_dir)
        \ && filereadable(
        \ l:p.build_dir . '/compile_commands.json')
    let l:dir = l:p.build_dir
  endif
  " 2. 프로젝트 root의 compile_commands.json
  if empty(l:dir)
    let l:root_cc =
          \ l:root . '/compile_commands.json'
    if filereadable(l:root_cc)
      let l:resolved = resolve(l:root_cc)
      if filereadable(l:resolved)
        let l:dir =
              \ simplify(
              \ fnamemodify(
              \ l:resolved,
              \ ':h'))
      endif 
    endif
  endif
  " 3. 기존 fallback build directory
  if empty(l:dir)
    let l:fallback =
          \ s:FallbackBuildDir(l:p.config)
    if filereadable(
          \ l:fallback . '/compile_commands.json')
      let l:dir =
            \ simplify(
            \ fnamemodify(
            \ l:fallback,
            \ ':p'))
      let l:p.build_dir = l:dir
    endif
  endif
  " 4. 선택된 Configure Preset의 binaryDir
  if empty(l:dir)
        \ && !empty(l:p.configure_preset)
    let l:preset_dir =
          \ s:PresetBinaryDir(
          \ l:p.configure_preset)
    if !empty(l:preset_dir)
          \ && filereadable(
          \ l:preset_dir . '/compile_commands.json')
      let l:dir =
            \ simplify(
            \ fnamemodify(
            \ l:preset_dir,
            \ ':p'))
      let l:p.build_dir = l:dir
    endif
  endif
  " 5. compile_commands.json이 없으면 Configure
  if empty(l:dir)
    if !universal_cmake#configure()
      return
    endif
    let l:dir =
          \ universal_cmake#clangd_dir()
    if empty(l:dir)
      return
    endif
  endif
  " 6. 동일한 compile database를 이미 사용 중이면 종료
  if get(s:clangd_dirs, l:root, '') ==# l:dir
    return
  endif
  let s:clangd_dirs[l:root] = l:dir
  " 7. 프로젝트 root에 compile_commands.json 링크 생성
  if filereadable(
        \ l:dir . '/compile_commands.json')
    call universal_cmake#link_compile_commands()
  endif
endfunction

" ============================================================
" CMake File API / Targets
" ============================================================
function! s:CodeModel(build_dir) abort
  let l:files = glob(
        \ a:build_dir
        \ . '/.cmake/api/v1/reply/codemodel-v2-*.json',
        \ 0,
        \ 1)
  if empty(l:files)
    return ''
  endif
  call sort(
        \ l:files,
        \ {a, b -> getftime(a) > getftime(b) ? -1 : 1})
  return l:files[0]
endfunction

function! s:Targets(build_dir) abort
  let l:model_file = s:CodeModel(a:build_dir)
  if empty(l:model_file)
    return []
  endif
  let l:model = s:ReadJSON(l:model_file)
  let l:reply =
        \ fnamemodify(
        \ l:model_file,
        \ ':h')
  let l:targets = []
  let l:seen = {}
  for l:config in get(l:model, 'configurations', [])
    for l:ref in get(l:config, 'targets', [])
      let l:file =
            \ l:reply
            \ . '/'
            \ . get(l:ref, 'jsonFile', '')
      let l:data = s:ReadJSON(l:file)
      let l:name = get(l:data, 'name', '')
      let l:type = get(l:data, 'type', '')
      if empty(l:name)
            \ || has_key(l:seen, l:name)
        continue
      endif
      let l:artifacts = []
      for l:item in get(l:data, 'artifacts', [])
        let l:path =
              \ get(l:item, 'path', '')
        if !empty(l:path)
          if l:path !~# '^/'
            let l:path =
                  \ a:build_dir
                  \ . '/'
                  \ . l:path
          endif
          call add(
                \ l:artifacts,
                \ simplify(
                \ fnamemodify(
                \ l:path,
                \ ':p')))
        endif
      endfor
      call add(l:targets, {
            \ 'name': l:name,
            \ 'type': l:type,
            \ 'artifacts': l:artifacts
            \ })
      let l:seen[l:name] = 1
    endfor
  endfor
  return l:targets
endfunction

function! s:ExecutableTargets() abort
  let l:p = s:Project()
  if empty(l:p.build_dir)
    return []
  endif
  return filter(
        \ s:Targets(l:p.build_dir),
        \ 'v:val.type ==# "EXECUTABLE" && !empty(v:val.artifacts)')
endfunction

function! universal_cmake#select_target() abort
  let l:p = s:Project()
  if empty(l:p.build_dir)
    if !universal_cmake#build()
      return
    endif
  endif
  let l:targets =
        \ s:ExecutableTargets()
  if empty(l:targets)
    echoerr '실행 가능한 target을 찾을 수 없습니다.'
    return
  endif
  let l:names =
        \ map(
        \ copy(l:targets),
        \ 'v:val.name')
  let l:selected =
        \ s:Choose(
        \ l:names,
        \ 'Executable Target 선택:',
        \ l:p.target)
  if !empty(l:selected)
    let l:p.target = l:selected
    echo 'Target: ' . l:selected
  endif
endfunction

function! s:CurrentTarget() abort
  let l:p = s:Project()
  let l:targets = s:ExecutableTargets()
  if empty(l:targets)
    return {}
  endif
  for l:target in l:targets
    if l:target.name ==# l:p.target
      return l:target
    endif
  endfor
  if len(l:targets) == 1
    let l:p.target = l:targets[0].name
    return l:targets[0]
  endif
  call universal_cmake#select_target()
  for l:target in s:ExecutableTargets()
    if l:target.name ==# l:p.target
      return l:target
    endif
  endfor
  return {}
endfunction

" ============================================================
" Run
" ============================================================
function! universal_cmake#run() abort
  if !universal_cmake#build()
    return
  endif
  call s:SyncPresetState()
  let l:target = s:CurrentTarget()
  if empty(l:target)
    return
  endif
  if empty(l:target.artifacts)
    echoerr '실행 가능한 artifact를 찾을 수 없습니다.'
    return
  endif
  execute '!'
        \ . s:Shell(
        \ shellescape(
        \ l:target.artifacts[0]))
endfunction

" ============================================================
" CTest
" ============================================================
function! universal_cmake#test(...) abort
  if !universal_cmake#build()
    return
  endif
  let l:p = s:Project()
  let l:cmd =
        \ 'ctest --test-dir '
        \ . shellescape(l:p.build_dir)
        \ . ' --output-on-failure'
  if a:0 && !empty(a:1)
    let l:cmd .=
          \ ' -R '
          \ . shellescape(a:1)
  endif
  execute '!' . s:Shell(l:cmd)
endfunction

function! universal_cmake#test_current() abort
  let l:name = expand('%:t:r')
  let l:name =
        \ substitute(
        \ l:name,
        \ '_test$',
        \ '',
        \ '')
  call universal_cmake#test(l:name)
endfunction

" ============================================================
" Valgrind
" ============================================================
function! universal_cmake#valgrind() abort
  if !executable('valgrind')
    echoerr 'valgrind가 설치되어 있지 않습니다.'
    return
  endif
  if !universal_cmake#build()
    return
  endif
  let l:target = s:CurrentTarget()
  if empty(l:target)
    return
  endif
  let l:cmd =
        \ 'valgrind --leak-check=full'
        \ . ' --show-leak-kinds=all'
        \ . ' --track-origins=yes '
        \ . shellescape(l:target.artifacts[0])
  execute '!' . s:Shell(l:cmd)
endfunction

" ============================================================
" GDB
" ============================================================
function! s:GdbExit(job, status) abort
  let s:gdb_job = -1
  echo 'GDB 종료'
endfunction

function! universal_cmake#gdb() abort
  if !executable('gdb')
    echoerr 'gdb가 설치되어 있지 않습니다.'
    return
  endif
  if !universal_cmake#build()
    return
  endif
  let l:target = s:CurrentTarget()
  if empty(l:target)
    return
  endif
  botright 15split
  enew
  setlocal bufhidden=wipe
        \ nobuflisted
        \ noswapfile
  let s:gdb_job =
        \ term_start(
        \ [
        \ 'gdb',
        \ '-q',
        \ l:target.artifacts[0]
        \ ],
        \ {
        \ 'curwin': 1,
        \ 'term_name': 'gdb',
        \ 'exit_cb': function('s:GdbExit')
        \ })
  call term_sendkeys(
        \ s:gdb_job,
        \ "break main\nrun\n")
endfunction

function! universal_cmake#gdb_send(cmd) abort
  if s:gdb_job == -1
        \ || job_status(s:gdb_job) !=# 'run'
    echoerr '실행 중인 GDB를 찾을 수 없습니다.'
    return
  endif
  call term_sendkeys(
        \ s:gdb_job,
        \ a:cmd . "\n")
endfunction

function! universal_cmake#breakpoint() abort
  call universal_cmake#gdb_send(
        \ 'break '
        \ . shellescape(expand('%:p'))
        \ . ':'
        \ . line('.'))
endfunction

" ============================================================
" Project Utility
" ============================================================
function! universal_cmake#show_targets() abort
  let l:p = s:Project()
  if empty(l:p.build_dir)
    echoerr '먼저 Configure 또는 Build 하십시오.'
    return
  endif
  let l:targets =
        \ s:Targets(l:p.build_dir)
  new
  setlocal buftype=nofile
        \ bufhidden=wipe
        \ noswapfile
        \ nobuflisted
  call setline(
        \ 1,
        \ [
        \ 'CMake Targets',
        \ repeat('=', 70)
        \ ])
  for l:target in l:targets
    call append(
          \ '$',
          \ printf(
          \ '%-40s %s',
          \ l:target.name,
          \ l:target.type))
    for l:path in l:target.artifacts
      call append(
            \ '$',
            \ '  -> ' . l:path)
    endfor
  endfor
  normal! gg
endfunction

function! universal_cmake#status() abort
  let l:p = s:Project()
  echo join([
        \ 'root=' . universal_cmake#root(),
        \ 'configure=' . l:p.configure_preset,
        \ 'build=' . l:p.build_preset,
        \ 'dir=' . l:p.build_dir,
        \ 'clangd=' . universal_cmake#clangd_dir(),
        \ 'target=' . l:p.target
        \ ], "\n")
endfunction

function! universal_cmake#reset() abort
  let l:root = universal_cmake#root()
  if has_key(s:projects, l:root)
    call remove(s:projects, l:root)
  endif
  if has_key(s:clangd_dirs, l:root)
    call remove(s:clangd_dirs, l:root)
  endif
  echo '현재 프로젝트 상태 초기화'
endfunction

