if exists('g:loaded_universal_cmake_plugin')
  finish
endif
let g:loaded_universal_cmake_plugin = 1

command! CMakeRoot echo universal_cmake#root()
command! CMakeConfigure call universal_cmake#configure()
command! CMakeBuild call universal_cmake#build()
command! CMakeRun call universal_cmake#run()

command! CMakeSelectConfigurePreset call universal_cmake#select_configure_preset()
command! CMakeSelectBuildPreset call universal_cmake#select_build_preset()
command! CMakeSelectTarget call universal_cmake#select_target()

command! CMakeTargets call universal_cmake#show_targets()

command! -nargs=? CMakeTest call universal_cmake#test(<q-args>)
command! CMakeTestCurrent call universal_cmake#test_current()

command! CMakeValgrind call universal_cmake#valgrind()

command! CMakeGDB call universal_cmake#gdb()
command! -nargs=1 CMakeGDBSend call universal_cmake#gdb_send(<q-args>)
command! CMakeBreakpoint call universal_cmake#breakpoint()

command! CMakeStatus call universal_cmake#status()
command! CMakeReset call universal_cmake#reset()

command! CMakeLinkCompileCommands call universal_cmake#link_compile_commands()
command! CMakeUpdateClangd call universal_cmake#update_clangd()

