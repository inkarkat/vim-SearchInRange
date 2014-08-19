" SearchInRange.vim: Limit search to range when jumping to the next search result.
"
" DEPENDENCIES:
"   - ingo/avoidprompt.vim autoload script
"   - ingo/cmdargs/pattern.vim autoload script
"   - ingo/collections/unique.vim autoload script
"   - ingo/err.vim autoload script
"   - ingo/msg.vim autoload script
"   - ingo/range.vim autoload script
"   - SearchRepeat.vim autoload script (optional integration)
"
" Copyright: (C) 2008-2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   2.00.020	08-Aug-2014	Change b:startLine + b:endLine to
"				b:SearchInRange_Include and b:SearchInRange_Exclude.
"				Add SearchInRange#Include(),
"				SearchInRange#Exclude(), SearchInRange#Clear().
"				FIX: When moving to start / end of range, must
"				use "c" search flag to avoid skipping a match
"				directly at the border.
"				FIX: Need to explicitly account for closed folds
"				in the range passed to
"				SearchInRange#SetAndSearchInRange().
"   1.00.019	29-May-2014	Use
"				ingo#cmdargs#pattern#ParseUnescapedWithLiteralWholeWord()
"				to also allow :[range]SearchInRange /{pattern}/
"				argument syntax with literal whole word search.
"	018	26-May-2014	Adapt <Plug>-mapping naming.
"	017	26-Apr-2014	Split off autoload script.
"				Use ingo#err#Set() to abort on errors.
"   	016	07-Jun-2013	Move EchoWithoutScrolling.vim into ingo-library.
"				Use ingo#msg#WarningMsg().
"	015	24-May-2013	Change <Leader>/ to <Leader>n; / implies
"				entering a new pattern, whereas n is related to
"				the last search pattern, also in [n.
"	014	24-Jun-2012	Don't define the <Leader>/ default mapping in
"				select mode, just visual mode.
"	013	14-Mar-2012	Split off documentation.
"	012	30-Sep-2011	Use <silent> for <Plug> mapping instead of
"				default mapping.
"	011	13-Jul-2010	ENH: Now handling [count].
"				BUG: Fixed mixed up "skipping to TOP/BOTTOM of
"				range" message when the search wraps around.
"				Make s:startLine a buffer variable, so that the
"				range is remembered for each buffer separately.
"				(Linking this to the window doesn't make sense,
"				as the fixed range probably won't apply to a
"				different buffer shown in the same window, and
"				one can easily re-set the range for any new
"				buffer.)
"	010	13-Jul-2010	Refactored so that error / wrap / echo message
"				output is done at the end of the script, not
"				inside the logic.
"				ENH: The search adds the original cursor
"				position to the jump list, like the built-in
"				[/?*#nN] commands.
"	009	17-Aug-2009	BF: Checking for undefined range to avoid "E121:
"				Undefined variable: b:startLine".
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

function! s:DetermineSearchedLines()
    let l:didClobberSearchHistory = 0
    let l:lines = {}

    if ! exists('b:SearchInRange_Include') || empty(b:SearchInRange_Include)
	if ! exists('b:SearchInRange_Exclude') || empty(b:SearchInRange_Exclude)
	    throw 'No ranges defined'
	endif

	" Initialize with all lines in the buffer.
	let l:lines = ingo#collections#ToDict(range(1, line('$')))
    else
	for l:range in b:SearchInRange_Include
	    let [l:recordedLines, l:startLines, l:endLines, l:isClobberSearchHistory] = ingo#range#lines#Get(1, line('$'), l:range)
	    let l:didClobberSearchHistory = l:didClobberSearchHistory || l:isClobberSearchHistory

	    call extend(l:lines, l:recordedLines, 'keep')
	endfor
    endif
    if exists('b:SearchInRange_Exclude') && ! empty(b:SearchInRange_Exclude)
	for l:range in b:SearchInRange_Exclude
	    let [l:recordedLines, l:startLines, l:endLines, l:isClobberSearchHistory] = ingo#range#lines#Get(1, line('$'), l:range)
	    let l:didClobberSearchHistory = l:didClobberSearchHistory || l:isClobberSearchHistory

	    for l:lnum in keys(l:recordedLines)
		call remove(l:lines, l:lnum)
	    endfor
	endfor
    endif

    if l:didClobberSearchHistory
	call histdel('search', -1)
    endif

    return l:lines
endfunction

function! s:WrapMessage( rangeMessage, message )
    if &shortmess !~# 's'
	call ingo#msg#WarningMsg(a:message)
    else
	call ingo#avoidprompt#EchoAsSingleLine(':' . a:rangeMessage . '/' . @/)
    endif
endfunction

function! s:MoveToStart( startLnum )
    call cursor(a:startLnum, 1)
endfunction
function! s:MoveToEnd( endLnum )
    call cursor(a:endLnum, 1)
    call cursor(a:endLnum, col('$'))
endfunction
function! s:GetRangeMessage()
    let l:hasInclude = (exists('b:SearchInRange_Include') && ! empty(b:SearchInRange_Include))
    let l:hasExclude = (exists('b:SearchInRange_Exclude') && ! empty(b:SearchInRange_Exclude))
    let l:message = (l:hasInclude ? join(b:SearchInRange_Include, ' and ') : '%')
    let l:message .= (l:hasExclude ? ' without ' . join(b:SearchInRange_Exclude, ' and ') : '')
    return l:message
