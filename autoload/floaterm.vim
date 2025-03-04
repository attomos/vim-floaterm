" vim:fdm=indent
" ========================================================================
" Description: autoload/floaterm.vim
" Author: voldikss
" GitHub: https://github.com/voldikss/vim-floaterm
" ========================================================================

if has('nvim') && exists('*nvim_win_set_config')
  let g:floaterm_type = 'floating'
else
  let g:floaterm_type = 'normal'
endif

function! floaterm#toggleTerminal(height, width) abort
  let found_winnr = 0
  for winnr in range(1, winnr('$'))
    if getbufvar(winbufnr(winnr), '&buftype') == 'terminal'
      \ && getbufvar(winbufnr(winnr), 'floaterm_window') == 1
      let found_winnr = winnr
    endif
  endfor

  if found_winnr > 0
    if &buftype == 'terminal'
      " if current window is the terminal window, close it
      execute found_winnr . ' wincmd q'
    else
      " if current window is not terminal, go to the terminal window
      execute found_winnr . ' wincmd w'
    endif
  else
    let found_bufnr = 0
    for bufnr in filter(range(1, bufnr('$')), 'bufexists(v:val)')
      let buftype = getbufvar(bufnr, '&buftype')
      if buftype == 'terminal' && getbufvar(bufnr, 'floaterm_window') == 1
        let found_bufnr = bufnr
      endif
    endfor

    let height = a:height == v:null ? float2nr(0.7*&lines) : float2nr(a:height)
    let width = a:width == v:null ? float2nr(0.7*&columns) : float2nr(a:width)

    if g:floaterm_type == 'floating'
      call s:openTerminalFloating(found_bufnr, height, width)
    else
      call s:openTerminalNormal(found_bufnr, height, width)
    endif
    call s:onOpenTerminal()
  endif
endfunction

function! s:openTerminalFloating(found_bufnr, height, width) abort
  let [relative, row, col, vert, hor] = s:getWindowPosition(a:width, a:height)
  let opts = {
    \ 'relative': relative,
    \ 'width': a:width,
    \ 'height': a:height,
    \ 'col': col,
    \ 'row': row,
    \ 'anchor': vert . hor
  \ }

  if a:found_bufnr > 0
    call nvim_open_win(a:found_bufnr, 1, opts)
  else
    let bufnr = nvim_create_buf(v:false, v:true)
    call nvim_open_win(bufnr, 1, opts)
    terminal
  endif
endfunction

function! s:openTerminalNormal(found_bufnr, height, width) abort
  if a:found_bufnr > 0
    if &lines > 30
      execute 'botright ' . a:height . 'split'
      execute 'buffer ' . a:found_bufnr
    else
      botright split
      execute 'buffer ' . a:found_bufnr
    endif
  else
    if &lines > 30
      if has('nvim')
        execute 'botright ' . a:height . 'split term://' . &shell
      else
        botright terminal
        resize a:height
      endif
    else
      if has('nvim')
        execute 'botright split term://' . &shell
      else
        botright terminal
      endif
    endif
  endif
endfunction

function! s:getWindowPosition(width, height) abort
  let bottom_line = line('w0') + &lines - 1
  let relative = 'editor'
  if g:floaterm_position == 'topright'
    let row = 0
    let col = &columns
    let vert = 'N'
    let hor = 'E'
  elseif g:floaterm_position == 'topleft'
    let row = 0
    let col = 0
    let vert = 'N'
    let hor = 'W'
  elseif g:floaterm_position == 'bottomright'
    let row = &lines
    let col = &columns
    let vert = 'S'
    let hor = 'E'
  elseif g:floaterm_position == 'bottomleft'
    let row = &lines
    let col = 0
    let vert = 'S'
    let hor = 'W'
  elseif g:floaterm_position == 'center'
    let row = (&lines - a:height)/2
    let col = (&columns - a:width)/2
    let vert = 'N'
    let hor = 'W'

    if row < 0
      let row = 0
    endif
    if col < 0
      let col = 0
    endif
  else
    let relative = 'cursor'
    let curr_pos = getpos('.')
    let rownr = curr_pos[1]
    let colnr = curr_pos[2]
    " a long wrap line
    if colnr > &columns
      let colnr = colnr % &columns
      let rownr += colnr / &columns
    endif

    if rownr + a:height <= bottom_line
      let vert = 'N'
      let row = 1
    else
      let vert = 'S'
      let row = 0
    endif

    if colnr + a:width <= &columns
      let hor = 'W'
      let col = 0
    else
      let hor = 'E'
      let col = 1
    endif
  endif

  return [relative, row, col, vert, hor]
endfunction

function! s:onOpenTerminal() abort
  call setbufvar(bufnr('%'), 'floaterm_window', 1)

  execute 'setlocal winblend=' . g:floaterm_winblend
  setlocal bufhidden=hide
  setlocal signcolumn=no
  setlocal nobuflisted
  setlocal nocursorline
  setlocal nonumber
  setlocal norelativenumber
  setlocal foldcolumn=1
  setlocal filetype=terminal

  " iterate to find the background for floating
  if g:floaterm_background == v:null
    let hiGroup = 'NormalFloat'
    while 1
      let hiInfo = execute('hi ' . hiGroup)
      let g:floaterm_background = matchstr(hiInfo, 'guibg=\zs\S*')
      let hiGroup = matchstr(hiInfo, 'links to \zs\S*')
      if g:floaterm_background != '' || hiGroup == ''
        break
      endif
    endwhile
  endif
  if g:floaterm_background != ''
    execute 'hi FloatTermNormal term=None guibg='. g:floaterm_background
    call setbufvar(bufnr('%'), '&winhl', 'Normal:FloatTermNormal,FoldColumn:FloatTermNormal')
  endif

  augroup NvimCloseTermWin
    autocmd!
    autocmd TermClose <buffer> if &buftype=='terminal'
      \ && getbufvar(bufnr('%'), 'floaterm_window') == 1 |
      \ bdelete! |
      \ endif
  augroup END
endfunction
