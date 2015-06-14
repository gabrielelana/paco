" autoload the local .vimrc file you need to have
" https://github.com/MarcWeber/vim-addon-local-vimrc
" plugin installed

let g:syntastic_elixir_checkers = ["elixir"]
let g:syntastic_enable_elixir_checker = 1
let g:syntastic_mode_map = {"mode": "passive", "passive_filetypes": ["elixir"]}

let g:ctrlp_custom_ignore = "_build"

nnoremap <silent> <Leader>c :SyntasticCheck<CR>
nnoremap <silent> <Leader>a :exec "!mix test"<CR>
nnoremap <silent> <Leader>t :exec "!mix test " . expand("%")<CR>
nnoremap <silent> <Leader>f :exec "!mix test " . expand("%") . ":" . line(".")<CR>
nnoremap <silent> <Leader>r :exec "!mix run " . expand("%")<CR>