endfunction
function! SearchInRange#SearchInRange( isBackward )
    if ! exists('b:SearchInRange_Include') && ! exists('b:SearchInRange_Exclude')
	call ingo#err#Set('Define range with :SearchInRange, :SearchInRangeInclude, or :SearchInRangeExclude first!')
	return 0
    endif

    let l:count = v:count1
    let l:save_view = winsaveview()
	let l:lines = s:DetermineSearchedLines()
    call winrestview(l:save_view)
    let l:startLnum = min(keys(l:lines))
    let l:endLnum = max(keys(l:lines))

    let l:message = ['echo', ':' . s:GetRangeMessage() . '/' . ingo#avoidprompt#TranslateLineBreaks(@/)]
    let l:searchFlags = ''
echomsg '****' l:startLnum l:endLnum string(sort(keys(l:lines), 'ingo#collections#numsort'))
    while l:count > 0 && l:message[0] !=# 'error'
	let [l:prevLine, l:prevCol] = [line('.'), col('.')]

	if l:prevLine < l:startLnum
	    call s:MoveToStart(l:startLnum)
	    let l:searchFlags = 'c'
	elseif l:prevLine > l:endLnum
	    call s:MoveToEnd(l:endLnum)
	    let l:searchFlags = 'c'
	endif

	let l:line = search(@/, (a:isBackward ? 'b' : '') . l:searchFlags)
	let l:searchFlags = ''
	if l:line == 0
	    " No match, not even outside the range.
	    let l:message = ['error', 'Pattern not found: ' . @/]
	else
	    if ! a:isBackward && (l:line < l:startLnum || l:line > l:endLnum)
		" We moved outside the range, restart at start of range.
		call s:MoveToStart(l:startLnum)
		let l:line = search( @/, '' )

		if l:line > l:endLnum
		    " Only matches outside of range.
		    let l:message = ['error', 'Pattern not found in ' . s:GetRangeMessage() . ': ' . @/]
		else
		    if l:prevLine > l:endLnum
			let l:message = ['wrap', 'skipping to TOP of range(s)']
		    else
			let l:message = ['wrap', 'search hit BOTTOM of range(s), continuing at TOP']
		    endif
		endif
	    elseif a:isBackward && (l:line < l:startLnum || l:line > l:endLnum)
		" We moved outside the range, restart at end of range.
		call s:MoveToEnd(l:endLnum)
		let l:line = search( @/, 'b' )

		if l:line < l:startLnum
		    " Only matches outside of range.
		    let l:message = ['error', 'Pattern not found in ' . s:GetRangeMessage() . ': ' . @/]
		else
		    if l:prevLine < l:startLnum
			let l:message = ['wrap', 'skipping to BOTTOM of range(s)']
		    else
			let l:message = ['wrap', 'search hit TOP of range(s), continuing at BOTTOM']
		    endif
		endif
	    else
		" We're inside a range, check for movements from outside the
		" range(s) and for wrapping inside the range (which can lead to
		" here if all matches are inside the range).
		if l:prevLine < l:startLnum || l:prevLine > l:endLnum
		    let l:message = ['wrap', (a:isBackward ? 'skipping to BOTTOM of range(s)' : 'skipping to TOP of range(s)')]
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
	call ingo#err#Set('E486: ' . l:message[1])
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
	call s:WrapMessage(s:GetRangeMessage(), l:message[1])
    elseif l:message[0] ==# 'echo'
	call ingo#avoidprompt#Echo(l:message[1])
    endif

    return 1
endfunction


function! s:AddRange( variable, startLnum, endLnum, range )
    if empty(a:range)
	let l:range = (a:startLnum == a:endLnum ? a:startLnum : a:startLnum . ',' . a:endLnum)
	execute "call ingo#collections#unique#AddNew(" . a:variable . ", l:range)"
    else
	if a:startLnum != a:endLnum
	    " Ranges are given both before and after the command; add both.
	    execute "call ingo#collections#unique#AddNew(" . a:variable . ", a:startLnum . ',' . a:endLnum)"
	endif
	execute "call ingo#collections#unique#AddNew(" . a:variable . ", a:range)"
    endif
endfunction
function! SearchInRange#Include( startLnum, endLnum, range )
    if ! exists('b:SearchInRange_Include')
	let b:SearchInRange_Include = []
    endif
    call s:AddRange('b:SearchInRange_Include', a:startLnum, a:endLnum, a:range)
    return 1
endfunction
function! SearchInRange#Exclude( startLnum, endLnum, range )
    if ! exists('b:SearchInRange_Exclude')
	let b:SearchInRange_Exclude = []
    endif
    call s:AddRange('b:SearchInRange_Exclude', a:startLnum, a:endLnum, a:range)
    return 1
endfunction
function! SearchInRange#Clear()
    if ! exists('b:SearchInRange_Include') && ! exists('b:SearchInRange_Exclude')
	call ingo#err#Set('No ranges defined')
	return 0
    endif

    unlet! b:SearchInRange_Include
    unlet! b:SearchInRange_Exclude
    return 1
endfunction
function! SearchInRange#SetAndSearchInRange( startLnum, endLnum, pattern )
    let l:pattern = ingo#cmdargs#pattern#ParseUnescapedWithLiteralWholeWord(a:pattern)

    let b:SearchInRange_Include = [ingo#range#NetStart(a:startLnum) . ',' . ingo#range#NetEnd(a:endLnum)]
    unlet! b:SearchInRange_Exclude

    if ! empty(l:pattern)
	let @/ = l:pattern
    endif

    " Integration into SearchRepeat.vim
    silent! call SearchRepeat#Set("\<Plug>(SearchInRangeNext)", "\<Plug>(SearchInRangePrev)", 2)<CR>

    return SearchInRange#SearchInRange(0)
endfunction


function! SearchInRange#Operator( type )
    call SearchInRange#SetAndSearchInRange(line("'["), line("']"), '')
endfunction
function! SearchInRange#OperatorExpr()
    set opfunc=SearchInRange#Operator
    return 'g@'
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
