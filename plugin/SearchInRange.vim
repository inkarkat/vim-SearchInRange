" SearchInRange.vim: Limit search to range when jumping to the next search result.
"
" DEPENDENCIES:
"   - SearchInRange.vim autoload script
"   - ingo/err.vim autoload script
"   - SearchRepeat.vim autoload script (optional integration)
"
" Copyright: (C) 2008-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

" Avoid installing twice or when in unsupported Vim version.
if exists('g:loaded_SearchInRange') || (v:version < 700)
    finish
endif
let g:loaded_SearchInRange = 1
let s:save_cpo = &cpo
set cpo&vim

"- commands -------------------------------------------------------------------

command! -nargs=? -range SearchInRange        if SearchInRange#SetAndSearchInRange(<line1>, <line2>, <q-args>) | if &hlsearch | set hlsearch | endif | else | echoerr ingo#err#Get() | endif
command! -nargs=? -range SearchInRangeInclude if ! SearchInRange#Include(<line1>, <line2>, <q-args>) | echoerr ingo#err#Get() | endif
command! -nargs=? -range SearchInRangeExclude if ! SearchInRange#Exclude(<line1>, <line2>, <q-args>) | echoerr ingo#err#Get() | endif
command! -bar            SearchInRangeClear   if ! SearchInRange#Clear() | echoerr ingo#err#Get() | endif


"- mappings -------------------------------------------------------------------

vnoremap <silent> <Plug>(SearchInRange) :SearchInRange<CR>
if ! hasmapto('<Plug>(SearchInRange)', 'x')
    xmap <Leader>n <Plug>(SearchInRange)
endif

nnoremap <expr> <Plug>(SearchInRangeOperator) SearchInRange#OperatorExpr()
if ! hasmapto('<Plug>(SearchInRangeOperator)', 'n')
    nmap <Leader>n <Plug>(SearchInRangeOperator)
endif

nnoremap <silent> <Plug>(SearchInRangeNext) :<C-u>if SearchInRange#SearchInRange(0)<Bar>if &hlsearch<Bar>set hlsearch<Bar>endif<Bar>else<Bar>echoerr ingo#err#Get()<Bar>endif<CR>
nnoremap <silent> <Plug>(SearchInRangePrev) :<C-u>if SearchInRange#SearchInRange(1)<Bar>if &hlsearch<Bar>set hlsearch<Bar>endif<Bar>else<Bar>echoerr ingo#err#Get()<Bar>endif<CR>

if ! hasmapto('<Plug>(SearchInRangeNext)', 'n')
    nmap gor <Plug>(SearchInRangeNext)
endif
if ! hasmapto('<Plug>(SearchInRangePrev)', 'n')
    nmap gOr <Plug>(SearchInRangePrev)
endif


"- Integration into SearchRepeat.vim -------------------------------------------

try
    " The user might have mapped these to something else; the only way to be
    " sure would be to grep the :map output. We just include the mapping if it's
    " the default one; the user could re-register, anyway.
    let s:mapping = (exists('mapleader') ? mapleader : '\') . '/'
    let s:mapping = (maparg(s:mapping, 'n') ==# '<Plug>(SearchInRangeOperator)' ? s:mapping : '')

    call SearchRepeat#Define(
    \   '<Plug>(SearchInRangeNext)', '<Plug>(SearchInRangePrev)',
    \   s:mapping, 'r', 'range', 'Search in range', ':[range]SearchInRange [/][{pattern}][/]',
    \   2
    \)
catch /^Vim\%((\a\+)\)\=:E117:/	" catch error E117: Unknown function
finally
    unlet! s:mapping
endtry

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
