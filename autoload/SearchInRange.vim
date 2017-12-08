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
" Copyright: (C) 2008-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

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
function! s:IsSingleRange( lines )
    let l:lnums = keys(a:lines)
    let [l:minLnum, l:maxLnum] = [min(l:lnums), max(l:lnums)]
    return (! empty(a:lines) && len(l:lnums) == l:maxLnum - l:minLnum + 1)
endfunction
function! s:GetRangeMultiplicityName( lines )
    return (s:IsSingleRange(a:lines) ? 'range' : 'ranges')
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
"****D echomsg '****' l:startLnum l:endLnum string(sort(keys(l:lines), 'ingo#collections#numsort'))
    while l:count > 0 && l:message[0] !=# 'error'
	let [l:prevLnum, l:prevCol] = getpos('.')[1:2]

	if l:prevLnum < l:startLnum
	    call s:MoveToStart(l:startLnum)
	    let l:searchFlags = 'c'
	elseif l:prevLnum > l:endLnum
	    call s:MoveToEnd(l:endLnum)
	    let l:searchFlags = 'c'
	endif

	let l:lnum = search(@/, (a:isBackward ? 'b' : '') . l:searchFlags)
	let l:searchFlags = ''
	if l:lnum == 0
	    " No match, not even outside the range(s).
	    let l:message = ['error', 'Pattern not found: ' . @/]
	else
	    if ! a:isBackward && (l:lnum < l:startLnum || l:lnum > l:endLnum)
		" We moved outside the range, restart at start of range.
		call s:MoveToStart(l:startLnum)
		let l:lnum = search( @/, 'c' )

		if l:lnum > l:endLnum
		    " Only matches outside of range(s).
		    let l:message = ['error', 'Pattern not found in ' . s:GetRangeMessage() . ': ' . @/]
		else
		    if l:prevLnum > l:endLnum
			let l:message = ['wrap', 'skipping to TOP of ' . s:GetRangeMultiplicityName(l:lines)]
		    else
			let l:message = ['wrap', 'search hit BOTTOM of ' . s:GetRangeMultiplicityName(l:lines) . ', continuing at TOP']
		    endif
		endif
	    elseif a:isBackward && (l:lnum < l:startLnum || l:lnum > l:endLnum)
		" We moved outside the range(s), restart at end of range(s).
		call s:MoveToEnd(l:endLnum)
		let l:lnum = search( @/, 'bc' )

		if l:lnum < l:startLnum
		    " Only matches outside of range(s).
		    let l:message = ['error', 'Pattern not found in ' . s:GetRangeMessage() . ': ' . @/]
		else
		    if l:prevLnum < l:startLnum
			let l:message = ['wrap', 'skipping to BOTTOM of ' . s:GetRangeMultiplicityName(l:lines)]
		    else
			let l:message = ['wrap', 'search hit TOP of ' . s:GetRangeMultiplicityName(l:lines) . ', continuing at BOTTOM']
		    endif
		endif
	    elseif ! has_key(l:lines, l:lnum)
		" We moved outside a range, but still within the overall ranges.
		" Position to next / previous range start / end to avoid hitting
		" other intermediate matches not inside a range.
		if a:isBackward
		    let l:nextLnum = max(filter(keys(l:lines), 'str2nr(v:val) < l:lnum'))
		    call s:MoveToEnd(l:nextLnum)
		else
		    let l:nextLnum = min(filter(keys(l:lines), 'str2nr(v:val) > l:lnum'))
		    call s:MoveToStart(l:nextLnum)
		endif
		let l:searchFlags = 'c'

		let l:message = ['wrap', 'skipping to ' . (a:isBackward ? 'PREVIOUS' : 'NEXT') . ' range']

		continue
	    else
		" We're inside a range, check for movements from outside the
		" range(s) and for wrapping inside the range (which can lead to
		" here if all matches are inside the range).
		if l:prevLnum < l:startLnum || l:prevLnum > l:endLnum
		    let l:message = ['wrap', (a:isBackward ? 'skipping to BOTTOM of ' . s:GetRangeMultiplicityName(l:lines) . '' : 'skipping to TOP of ' . s:GetRangeMultiplicityName(l:lines))]
		elseif ! a:isBackward && l:lnum < l:prevLnum
		    let l:message = ['wrap', 'search hit BOTTOM, continuing at TOP']
		elseif a:isBackward && l:lnum > l:prevLnum
		    let l:message = ['wrap', 'search hit TOP, continuing at BOTTOM']
		endif
	    endif
	endif
	let l:count -= 1
    endwhile

    if l:message[0] ==# 'error'
	call ingo#err#Set('E486: ' . l:message[1])
	call cursor(l:prevLnum, l:prevCol)
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
    let [l:netStartLnum, l:netEndLnum] = [ingo#range#NetStart(a:startLnum), ingo#range#NetEnd(a:endLnum)]
    if empty(a:range)
	let l:range = (l:netStartLnum == l:netEndLnum ? l:netStartLnum : l:netStartLnum . ',' . l:netEndLnum)
	execute "call ingo#collections#unique#AddNew(" . a:variable . ", l:range)"
    else
	if a:startLnum != a:endLnum
	    " Ranges are given both before and after the command; add both.
	    execute "call ingo#collections#unique#AddNew(" . a:variable . ", l:netStartLnum . ',' . l:netEndLnum)"
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
	call histadd('search', escape(@/, '/'))
    endif

    " Integration into SearchRepeat.vim
    silent! call SearchRepeat#Set("\<Plug>(SearchInRangeNext)", "\<Plug>(SearchInRangePrev)", 2)

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
