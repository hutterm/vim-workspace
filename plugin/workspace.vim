" Vim plugin
" Author:  Thaer Khawaja
" License: Apache 2.0
" URL:     https://github.com/thaerkh/vim-workspace

let g:workspace_session_name = get(g:, 'workspace_session_name', 'Session.vim')
let g:workspace_session_disable_on_args = get(g:, 'workspace_session_disable_on_args', 0)
let g:workspace_undodir = get(g:, 'workspace_undodir', '.undodir')
let g:workspace_persist_undo_history = get(g:, 'workspace_persist_undo_history', 1)
let g:workspace_autosave = get(g:, 'workspace_autosave', 1)
let g:workspace_autosave_always = get(g:, 'workspace_autosave_always', 0)
let g:workspace_autosave_ignore = get(g:, 'workspace_autosave_ignore', ['gitcommit', 'gitrebase', 'nerdtree'])
let g:workspace_autosave_untrailspaces = get(g:, 'workspace_autosave_untrailspaces', 1)
let g:workspace_autosave_untrailtabs = get(g:, 'workspace_autosave_untrailtabs', 1)
let g:workspace_autosave_au_updatetime = get(g:, 'workspace_autosave_au_updatetime', 3)
let g:workspace_autocreate = get(g:, 'workspace_autocreate', 0)
let g:workspace_nocompatible = get(g:, 'workspace_nocompatible', 1)
let g:workspace_session_directory = get(g:, 'workspace_session_directory', '')
let g:workspace_create_new_tabs = get(g:, 'workspace_create_new_tabs', 1)

function! s:IsSessionDirectoryUsed()
  return !empty(g:workspace_session_directory)
endfunction

