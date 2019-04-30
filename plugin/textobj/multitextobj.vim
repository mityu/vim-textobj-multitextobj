scriptencoding utf-8
if exists('g:loaded_multitextobj')
  finish
endif
let g:loaded_multitextobj = 1

let s:save_cpo = &cpo
set cpo&vim


function! textobj#multitextobj#register_group(name)
	for range in ['a', 'i']
		let textobj = printf('<Plug>(textobj-multitextobj-%s-%s)',
\			a:name, range)
		let register = printf('<Plug>(textobj-multitextobj-register-%s-%s)', a:name, range)
		for mapping in ['omap', 'xmap']
			execute mapping textobj register . textobj
			execute mapping '<expr>' register
\				printf('textobj#multitextobj#register_group_impl(%s, %s)',
\				string(range), string(a:name))
		endfor
	endfor
endfunction

let g:textobj_multitextobj_debug = get(g:, "textobj_multitextobj_debug", 0)

let g:textobj_multitextobj_textobjects_i = get(g:, "textobj_multitextobj_textobjects_i", [])
let g:textobj_multitextobj_textobjects_a = get(g:, "textobj_multitextobj_textobjects_a", [])


let g:textobj_multitextobj_textobjects_group_i
\	= get(g:, "textobj_multitextobj_textobjects_group_i", {})

let g:textobj_multitextobj_textobjects_group_a
\	= get(g:, "textobj_multitextobj_textobjects_group_a", {})
let g:textobj_multitextobj_textobjects_group_list
\	= get(g:, "textobj_multitextobj_textobjects_group_list", [])


let s:textobj_dict = {
\      '-': {
\        'select-a': '',
\        'select-a-function': 'textobj#multitextobj#select_a',
\        'select-i': '',
\        'select-i-function': 'textobj#multitextobj#select_i',
\      },
\      'apply-prev': {
\        'select': '',
\        'select-function': 'textobj#multitextobj#apply_prev',
\      },
\      'apply-next': {
\        'select': '',
\        'select-function': 'textobj#multitextobj#apply_next',
\      },
\}

call textobj#user#plugin('multitextobj', s:textobj_dict)

for group_name in g:textobj_multitextobj_textobjects_group_list
	call textobj#multitextobj#register_group(group_name)
endfor

let &cpo = s:save_cpo
unlet s:save_cpo
