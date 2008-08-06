" SearchInRange.vim: Limit search to range when jumping to the next search
" result. 
"
" DESCRIPTION:
" USAGE:
" INSTALLATION:
" DEPENDENCIES:
"   - EchoWithoutScrolling.vim autoload script. 
"   - SearchRepeat.vim (optional integration)
"
" CONFIGURATION:
" INTEGRATION:
" LIMITATIONS:
" ASSUMPTIONS:
" KNOWN PROBLEMS:
" TODO:
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS 
"	001	07-Aug-2008	file creation

" Avoid installing twice or when in unsupported VIM version. 
if exists('g:loaded_SearchInRange') || v:version < 700
    finish
endif
let g:loaded_SearchInRange = 1

function! s:WrapMessage( message )
    echohl WarningMsg
    echomsg a:message
    echohl NONE
endfunction
function! s:SearchErrorMessage( message )
    echohl ErrorMsg
    echomsg 'E486:' a:message
    echohl NONE
endfunction

function! s:SearchInRange( isBackward )
    let l:prevLine = line('.')
    let l:prevCol = col('.')

    if l:prevLine < s:startLine
	call cursor(s:startLine, 1)
    elseif l:prevLine > s:endLine
	call cursor(s:endLine, 1)
	call cursor(s:endLine, col('$'))
    endif

    let l:isFoundMatch = 0
    let l:line = search( @/, (a:isBackward ? 'b' : '') )
    if l:line == 0
	call s:SearchErrorMessage( 'Pattern not found: ' . @/ )
	call cursor(l:prevLine, l:prevCol)
	return 0
    else
	if ! a:isBackward && l:line > s:endLine
	    call cursor(s:startLine, 1)
	    let l:line = search( @/, '' )
	    if l:line > s:endLine
		call s:SearchErrorMessage( 'Pattern not found in range ' . s:startLine . ',' . s:endLine . ': ' . @/ )
		call cursor(l:prevLine, l:prevCol)
		return 0
	    else
		if l:prevLine > s:endLine
		    call s:WrapMessage('skipping to TOP of range')
		else
		    call s:WrapMessage('search hit BOTTOM of range, continuing at TOP')
		endif
	    endif
	    return 1
	elseif a:isBackward && l:line < s:startLine
	    call cursor(s:endLine, 1)
	    call cursor(s:endLine, col('$'))
	    let l:line = search( @/, 'b' )
	    if l:line < s:startLine
		call s:SearchErrorMessage( 'Pattern not found in range ' . s:startLine . ',' . s:endLine . ': ' . @/ )
		call cursor(l:prevLine, l:prevCol)
		return 0
	    else
		if l:prevLine < s:startLine
		    call s:WrapMessage('skipping to BOTTOM of range')
		else
		    call s:WrapMessage('search hit TOP of range, continuing at BOTTOM')
		endif
	    endif
	    return 1
	else
	    if l:prevLine < s:startLine
		call s:WrapMessage('skipping to TOP of range')
	    elseif l:prevLine > s:endLine
		call s:WrapMessage('skipping to BOTTOM of range')
	    else
		call EchoWithoutScrolling#Echo( s:startLine . ',' . s:endLine . '/' . @/ )
	    endif
	endif
	return 1
    endif

    call s:SearchErrorMessage( 'Pattern not found: ' . @/ )
    return 0
endfunction


function! s:SetRange( startLine, endLine, pattern )
    let s:startLine = a:startLine
    let s:endLine = a:endLine
    if ! empty(a:pattern)
	let @/ = a:pattern
    endif
endfunction

command! -nargs=? -range SearchInRange call <SID>SetRange(<line1>,<line2>,<q-args>)

nnoremap <silent> <Plug>SearchInRangeNext :<C-u>if <SID>SearchInRange(0) && &hlsearch<Bar>set hlsearch<Bar>endif<CR>
nnoremap <silent> <Plug>SearchInRangePrev :<C-u>if <SID>SearchInRange(1) && &hlsearch<Bar>set hlsearch<Bar>endif<CR>

" Integration into SearchRepeat.vim
" gnr / gnR		Go next search result in range. 
try
    call SearchRepeat#Register("\<Plug>SearchInRangeNext", '', 'gnr', 'Search forward in range')
    call SearchRepeat#Register("\<Plug>SearchInRangePrev", '', 'gnR', 'Search backward in range')
    nnoremap <silent> gnr :<C-u>call SearchRepeat#Execute("\<Plug>SearchInRangeNext", "\<Plug>SearchInRangePrev", 2)<CR>
    nnoremap <silent> gnR :<C-u>call SearchRepeat#Execute("\<Plug>SearchInRangePrev", "\<Plug>SearchInRangeNext", 2)<CR>
catch /^Vim\%((\a\+)\)\=:E117/	" catch error E117: Unknown function
endtry

" vim: set sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
