" FooInRange.vim: Limit foo to range when jumping to the next foo result.
"
" DEPENDENCIES:
"   - ingo/avoidprompt.vim autoload script
"   - ingo/cmdargs/pattern.vim autoload script
"   - ingo/collections/unique.vim autoload script
"   - ingo/err.vim autoload script
"   - ingo/msg.vim autoload script
"   - ingo/range.vim autoload script
"   - FooRepeat.vim autoload script (optional integration)
"
" Copyright: (C) 2008-2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! s:MoveToStart( startLnum )
    call cursor(a:startLnum, 1)
endfunction
function! s:MoveToEnd( endLnum )
    call cursor(a:endLnum, 1)
    call cursor(a:endLnum, col('$'))
endfunction

function! FooInRange#FooInRange( isBackward )
"****D echomsg '****' l:startLnum l:endLnum string(sort(keys(l:lines), 'ingo#collections#numsort'))
    while l:count > 0 && l:message[0] !=# 'error'
	let l:fooFlags = ''
	if l:lnum == 0
	    " No match, not even outside the range(s).
	    let l:message = ['error', 'Pattern not found: ' . @/]
	endif
	let l:count -= 1
    endwhile

    " Open fold at the foo result, like the built-in commands.
    normal! zv

    " Add the original cursor position to the jump list, like the [/?*#nN]
    " commands.
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

" Implementation: Memorize the match position, restore the view to the state
" before the foo, then jump straight back to the match position. This
" also allows us to set a jump only if a match was found. (:call
" setpos("''", ...) doesn't work in Vim 7.2)

function! FooInRange#Include( startLnum, endLnum, range )
    if ! exists('b:FooInRange_Include')
	let b:FooInRange_Include = []
    endif
    call s:AddRange('b:FooInRange_Include', a:startLnum, a:endLnum, a:range)
    return 1
endfunction
function! FooInRange#Exclude( startLnum, endLnum, range )
    if ! exists('b:FooInRange_Exclude')
	let b:FooInRange_Exclude = []
    endif
    call s:AddRange('b:FooInRange_Exclude', a:startLnum, a:endLnum, a:range)
    return 1
endfunction
function! FooInRange#Clear()
    if ! exists('b:FooInRange_Include') && ! exists('b:FooInRange_Exclude')
	call ingo#err#Set('No ranges defined')
	return 0
    endif

    unlet! b:FooInRange_Include
    unlet! b:FooInRange_Exclude
    return 1
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=manual :
