" =================================================================
" C/C++ Vim Configuration
" C++20/23 | Universal CMake | CTest | Valgrind | GDB | CoC
" =================================================================

set nocompatible
set encoding=utf-8
set fileencodings=utf-8,cp949
scriptencoding utf-8
set ttimeout ttimeoutlen=40
set isfname+=~,*,?,[,],-
set path=.,/usr/include/c++/*,/usr/include,/usr/local/include,,
set suffixesadd=.h,.c,.cc,.C,.cpp,.cxx,.hpp,.hxx
set ignorecase smartcase autoread
set splitbelow splitright

let mapleader = ' '

" =================================================================
" Plugins
" =================================================================
call plug#begin('~/.vim/plugged')
Plug 'preservim/nerdtree'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'vim-airline/vim-airline'
Plug 'junegunn/fzf', {'do': { -> fzf#install() }}
Plug 'junegunn/fzf.vim'
Plug 'Yggdroot/indentLine'
Plug 'morhetz/gruvbox'
Plug 'derekwyatt/vim-fswitch'
Plug 'pboettch/vim-cmake-syntax'
call plug#end()

" =================================================================
" UI / Editing
" =================================================================
filetype plugin indent on
syntax on

set number cursorline
set termguicolors background=dark
set autoindent cindent
set tabstop=2 shiftwidth=2 expandtab
set completeopt=noinsert,menuone
set clipboard=unnamedplus
set signcolumn=yes
set colorcolumn=100
set conceallevel=0

let g:gruvbox_contrast_dark = 'medium'
let g:gruvbox_bold = 0
let g:gruvbox_italic = 0
colorscheme gruvbox

let g:airline_theme = 'gruvbox'
let g:airline_powerline_fonts = 0
let g:vim_json_conceal = 0

augroup CustomHighlights
  autocmd!
  autocmd ColorScheme gruvbox highlight CursorLine guibg=#2a2a2a
  autocmd ColorScheme gruvbox highlight ColorColumn guibg=#1f1f1f
  autocmd ColorScheme gruvbox highlight CocFloating ctermbg=235 guibg=#3c3836
  autocmd ColorScheme gruvbox highlight CocErrorFloat ctermfg=203 guifg=#fb4934
  autocmd ColorScheme gruvbox highlight CocInfoFloat ctermfg=214 guifg=#fabd2f
  autocmd ColorScheme gruvbox highlight CocWarningFloat ctermfg=208 guifg=#fe8019
  autocmd ColorScheme gruvbox highlight CocDisabled ctermfg=242 guifg=#665c54
  autocmd ColorScheme gruvbox highlight CocHintFloat ctermfg=250 guifg=#d5c4a1
  autocmd ColorScheme gruvbox highlight CocFadeOut ctermfg=250 guifg=#a89984
  autocmd ColorScheme gruvbox highlight CocUnusedSuggest ctermfg=250 guifg=#a89984
augroup END

doautocmd ColorScheme gruvbox

let g:indentLine_char = '┊'
let g:indentLine_color_gui = '#504945'

" =================================================================
" CoC / LSP
" =================================================================
nnoremap <F1> :CocCommand document.toggleInlayHint<CR>
nnoremap <F4> :FSHere<CR>

nnoremap <silent> K :call CocActionAsync('doHover')<CR>
nnoremap <silent> gd <Plug>(coc-definition)
nnoremap <silent> gy <Plug>(coc-type-definition)
nnoremap <silent> gi <Plug>(coc-implementation)
nnoremap <silent> gr <Plug>(coc-references)
nnoremap <silent> <leader>rn <Plug>(coc-rename)
function! s:FormatCode() abort
  if CocHasProvider('format')
    call CocAction('format')
  else
    normal! gg=G
    echo 'LSP Formatter 미연동: gg=G 적용'
  endif
endfunction

nnoremap <silent> <leader>cf :call <SID>FormatCode()<CR>
" =================================================================
" Search / Files
" =================================================================
nnoremap <C-n> :NERDTreeToggle<CR>
nnoremap <C-p> :Files<CR>
nnoremap <leader>rg :Rg<CR>

" =================================================================
" Insert / Completion
" =================================================================
inoremap jk <Esc>
inoremap kj <Esc>

function! s:CheckBackSpace() abort
  let l:col = col('.') - 1
  return !l:col || getline('.')[l:col - 1] =~# '\s'
endfunction

inoremap <silent><expr> <CR> coc#pum#visible()
      \ ? coc#pum#confirm()
      \ : "\<C-g>u\<CR>\<C-r>=coc#on_enter()\<CR>"

inoremap <silent><expr> <TAB> coc#pum#visible()
      \ ? coc#pum#next(1)
      \ : <SID>CheckBackSpace()
      \ ? "\<Tab>"
      \ : coc#refresh()

inoremap <expr> <S-TAB> coc#pum#visible()
      \ ? coc#pum#prev(1)
      \ : "\<C-h>"

" =================================================================
" vim-fswitch
" =================================================================
augroup FSwitchPaths
  autocmd!
  autocmd BufEnter *.cpp,*.cc,*.c,*.cxx
        \ let b:fswitchdst = 'h,hpp,hxx' |
        \ let b:fswitchlocs = 'reg:|src|include|,reg:|src|../include|,../include,.,tests'
  autocmd BufEnter *.h,*.hpp,*.hxx
        \ let b:fswitchdst = 'cpp,cc,c,cxx' |
        \ let b:fswitchlocs = 'reg:|include|src|,reg:|include|../src|,../src,.,tests'
augroup END

" =================================================================
" WSL Clipboard
" =================================================================
let g:clipboard = {
      \ 'name': 'win32yank',
      \ 'copy': {
      \   '+': 'win32yank.exe -i --crlf',
      \   '*': 'win32yank.exe -i --crlf'
      \ },
      \ 'paste': {
      \   '+': 'win32yank.exe -o --lf',
      \   '*': 'win32yank.exe -o --lf'
      \ },
      \ 'cache_enabled': 0
      \ }

" =================================================================
" Cursor Shape
" =================================================================
if !has('gui_running')
  let &t_SI = "\<Esc>[5 q"
  let &t_EI = "\<Esc>[2 q"
  let &t_SR = "\<Esc>[3 q"
endif

" =================================================================
" Universal CMake
" ~/.vim/autoload/universal_cmake.vim
" ~/.vim/plugin/universal_cmake.vim
" =================================================================

" Build / Run / Test / Debug
nnoremap <silent> <F5> :w<CR>:CMakeBuild<CR>
nnoremap <silent> <F6> :w<CR>:CMakeRun<CR>
nnoremap <silent> <F7> :w<CR>:CMakeTest<CR>
nnoremap <silent> <F8> :w<CR>:CMakeGDB<CR>

" Configure / Presets
nnoremap <silent> <leader>bc :CMakeConfigure<CR>
nnoremap <silent> <leader>bp :CMakeSelectConfigurePreset<CR>
nnoremap <silent> <leader>bb :CMakeSelectBuildPreset<CR>

" Targets / Run
nnoremap <silent> <leader>bt :CMakeSelectTarget<CR>
nnoremap <silent> <leader>br :CMakeRun<CR>
nnoremap <silent> <leader>ba :CMakeTargets<CR>

" Debug
nnoremap <silent> <leader>bd :CMakeGDB<CR>
nnoremap <silent> <leader>bk :CMakeBreakpoint<CR>

nnoremap <silent> <F10> :call universal_cmake#gdb_send('next')<CR>
tnoremap <silent> <F10> <C-\><C-n>:call universal_cmake#gdb_send('next')<CR>i

nnoremap <silent> <F11> :call universal_cmake#gdb_send('step')<CR>
tnoremap <silent> <F11> <C-\><C-n>:call universal_cmake#gdb_send('step')<CR>i

nnoremap <silent> <F12> :call universal_cmake#gdb_send('continue')<CR>
tnoremap <silent> <F12> <C-\><C-n>:call universal_cmake#gdb_send('continue')<CR>i

" Test / Analysis
nnoremap <silent> <leader>tb :CMakeTest<CR>
nnoremap <silent> <leader>tc :CMakeTestCurrent<CR>
nnoremap <silent> <leader>bv :CMakeValgrind<CR>

" Project / clangd
nnoremap <silent> <leader>cs :CMakeStatus<CR>
nnoremap <silent> <leader>cr :CMakeReset<CR>
nnoremap <silent> <leader>cl :CMakeLinkCompileCommands<CR>

augroup UniversalCMakeClangd
  autocmd!
  autocmd BufEnter *.c,*.cc,*.cpp,*.cxx,*.h,*.hpp,*.hxx call universal_cmake#update_clangd()
augroup END

" =================================================================
" Misc
" =================================================================
nnoremap <silent> <Esc><Esc> :nohlsearch<CR>

