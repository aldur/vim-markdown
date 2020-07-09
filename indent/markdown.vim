" Only load this indent file when no other was loaded.
" if exists('b:did_indent') | finish | endif
" let b:did_indent = 1

setlocal indentexpr=GetMarkdownIndent(v:lnum)
setlocal indentkeys=0<:>,0=*,0=-,0=+,!^F,o,O
setlocal nolisp
setlocal autoindent

" Automatically continue blockquote on line break
setlocal formatoptions+=r
setlocal comments=b:>
if get(g:, 'vim_markdown_auto_insert_bullets', 1)
    " Do not automatically insert bullets when auto-wrapping with text-width
    setlocal formatoptions-=c
    " Accept various markers as bullets
    setlocal comments+=b:*,b:+,b:-
endif

let b:undo_indent = 'setlocal indentexpr< indentkeys< lisp< autoindent< formatoptions< comments<'

" Only define the function once.
" if exists('*GetMarkdownIndent') | finish | endif

function! s:IsMkdCode(lnum) abort
    let name = synIDattr(synID(a:lnum, 1, 0), 'name')
    return (name =~# '^mkd\%(Code$\|Snippet\)' || name !=# '' && name !~# '^\%(mkd\|html\)')
endfunction

let s:whitespace_re = '^\s*$'
let s:unorder_list_re = '^\s*[*+-] \+'
let s:order_list_re = '^\s*\d\. \+'
let s:quote_re = '^\s*>\+ \+'

function! s:IsLiStart(line) abort
    return a:line !~# '^ *\([*-]\)\%( *\1\)\{2}\%( \|\1\)*$' &&
      \ (
      \         a:line =~# s:unorder_list_re ||
      \         a:line =~# s:order_list_re ||
      \         a:line =~# s:quote_re
      \ )
endfunction

function! GetMarkdownIndent(lnum) abort
    let current_line = getline(a:lnum)
    let past_line = a:lnum  - 1

    " Indent after :tags in frontmatter
    if getline(past_line) ==# 'tags:' && current_line =~# '^\s*:'
        " Here I could even dynamically load the YAML indent,
        " but it seems overkill.
        return shiftwidth()
    endif

    " Reindent when pressing [*+-]
    if current_line =~# '^\s*[*+-]' " Look above for where's the previous list item and blank line
        let previous_list_item_n = search(s:unorder_list_re, 'Wbn')
        let previous_empty_n = search(s:whitespace_re, 'Wbn')

        " We have a list item right above, without empty lines in the middle
        if previous_list_item_n > previous_empty_n
            " Align to the previous list item.
            return indent(previous_list_item_n)
        endif
    endif

    " A blank line resets indentation to 0.
    " A fenced code or quote block nested under a list item makes an exception.
    if empty(getline(past_line))
                \ && current_line !~# '^\s\+```'
                \ && current_line !~# '^\s\+> '
        return 0
    endif

    " Find a non-blank line above the current line.
    let last_non_blank_n = prevnonblank(a:lnum - 1)

    " At the start of the file use zero indent.
    if last_non_blank_n == 0 | return 0 | endif

    let last_indent = indent(last_non_blank_n)
    let last_non_blank = getline(last_non_blank_n)

    if s:IsLiStart(current_line)
        " Current line is the first line of a list item, do not change indent
        return indent(a:lnum)
    elseif current_line =~# '^\s*#\+ ' && !s:IsMkdCode(a:lnum)
        " Current line is a header, do not indent
        return 0
    elseif s:IsLiStart(last_non_blank)
        if s:IsMkdCode(last_non_blank_n)
            return last_indent
        endif

        " Last line is the first line of a list item that has a paragraph.
        return last_indent + shiftwidth()
    endif

    return last_indent
endfunction
