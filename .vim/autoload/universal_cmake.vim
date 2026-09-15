if exists('g:loaded_universal_cmake_autoload')
  finish
endif
let g:loaded_universal_cmake_autoload = 1

let s:projects = {}
let s:gdb_buf = -1
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

function! s:CompileCommandsRecord() abort
  return s:CacheRoot()
        \ . '/'
        \ . s:ProjectHash()
        \ . '/compile_commands.source'
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
      " CMake preset의 map 필드는 상속 시 항목별로 병합된다.
      " 특히 environment는 binaryDir의 $env{} 확장에도 사용된다.
      if index(['environment', 'cacheVariables', 'vendor'], l:key) >= 0
            \ && type(l:value) == v:t_dict
            \ && type(get(l:result, l:key, {})) == v:t_dict
        let l:merged = copy(get(l:result, l:key, {}))
        call extend(l:merged, l:value, 'force')
        let l:result[l:key] = l:merged
      else
        let l:result[l:key] = l:value
      endif
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
  for l:parent_name in reverse(copy(l:parents))
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

" NOTE:
" Preset condition은 CMake가 최종 평가한다.
" 여기서는 hidden preset만 선택 목록에서 제외한다.
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
  for [l:name, l:preset] in items(s:BuildPresetMap())
    if !get(l:preset, 'hidden', v:false)
          \ && get(
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

function! s:HostSystemName() abort
  if has('win32') || has('win64')
    return 'Windows'
  elseif has('macunix')
    return 'Darwin'
  endif
  return 'Linux'
endfunction

function! s:ParentEnvValue(name) abort
  let l:value = getenv(a:name)
  return type(l:value) == v:t_string ? l:value : ''
endfunction

function! s:PresetEnvValue(preset, name, stack) abort
  if index(a:stack, a:name) >= 0
    echoerr 'Preset environment 순환 참조: ' . a:name
    return ''
  endif
  let l:environment = get(a:preset, 'environment', {})
  if has_key(l:environment, a:name)
    let l:value = l:environment[a:name]
    if l:value is v:null
      return ''
    endif
    if type(l:value) != v:t_string
      echoerr '잘못된 preset environment 값: ' . a:name
      return ''
    endif
    return s:ExpandPresetValueInternal(
          \ l:value,
          \ a:preset,
          \ a:stack + [a:name])
  endif
  return s:ParentEnvValue(a:name)
endfunction

function! s:ExpandPresetValueInternal(value, preset, stack) abort
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
        \ '\${sourceDirName}',
        \ escape(fnamemodify(l:source, ':t'), '\&'),
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
        \ '\${fileDir}',
        \ escape(get(a:preset, '__dir', l:source), '\&'),
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
  let l:value =
        \ substitute(
        \ l:value,
        \ '\${pathListSep}',
        \ has('win32') || has('win64') ? ';' : ':',
        \ 'g')
  let l:value =
        \ substitute(
        \ l:value,
        \ '\${hostSystemName}',
        \ s:HostSystemName(),
        \ 'g')
  let l:value =
        \ substitute(
        \ l:value,
        \ '\$penv{\([^}]*\)}',
        \ '\=s:ParentEnvValue(submatch(1))',
        \ 'g')
  let l:value =
        \ substitute(
        \ l:value,
        \ '\$env{\([^}]*\)}',
        \ '\=s:PresetEnvValue(a:preset, submatch(1), a:stack)',
        \ 'g')

  " ${dollar} 결과는 다시 매크로로 해석하지 않아야 한다.
  let l:dollar_marker = nr2char(31)
  let l:value = substitute(
        \ l:value,
        \ '\${dollar}',
        \ l:dollar_marker,
        \ 'g')
  if l:value =~# '\$\%({\|env{\|penv{\)'
    echoerr '지원하지 않는 preset 매크로: ' . l:value
    return ''
  endif
  return join(split(l:value, l:dollar_marker, 1), '$')
endfunction

function! s:ExpandPresetValue(value, preset) abort
  return s:ExpandPresetValueInternal(a:value, a:preset, [])
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
  if empty(l:selected)
    return ''
  endif
  if l:selected !=# l:p.config
    let l:p.build_dir = ''
    let l:p.target = ''
  endif
  let l:p.config = l:selected
  return l:selected
endfunction

function! s:ConfigureFallback(choose_config) abort
  let l:p = s:Project()
  let l:root = universal_cmake#root()
  if a:choose_config
    let l:config = s:ChooseFallbackConfig()
    if empty(l:config)
      echo 'Build Configuration 선택을 취소했습니다.'
      return 0
    endif
  else
    let l:config = l:p.config
  endif
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

function! universal_cmake#configure(...) abort
  let l:p = s:Project()
  if !empty(l:p.configure_preset)
    let l:ok = s:ConfigurePreset()
  else
    " 명시적인 :CMakeConfigure는 configuration을 묻고,
    " Build가 내부 호출할 때는 현재 값을 그대로 사용한다.
    let l:choose_config = a:0 ? a:1 : 1
    let l:ok = s:ConfigureFallback(l:choose_config)
  endif
  if l:ok
    echo 'Configure 성공: ' . l:p.build_dir
  endif
  return l:ok
endfunction

" ============================================================
" CMake Build
" ============================================================
function! s:IsMultiConfig(build_dir) abort
  let l:cache = a:build_dir . '/CMakeCache.txt'
  if !filereadable(l:cache)
    return 0
  endif
  for l:line in readfile(l:cache)
    if l:line =~# '^CMAKE_CONFIGURATION_TYPES:[^=]*='
      return 1
    endif
  endfor
  return 0
endfunction

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
  let l:cmd =
        \ 'cmake --build '
        \ . shellescape(l:p.build_dir)
  if s:IsMultiConfig(l:p.build_dir)
    let l:cmd .=
          \ ' --config '
          \ . shellescape(s:ActiveConfig())
  endif
  return s:Run(l:cmd)
endfunction

function! universal_cmake#build() abort
  if !universal_cmake#configure(0)
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

function! s:WriteCompileCommandsRecord(source) abort
  let l:record = s:CompileCommandsRecord()
  if !isdirectory(fnamemodify(l:record, ':h'))
        \ && mkdir(fnamemodify(l:record, ':h'), 'p') == 0
    echoerr 'compile_commands 링크 기록 디렉터리 생성 실패'
    return 0
  endif
  if writefile([a:source], l:record) != 0
    echoerr 'compile_commands 링크 기록 실패'
    return 0
  endif
  return 1
endfunction

function! s:RecordedCompileCommandsSource() abort
  let l:record = s:CompileCommandsRecord()
  if !filereadable(l:record)
    return ''
  endif
  let l:lines = readfile(l:record, '', 1)
  return empty(l:lines) ? '' : l:lines[0]
endfunction

function! s:LinkCompileCommands(source) abort
  let l:source = resolve(fnamemodify(a:source, ':p'))
  if empty(l:source)
        \ || !filereadable(l:source)
    echoerr 'compile_commands.json을 찾을 수 없습니다.'
    return 0
  endif
  let l:root = universal_cmake#root()
  let l:dest = l:root . '/compile_commands.json'
  let l:expected = l:source

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
      return 0
    endif
    if !s:WriteCompileCommandsRecord(l:expected)
      return 0
    endif
    echo 'compile_commands.json linked'
    return 1
  endif

  " 기존 일반 파일은 절대 수정하지 않는다.
  if getftype(l:dest) !=# 'link'
    echo '기존 compile_commands.json 유지: ' . l:dest
    return 0
  endif

  " 이미 동일한 compile_commands.json을 가리키면 유지.
  let l:current = resolve(l:dest)
  if l:current ==# l:expected
    " 이전 버전이 만든 동일한 링크를 안전하게 관리 대상으로 인계한다.
    return s:WriteCompileCommandsRecord(l:expected)
  endif

  " 기록된 대상과 현재 링크가 일치할 때만 플러그인 소유 링크로 본다.
  let l:recorded = s:RecordedCompileCommandsSource()
  if empty(l:recorded) || l:current !=# l:recorded
    echo '사용자 소유 compile_commands.json 링크 유지: ' . l:dest
    return 0
  endif

  " 같은 디렉터리에서 임시 링크를 만든 후 원자적으로 교체한다.
  let l:temporary = l:dest . '.vim-cmake.' . getpid()
  if getftype(l:temporary) !=# ''
    echoerr '임시 compile_commands.json 링크가 이미 존재합니다.'
    return 0
  endif
  call system(
        \ 'ln -s '
        \ . shellescape(l:expected)
        \ . ' '
        \ . shellescape(l:temporary))
  if v:shell_error != 0
    echoerr '임시 compile_commands.json 링크 생성 실패'
    return 0
  endif
  if rename(l:temporary, l:dest) != 0
    call delete(l:temporary)
    echoerr 'compile_commands.json 링크 교체 실패'
    return 0
  endif
  if !s:WriteCompileCommandsRecord(l:expected)
    return 0
  endif
  echo 'compile_commands.json link updated'
  return 1
endfunction

function! universal_cmake#link_compile_commands() abort
  let l:source = universal_cmake#compile_commands()
  return s:LinkCompileCommands(l:source)
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
  " 5. compile_commands.json이 없으면 조용히 종료
  " Configure는 사용자가 CMakeConfigure 또는 Build로 명시적으로 수행한다.
  if empty(l:dir)
    return
  endif
  " 6. 동일한 compile database를 이미 사용 중이면 종료
  if get(s:clangd_dirs, l:root, '') ==# l:dir
    return
  endif
  " 7. 링크 동기화가 성공한 뒤에만 현재 DB 상태를 기록한다.
  let l:source = l:dir . '/compile_commands.json'
  if filereadable(l:source)
        \ && s:LinkCompileCommands(l:source)
    let s:clangd_dirs[l:root] = l:dir
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

function! s:ActiveConfig() abort
  let l:p = s:Project()
  if !empty(l:p.build_preset)
    let l:presets = s:BuildPresetMap()
    if has_key(l:presets, l:p.build_preset)
      let l:config =
            \ get(
            \ l:presets[l:p.build_preset],
            \ 'configuration',
            \ '')
      if !empty(l:config)
        return l:config
      endif
    endif
  endif
  return l:p.config
endfunction

function! s:Targets(build_dir) abort
  let l:model_file = s:CodeModel(a:build_dir)
  if empty(l:model_file)
    return []
  endif
  let l:model = s:ReadJSON(l:model_file)
  let l:reply = fnamemodify(l:model_file, ':h')
  let l:targets = []
  let l:seen = {}
  let l:configs =
        \ get(
        \ l:model,
        \ 'configurations',
        \ [])
  let l:active_config = s:ActiveConfig()
  let l:matching_configs =
        \ filter(
        \ copy(l:configs),
        \ 'get(v:val, "name", "") ==# l:active_config')
  if !empty(l:matching_configs)
    let l:configs = l:matching_configs
  endif
  for l:config in l:configs
    for l:reference in get(l:config, 'targets', [])
      let l:json_file =
            \ get(
            \ l:reference,
            \ 'jsonFile',
            \ '')
      if empty(l:json_file)
        continue
      endif
      let l:target_file =
            \ l:reply
            \ . '/'
            \ . l:json_file
      let l:data = s:ReadJSON(l:target_file)
      if empty(l:data)
        continue
      endif
      let l:name =
            \ get(
            \ l:data,
            \ 'name',
            \ get(l:reference, 'name', ''))
      if empty(l:name)
            \ || has_key(l:seen, l:name)
        continue
      endif
      let l:artifacts = []
      for l:artifact in get(l:data, 'artifacts', [])
        let l:path = get(l:artifact, 'path', '')
        if empty(l:path)
          continue
        endif
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
      endfor
      let l:seen[l:name] = 1
      call add(l:targets, {
            \ 'name': l:name,
            \ 'type': get(l:data, 'type', ''),
            \ 'artifacts': l:artifacts
            \ })
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
      return 0
    endif
  endif
  let l:targets = s:ExecutableTargets()
  if empty(l:targets)
    echoerr '실행 가능한 target을 찾을 수 없습니다.'
    return 0
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
  if empty(l:selected)
    echo 'Target 선택을 취소했습니다.'
    return 0
  endif
  let l:p.target = l:selected
  echo 'Target: ' . l:selected
  return 1
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
    echoerr '실행 가능한 target을 찾을 수 없습니다.'
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
  " Valgrind로 검사할 실행 파일을 명시적으로 선택한다.
  if !universal_cmake#select_target()
    return
  endif
  let l:target = s:CurrentTarget()
  if empty(l:target)
    echoerr '실행 가능한 target을 찾을 수 없습니다.'
    return
  endif
  if empty(l:target.artifacts)
    echoerr '실행 가능한 artifact를 찾을 수 없습니다.'
    return
  endif
  let l:cmd =
        \ 'valgrind --leak-check=full'
        \ . ' --show-leak-kinds=all'
        \ . ' --track-origins=yes '
        \ . shellescape(l:target.artifacts[0])
  execute '!' . s:Shell(l:cmd)
endfunction

" ========================================================
" GDB
" ============================================================
function! s:GdbExit(job, status) abort
  let s:gdb_buf = -1
  echo 'GDB 종료'
endfunction

function! universal_cmake#gdb() abort
  if !executable('gdb')
    echoerr 'gdb가 설치되어 있지 않습니다.'
    return
  endif
  if s:gdb_buf != -1
        \ && bufexists(s:gdb_buf)
        \ && job_status(term_getjob(s:gdb_buf)) ==# 'run'
    echoerr '이미 실행 중인 GDB가 있습니다.'
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
  let s:gdb_buf =
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
        \ s:gdb_buf,
        \ "break main\nrun\n")
endfunction

function! universal_cmake#gdb_send(cmd) abort
  if s:gdb_buf == -1
        \ || !bufexists(s:gdb_buf)
        \ || job_status(term_getjob(s:gdb_buf)) !=# 'run'
    echoerr '실행 중인 GDB를 찾을 수 없습니다.'
    return
  endif
  call term_sendkeys(
        \ s:gdb_buf,
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

