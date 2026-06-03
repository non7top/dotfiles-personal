" [count]z?     Print all lines (with numbers) that start a fold where
"           the current line is contained in (for [count] upper
"           levels). When a line consists of just a symbol like "{",
"           the preceding non-empty line is printed, too.
" [count]z/     Like z?, but use a short output format with all line
"           contents concatenated, and without line numbers and
"           symbols.
if ! exists('g:PrintFoldHierarchySymbolLinePattern')
    let g:PrintFoldHierarchySymbolLinePattern = '^\s*{\s*$'
endif
function! s:PrintFoldHierarchy( count, isJoin )
    if foldclosed('.') != -1
        return 0
    endif

    let l:save_view = winsaveview()
        let l:levels = []
        let l:lnum = line('.')
        while (a:count ? len(l:levels) < a:count : 1)
            silent! normal! [z
            if line('.') == l:lnum
                break
            endif
            let l:lnum = line('.')
            call insert(l:levels, l:lnum)
            if getline(l:lnum) =~# g:PrintFoldHierarchySymbolLinePattern
                let l:precedingLnum = prevnonblank(l:lnum - 1)
                if l:precedingLnum > 0
                    if a:isJoin
                        let l:levels[0] = l:precedingLnum
                    else
                        call insert(l:levels, l:precedingLnum)
                    endif
                endif
            endif
        endwhile
    call winrestview(l:save_view)

    if a:isJoin
        echo
        let l:isFirst = 1
        for l:lnum in l:levels
            if l:isFirst
                let l:isFirst = 0
            else
                echohl SpecialKey
                echon ' / '
                echohl None
            endif
            echon ingo#str#Trim(getline(l:lnum))
        endfor
    else
        for l:lnum in l:levels
            echohl LineNr
            echo printf('%' . (ingo#window#dimensions#GetNumberWidth(1) - 1) . 'd ', l:lnum)
            echohl None
            echon getline(l:lnum)
        endfor
    endif

    return 1
endfunction
nnoremap <silent> z? :<C-u>if ! <SID>PrintFoldHierarchy(v:count, 0)<Bar>execute "normal! \<lt>C-\>\<lt>C-n>\<lt>Esc>"<Bar>endif<CR>
nnoremap <silent> z/ :<C-u>if ! <SID>PrintFoldHierarchy(v:count, 1)<Bar>execute "normal! \<lt>C-\>\<lt>C-n>\<lt>Esc>"<Bar>endif<CR>
