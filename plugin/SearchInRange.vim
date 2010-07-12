" SearchInRange.vim: Limit search to range when jumping to the next search
" result. 
"
" DESCRIPTION:
" USAGE:
":[range]SearchInRange 	Search forward to the first occurrence of the current
"			search pattern inside [range]. Limit search to lines
"			inside [range] when jumping to the next search result. 
":[range]SearchInRange {pattern}
"			Search for {pattern}, starting with the first occurrence
"			inside [range]. Limit search to lines inside [range]
"			when jumping to the next search result. 
"{Visual}<Leader>/	Jump to the first occurrence of the current search
"			pattern inside selection. Limit search to lines inside
"			selection when jumping to the next search result. 
"<Leader>/{motion}	Use the moved-over lines as a range to limit searches
"			to. Jump to first occurrence of the current search
"			pattern inside the range. 
"
"   The special searches all start with 'go...' (mnemonic: "go once to special
"   match"); and come in search forward (ending with lowercase letter) and
"   search backward (uppercase letter) variants. 
"
" [count]gor / goR	Search forward / backward to the [count]'th occurrence
"			of the current search result in the previously specified
"			range. 
"
"   If the SearchRepeat plugin is installed, a parallel set of "go now and for
"   next searches" mappings (starting with 'gn...' instead of 'go...') is
"   installed. These mappings have the same effect, but in addition re-program
"   the 'n/N' keys to repeat this particular search (until another gn... search
"   is used). 
"
" INSTALLATION:
" DEPENDENCIES:
"   - EchoWithoutScrolling.vim autoload script. 
"   - SearchRepeat.vim autoload script (optional integration). 
"
" CONFIGURATION:
" INTEGRATION:
" LIMITATIONS:
" ASSUMPTIONS:
" KNOWN PROBLEMS:
" TODO:
"   - Optionally highlight range. 
"   - Make s:startLine a buffer variable. 
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS 
"	011	13-Jul-2010	ENH: Now handling [count]. 
"				BUG: Fixed mixed up "skipping to TOP/BOTTOM of
"				range" message when the search wraps around. 
"	010	13-Jul-2010	Refactored so that error / wrap / echo message
"				output is done at the end of the script, not
"				inside the logic. 
"				ENH: The search adds the original cursor
"				position to the jump list, like the built-in
"				[/?*#nN] commands. 
"	009	17-Aug-2009	BF: Checking for undefined range to avoid "E121:
"				Undefined variable: s:startLine". 
"	008	17-Aug-2009	Added a:description to SearchRepeat#Register(). 
"	007	29-May-2009	Added "go once" mappings that do not integrate
"				into SearchRepeat.vim. 
"	006	15-May-2009	BF: Translating line breaks in search pattern
"				via EchoWithoutScrolling#TranslateLineBreaks()
"				to avoid echoing only the last part of the
"				search pattern when it contains line breaks. 
"	005	06-May-2009	Added a:relatedCommands to
"				SearchRepeat#Register(). 
"	004	11-Feb-2009	Now setting v:warningmsg on warnings. 
"	003	03-Feb-2009	Added activation mapping to SearchRepeat
"				registration. 
"	002	16-Jan-2009	Now setting v:errmsg on errors. 
"	001	07-Aug-2008	file creation

" Avoid installing twice or when in unsupported Vim version. 
if exists('g:loaded_SearchInRange') || (v:version < 700)
    finish
endif
let g:loaded_SearchInRange = 1

"- functions ------------------------------------------------------------------
function! s:WrapMessage( message )
    if &shortmess !~# 's'
	echohl WarningMsg
	let v:warningmsg = a:message
	echomsg v:warningmsg
	echohl None
    else
	call EchoWithoutScrolling#Echo( ':' . s:startLine . ',' . s:endLine . '/' . EchoWithoutScrolling#TranslateLineBreaks(@/) )
    endif
endfunction
function! s:SearchErrorMessage( message )
    echohl ErrorMsg
    let v:errmsg = 'E486: ' . a:message
    echomsg v:errmsg
    echohl None
endfunction
function! s:NoRangeErrorMessage()
    echohl ErrorMsg
    let v:errmsg = 'Define range with :SearchInRange first!'
    echomsg v:errmsg
    echohl None
endfunction

function! s:MoveToRangeStart()
    call cursor(s:startLine, 1)
endfunction
function! s:MoveToRangeEnd()
    call cursor(s:endLine, 1)
    call cursor(s:endLine, col('$'))
