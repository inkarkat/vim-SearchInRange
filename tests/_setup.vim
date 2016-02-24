runtime plugin/SearchInRange.vim

function! s:MarkCol( text, col )
    return substitute(a:text, '\%' . a:col . 'c.', '[\0]', '')
endfunction
function! TestMotionSequence( startPos, motionMapping, cursorPoints, description )
    call cursor(a:startPos)

    let l:prevPos = getpos('.')[1:2]
    for l:cnt in range(len(a:cursorPoints))
	execute 'normal' a:motionMapping
	let l:currentPos = getpos('.')[1:2]
	if l:currentPos == l:prevPos
	    call vimtap#Fail('cursor did not move: ' . string(l:currentPos))
	    return
	endif
	let l:prevPos = l:currentPos

	let l:description = printf('%s over %s, motion #%d', a:motionMapping, a:description, l:cnt + 1)
	let l:point = a:cursorPoints[l:cnt]
	if l:currentPos == l:point
	    call vimtap#Pass(l:description)
	else
	    let l:diag =
	    \   printf('expected cursor in col %d: %s', l:point[1],      s:MarkCol(getline(l:point[0])     , l:point[1])) . "\n" .
	    \   printf('but cursor was  in col %d: %s', l:currentPos[1], s:MarkCol(getline(l:currentPos[0]), l:currentPos[1]))
	    if l:currentPos[0] != l:point[0]
		let l:diag .= printf("\nof line %d rather than %d", l:currentPos[0], l:point[0])
	    endif

	    call vimtap#Fail(l:description)
	    call vimtap#Diag("Test '" . strtrans(l:description) . "' failed:\n" . l:diag)

	    break   " Doesn't make sense to continue with a wrong position.
	endif
    endfor
endfunction
