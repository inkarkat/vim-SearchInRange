" SearchInRange.vim: Limit search to range when jumping to the next search
" result. 
"
" DESCRIPTION:
" USAGE:
":[range]SearchInRange 	Jump to first occurrence of the current search pattern
"			inside [range]. Limit search to lines inside [range]
"			when jumping to the next search result. 
":[range]SearchInRange <pattern>
"			Search for <pattern>, starting with the first occurrence
"			inside [range]. Limit search to lines inside [range]
"			when jumping to the next search result. 
"{Visual}<Leader>/	Jump to first occurrence of the current search pattern
"			inside selection. Limit search to lines inside selection
"			when jumping to the next search result. 
"<Leader>/{motion}	Use the moved-over lines as a range to limit searches
"			to. Jump to first occurrence of the current search
"			pattern inside the range. 
"
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
"   - Handle [count]. 
"   - Optionally highlight range. 
"   - Check for existence of s:startLine. 
"   - Make s:startLine buffer / window -variable. 
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS 
"	002	16-Jan-2009	Now setting v:errmsg on errors. 
"	001	07-Aug-2008	file creation

" Avoid installing twice or when in unsupported VIM version. 
if exists('g:loaded_SearchInRange') || (v:version < 700)
    finish
endif
let g:loaded_SearchInRange = 1

function! s:WrapMessage( message )
    if &shortmess !~# 's'
	echohl WarningMsg
	echomsg a:message
	echohl NONE
    else
	call EchoWithoutScrolling#Echo( ':' . s:startLine . ',' . s:endLine . '/' . @/ )
    endif
endfunction
function! s:SearchErrorMessage( message )
    echohl ErrorMsg
    let v:errmsg = 'E486: ' . a:message
    echomsg v:errmsg
    echohl NONE
endfunction

function! s:MoveToRangeStart()
    call cursor(s:startLine, 1)
endfunction
function! s:MoveToRangeEnd()
    call cursor(s:endLine, 1)
    call cursor(s:endLine, col('$'))
endfunction
function! s:SearchInRange( isBackward )
    let l:prevLine = line('.')
    let l:prevCol = col('.')

    if l:prevLine < s:startLine
	call s:MoveToRangeStart()
    elseif l:prevLine > s:endLine
	call s:MoveToRangeEnd()
    endif

    let l:searchError = ''
    let l:line = search( @/, (a:isBackward ? 'b' : '') )
    if l:line == 0
	" No match, not even outside the range. 
	let l:searchError = 'Pattern not found: ' . @/
    else
	if ! a:isBackward && (l:line < s:startLine || l:line > s:endLine)
	    " We moved outside the range, restart at start of range. 
	    call s:MoveToRangeStart()
	    let l:line = search( @/, '' )

	    if l:line > s:endLine
		" Only matches outside of range. 
		let l:searchError = 'Pattern not found in range ' . s:startLine . ',' . s:endLine . ': ' . @/
	    else
		if l:prevLine > s:endLine
		    call s:WrapMessage('skipping to TOP of range')
		else
		    call s:WrapMessage('search hit BOTTOM of range, continuing at TOP')
		endif
	    endif
	elseif a:isBackward && (l:line < s:startLine || l:line > s:endLine)
	    " We moved outside the range, restart at end of range. 
	    call s:MoveToRangeEnd()
	    let l:line = search( @/, 'b' )

	    if l:line < s:startLine
		" Only matches outside of range. 
		let s:searchError = 'Pattern not found in range ' . s:startLine . ',' . s:endLine . ': ' . @/
	    else
		if l:prevLine < s:startLine
		    call s:WrapMessage('skipping to BOTTOM of range')
		else
		    call s:WrapMessage('search hit TOP of range, continuing at BOTTOM')
		endif
	    endif
	else
	    " We're inside the range, check for movements from outside the range
	    " and for wrapping inside the range (which can lead to here if all
	    " matches are inside the range). 
	    if l:prevLine < s:startLine
		call s:WrapMessage('skipping to TOP of range')
	    elseif l:prevLine > s:endLine
		call s:WrapMessage('skipping to BOTTOM of range')
	    elseif ! a:isBackward && l:line < l:prevLine
		call s:WrapMessage('search hit BOTTOM, continuing at TOP')
	    elseif a:isBackward && l:line > l:prevLine
		call s:WrapMessage('search hit TOP, continuing at BOTTOM')
	    else
		call EchoWithoutScrolling#Echo( ':' . s:startLine . ',' . s:endLine . '/' . @/ )
	    endif
	endif
    endif

    if ! empty(l:searchError)
	call s:SearchErrorMessage(l:searchError)
	call cursor(l:prevLine, l:prevCol)
	return 0
    else
	" Note: When typed, [*#nN] open the fold at the search result, but inside a
	" mapping or :normal this must be done explicitly via 'zv'. 
	normal! zv
	return 1
    endif
endfunction

function! s:SetAndSearchInRange( startLine, endLine, pattern )
    let s:startLine = a:startLine
    let s:endLine = a:endLine
    if ! empty(a:pattern)
	let @/ = a:pattern
    endif

    " Integration into SearchRepeat.vim
    silent! call SearchRepeat#Set("\<Plug>SearchInRangeNext", "\<Plug>SearchInRangePrev", 2)<CR>

    return s:SearchInRange(0)
endfunction
command! -nargs=? -range SearchInRange if <SID>SetAndSearchInRange(<line1>,<line2>,<q-args>) && &hlsearch|set hlsearch|endif


vnoremap <Plug>SearchInRange :SearchInRange<CR>
if ! hasmapto('<Plug>SearchInRange', 'v')
    vmap <silent> <Leader>/ <Plug>SearchInRange
endif


function! s:SearchInRangeOperator( type )
    call s:SetAndSearchInRange(line("'["), line("']"), '')
endfunction
nnoremap <Plug>SearchInRangeOperator :set opfunc=<SID>SearchInRangeOperator<CR>g@
if ! hasmapto('<Plug>SearchInRangeOperator', 'n')
    nmap <silent> <Leader>/ <Plug>SearchInRangeOperator
endif


nnoremap <silent> <Plug>SearchInRangeNext :<C-u>if <SID>SearchInRange(0) && &hlsearch<Bar>set hlsearch<Bar>endif<CR>
nnoremap <silent> <Plug>SearchInRangePrev :<C-u>if <SID>SearchInRange(1) && &hlsearch<Bar>set hlsearch<Bar>endif<CR>

" Integration into SearchRepeat.vim
" gnr / gnR		Go next search result in range. 
try
    call SearchRepeat#Register("\<Plug>SearchInRangeNext", '', 'gnr', 'Search forward in range')
    call SearchRepeat#Register("\<Plug>SearchInRangePrev", '', 'gnR', 'Search backward in range')
    nnoremap <silent> gnr :<C-u>call SearchRepeat#Execute("\<Plug>SearchInRangeNext", "\<Plug>SearchInRangePrev", 0)<CR>
    nnoremap <silent> gnR :<C-u>call SearchRepeat#Execute("\<Plug>SearchInRangePrev", "\<Plug>SearchInRangeNext", 0)<CR>
catch /^Vim\%((\a\+)\)\=:E117/	" catch error E117: Unknown function
endtry

" vim: set sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