endfunction
function! s:SearchInRange( isBackward )
    if ! exists('s:startLine')
	call s:NoRangeErrorMessage()
	return 0
    endif

    let l:count = v:count1
    let l:save_view = winsaveview()
    let l:message = ['echo', ':' . s:startLine . ',' . s:endLine . '/' . EchoWithoutScrolling#TranslateLineBreaks(@/)]

    while l:count > 0 && l:message[0] !=# 'error'
	let [l:prevLine, l:prevCol] = [line('.'), col('.')]

	if l:prevLine < s:startLine
	    call s:MoveToRangeStart()
	elseif l:prevLine > s:endLine
	    call s:MoveToRangeEnd()
	endif

	let l:line = search( @/, (a:isBackward ? 'b' : '') )
	if l:line == 0
	    " No match, not even outside the range. 
	    let l:message = ['error', 'Pattern not found: ' . @/]
	else
	    if ! a:isBackward && (l:line < s:startLine || l:line > s:endLine)
		" We moved outside the range, restart at start of range. 
		call s:MoveToRangeStart()
		let l:line = search( @/, '' )

		if l:line > s:endLine
		    " Only matches outside of range. 
		    let l:message = ['error', 'Pattern not found in range ' . s:startLine . ',' . s:endLine . ': ' . @/]
		else
		    if l:prevLine > s:endLine
			let l:message = ['wrap', 'skipping to TOP of range']
		    else
			let l:message = ['wrap', 'search hit BOTTOM of range, continuing at TOP']
		    endif
		endif
	    elseif a:isBackward && (l:line < s:startLine || l:line > s:endLine)
		" We moved outside the range, restart at end of range. 
		call s:MoveToRangeEnd()
		let l:line = search( @/, 'b' )

		if l:line < s:startLine
		    " Only matches outside of range. 
		    let l:message = ['error', 'Pattern not found in range ' . s:startLine . ',' . s:endLine . ': ' . @/]
		else
		    if l:prevLine < s:startLine
			let l:message = ['wrap', 'skipping to BOTTOM of range']
		    else
			let l:message = ['wrap', 'search hit TOP of range, continuing at BOTTOM']
		    endif
		endif
	    else
		" We're inside the range, check for movements from outside the range
		" and for wrapping inside the range (which can lead to here if all
		" matches are inside the range). 
		if l:prevLine < s:startLine || l:prevLine > s:endLine
		    let l:message = ['wrap', (a:isBackward ? 'skipping to BOTTOM of range' : 'skipping to TOP of range')]
		elseif ! a:isBackward && l:line < l:prevLine
		    let l:message = ['wrap', 'search hit BOTTOM, continuing at TOP']
		elseif a:isBackward && l:line > l:prevLine
		    let l:message = ['wrap', 'search hit TOP, continuing at BOTTOM']
		endif
	    endif
	endif
	let l:count -= 1
    endwhile

    if l:message[0] ==# 'error'
	call s:SearchErrorMessage(l:message[1])
	call cursor(l:prevLine, l:prevCol)
	return 0
    endif

    let l:matchPosition = getpos('.')

    " Open fold at the search result, like the built-in commands. 
    normal! zv

    " Add the original cursor position to the jump list, like the [/?*#nN]
    " commands. 
    " Implementation: Memorize the match position, restore the view to the state
    " before the search, then jump straight back to the match position. This
    " also allows us to set a jump only if a match was found. (:call
    " setpos("''", ...) doesn't work in Vim 7.2) 
    call winrestview(l:save_view)
    normal! m'
    call setpos('.', l:matchPosition)

    if l:message[0] ==# 'wrap'
	call s:WrapMessage(l:message[1])
    elseif l:message[0] ==# 'echo'
	call EchoWithoutScrolling#Echo(l:message[1])
    endif

    return 1
endfunction

"- commands -------------------------------------------------------------------
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


"- mappings -------------------------------------------------------------------
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

nmap <silent> gor <Plug>SearchInRangeNext
nmap <silent> goR <Plug>SearchInRangePrev


" Integration into SearchRepeat.vim
try
    " The user might have mapped these to something else; the only way to be
    " sure would be to grep the :map output. We just include the mapping if it's
    " the default one; the user could re-register, anyway. 
    let s:mapping = (exists('mapleader') ? mapleader : '\') . '/'
    let s:mapping = (maparg(s:mapping, 'n') ==# '<Plug>SearchInRangeOperator' ? s:mapping : '')

    call SearchRepeat#Register("\<Plug>SearchInRangeNext", s:mapping, 'gnr', '/range/', 'Search forward in range', ':[range]SearchInRange [{pattern}]')
    call SearchRepeat#Register("\<Plug>SearchInRangePrev", '', 'gnR', '?range?', 'Search backward in range', '')
    nnoremap <silent> gnr :<C-u>call SearchRepeat#Execute("\<Plug>SearchInRangeNext", "\<Plug>SearchInRangePrev", 2)<CR>
    nnoremap <silent> gnR :<C-u>call SearchRepeat#Execute("\<Plug>SearchInRangePrev", "\<Plug>SearchInRangeNext", 2)<CR>
catch /^Vim\%((\a\+)\)\=:E117/	" catch error E117: Unknown function
finally
    unlet! s:mapping
endtry

" vim: set sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