function! s:GetSessionDirectoryPath()
  if !isdirectory(g:workspace_session_directory)
    call mkdir(g:workspace_session_directory)
  endif
  let l:cwd = getcwd()
  if has('win32')
    let l:fileName = substitute(l:cwd, '\', '_', 'g')
    let l:fileName = substitute(l:fileName, ':', '_', 'g')
    let l:fileName = substitute(l:fileName, ' ', '_', 'g')
	let l:fileName = substitute(l:fileName, '%', '_', 'g')
  else
    let l:fileName = substitute(l:cwd, '/', '_', 'g')
  endif
  let l:fullPath = g:workspace_session_directory . l:fileName
  return l:fullPath
endfunction

function! s:GetSessionName()
  if s:IsSessionDirectoryUsed()
    return s:GetSessionDirectoryPath()
  else
    return g:workspace_session_name
  endif
endfunction

function! s:WorkspaceExists()
  return filereadable(s:GetSessionName())
endfunction

function! s:IsAbsolutePath(path)
  return (fnamemodify(a:path, ':p') == a:path)
endfunction

function! s:MakeWorkspace(workspace_save_session)
  if a:workspace_save_session == 1 || get(s:, 'workspace_save_session', 0) == 1
    let s:workspace_save_session = 1
    if s:IsSessionDirectoryUsed()
      execute printf('mksession! %s', escape(s:GetSessionDirectoryPath(), '%'))
    elseif s:IsAbsolutePath(g:workspace_session_name)
      execute printf('mksession! %s', g:workspace_session_name)
    else
      execute printf('mksession! %s/%s', getcwd(), g:workspace_session_name)
    endif
  endif
endfunction

function! s:FindOrNew(filename)
  let l:fnr = bufnr(a:filename)
  for tabnr in range(1, tabpagenr("$"))
    for bufnr in tabpagebuflist(tabnr)
      if (bufnr == l:fnr)
        execute 'tabn ' . tabnr
        call win_gotoid(win_findbuf(l:fnr)[0])
        return
      endif
    endfor
  endfor
  if g:workspace_create_new_tabs
    tabnew
  endif
  execute 'buffer ' . l:fnr
endfunction

function! s:CloseHiddenBuffers()
  let l:visible_buffers = {}
  for tabnr in range(1, tabpagenr('$'))
    for bufnr in tabpagebuflist(tabnr)
      let l:visible_buffers[bufnr] = 1
    endfor
  endfor

  for bufnr in range(1, bufnr('$'))
    if bufexists(bufnr) && !has_key(l:visible_buffers,bufnr)
      execute printf('bwipeout %d', bufnr)
    endif
  endfor
endfunction

function! s:ConfigureWorkspace()
  call s:SetUndoDir()
  call s:SetAutosave(1)
endfunction

function! s:RemoveWorkspace()
  let s:workspace_save_session  = 0
  if has('win32')
    execute printf('silent !del /q "%s"', s:GetSessionName())
  else
    execute printf('call delete("%s")', s:GetSessionName())
  endif
  if !g:workspace_autosave_always
    call s:SetAutosave(0)
  endif
endfunction

function! s:ToggleWorkspace()
  if s:WorkspaceExists()
    call s:RemoveWorkspace()
    if has('win32')
      execute printf('silent !rd /s /q "%s"', s:GetUndoDir())
    else
      execute printf('silent !rm -rf "%s"', s:GetUndoDir())
    endif
    call feedkeys("") | silent! redraw!  " Recover view from external comand
    echo 'Workspace removed!'
  else
    call s:MakeWorkspace(1)
    call s:ConfigureWorkspace()
    echo 'Workspace created!'
  endif
endfunction

function! s:LoadWorkspace()
  if index(g:workspace_autosave_ignore, &filetype) != -1 || get(s:, 'read_from_stdin', 0) || (g:workspace_session_disable_on_args && argc() != 0)
    return
  endif

  if s:WorkspaceExists()
    let s:workspace_save_session = 1
    let l:filename = expand(@%)
    if g:workspace_nocompatible | set nocompatible | endif
    execute 'source ' . escape(s:GetSessionName(), '%')
    call s:ConfigureWorkspace()
    call s:FindOrNew(l:filename)
  else
    if g:workspace_autocreate
      call s:ToggleWorkspace()
    else
      let s:workspace_save_session = 0
    endif
  endif
  set sessionoptions-=options
endfunction

function! s:UntrailSpaces()
  if g:workspace_autosave_untrailspaces && &modifiable
    let curr_row = line('.')
    let curr_col = col('.')
    execute 's/\ \+$//e'
    cal cursor(curr_row, curr_col)
  endif
endfunction

function! s:UntrailTabs()
  if g:workspace_autosave_untrailtabs && &modifiable
    let curr_row = line('.')
    let curr_col = col('.')
    execute 's/\t\+$//e'
    cal cursor(curr_row, curr_col)
  endif
endfunction

function! s:Autosave(timed)
  if index(g:workspace_autosave_ignore, &filetype) != -1 || &readonly || mode() == 'c' || pumvisible()
    return
  endif

  let current_time = localtime()
  let s:last_update = get(s:, 'last_update', 0)
  let s:time_delta = current_time - s:last_update

  if a:timed == 0 || s:time_delta >= 1
    let s:last_update = current_time
    checktime  " checktime with autoread will sync files on a last-writer-wins basis.
    call s:UntrailSpaces()
    call s:UntrailTabs()
    silent! doautocmd BufWritePre %  " needed for soft checks
    silent! update  " only updates if there are changes to the file.
    if a:timed == 0 || s:time_delta >= g:workspace_autosave_au_updatetime
      silent! doautocmd BufWritePost %  " Periodically trigger BufWritePost.
    endif
  endif
endfunction

function! s:SetAutosave(enable)
  if !g:workspace_autosave
    return
  endif
  if a:enable == 1
    let s:autoread = &autoread
    let s:autowriteall = &autowriteall
    let s:swapfile  = &swapfile
    let s:updatetime = &updatetime
    set autoread
    set autowriteall
    set noswapfile
    " don't clobber lower settings by user
    if s:updatetime >= 1000
      set updatetime=1000 " limited to 1s as default to match localtime() trigger limitations,
    endif
    if !has('nvim')
      let s:swapsync = &swapsync
      set swapsync=""
    endif
    augroup WorkspaceToggle
      au! BufLeave,FocusLost,FocusGained,InsertLeave * call s:Autosave(0)
      au! CursorHold * call s:Autosave(1)
      au! BufEnter * call s:MakeWorkspace(0)
    augroup END
    let s:autosave_on = 1
  else
    let &autoread = s:autoread
    let &autowriteall = s:autowriteall
    let &updatetime = s:updatetime
    let &swapfile = s:swapfile
    if !has('nvim')
      let &swapsync = s:swapsync
    endif
    au! WorkspaceToggle * *
    let s:autosave_on = 0
  endif
endfunction

function! s:ToggleAutosave()
  if get(s:, 'autosave_on', 0)
    call s:SetAutosave(0)
    echo 'Autosave disabled!'
  else
    call s:SetAutosave(1)
    echo 'Autosave enabled!'
  endif
endfunction

function! s:GetUndoDir()
  if s:IsSessionDirectoryUsed()
    return s:GetSessionDirectoryPath() . g:workspace_undodir
  else
    return g:workspace_undodir
  endif
endfunction

function! s:SetUndoDir()
  if g:workspace_persist_undo_history
    let l:undodir = s:GetUndoDir()
    if !isdirectory(l:undodir)
      call mkdir(l:undodir)
    endif
    execute 'set undodir="' . resolve(l:undodir) . '"' 
    set undofile
  endif
endfunction

function! s:PostLoadCleanup()
  if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
endfunction

augroup Workspace
  au! VimEnter * nested call s:LoadWorkspace()
  au! StdinReadPost * let s:read_from_stdin = 1
  au! VimLeave * call s:MakeWorkspace(0)
  au! InsertLeave * if getcmdwintype() == '' && pumvisible() == 0|pclose|endif
  au! SessionLoadPost * call s:PostLoadCleanup()
augroup END

augroup WorkspaceAutosave
  au! VimEnter * if g:workspace_autosave_always == 1 | call s:SetAutosave(1) | endif
augroup END

command! ToggleAutosave call s:ToggleAutosave()
command! ToggleWorkspace call s:ToggleWorkspace()
command! CloseHiddenBuffers call s:CloseHiddenBuffers()

" vim: ts=2 sw=2 et
