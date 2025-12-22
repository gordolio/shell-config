" Vim syntax file
" Language:	JSONL (JSON Lines / newline-delimited JSON)
" Maintainer:	Gordon
" Last Change:	2025-10-14
" Version:      0.1
"
" JSONL is just JSON objects separated by newlines
" We can use the JSON syntax highlighting for each line

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" Source the JSON syntax file
runtime! syntax/json.vim
unlet b:current_syntax

let b:current_syntax = "jsonl"

" Vim settings
" vim: ts=8 fdm=marker
