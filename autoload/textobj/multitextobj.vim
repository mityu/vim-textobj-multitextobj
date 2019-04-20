scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim


let s:true = 1
let s:false = !s:true

function! s:uniq(list)
	return reverse(filter(reverse(a:list), "count(a:list, v:val) <= 1"))
endfunction


if !exists('s:apply_in_order')
	let s:apply_in_order = {}
	let s:apply_in_order.available = s:false
	let s:apply_in_order.region = []
	let s:apply_in_order.textobjects = []
	let s:apply_in_order.cursor_pos = []
endif
if !exists('s:added_groups')
	let s:added_groups = []
endif

let s:nullpos = [0, 0]
let s:t_string = type('')
let s:t_number = type(0)
let s:t_list = type([])
let s:t_dict = type({})


" a <= b
function! s:pos_less_equal(a, b)
	return a:a[0] == a:b[0] ? a:a[1] <= a:b[1] : a:a[0] <= a:b[0]
endfunction

" a == b
function! s:pos_equal(a, b)
	return a:a[0] == a:b[0] && a:a[1] == a:b[1]
endfunction

" a < b
function! s:pos_less(a, b)
	return a:a[0] == a:b[0] ? a:a[1] < a:b[1] : a:a[0] < a:b[0]
endfunction

" begin < pos && pos < end
function! s:is_in(range, pos)
	return type(a:pos) == s:t_list && type(get(a:pos, 0)) == s:t_list
\		 ? len(a:pos) == len(filter(copy(a:pos), "s:is_in(a:range, v:val)"))
\		 : s:pos_less(a:range[0], a:pos) && s:pos_less(a:pos, a:range[1])
endfunction

function! s:pos_next(pos)
	if a:pos == s:nullpos
		return a:pos
	endif
	let lnum = a:pos[0]
	let col  = a:pos[1]
	let line_size = len(getline(lnum))
	return [
\		line_size == col ? lnum + 1 : lnum,
\		line_size == col ? 1        : col + 1,
\	]
endfunction

function! s:pos_prev(pos)
	if a:pos == s:nullpos
		return a:pos
	endif
	let lnum = a:pos[0]
	let col  = a:pos[1]
	let line_size = len(getline(lnum))
	return [
\		line_size == 0 ? lnum-1               : lnum,
\		line_size == 0 ? len(getline(lnum-1)) : col - 1,
\	]
endfunction

function! s:region_equal(lhs, rhs)
	return a:lhs[0] ==# a:rhs[0] &&
				\s:pos_equal(a:lhs[1][1:2], a:rhs[1][1:2]) &&
				\s:pos_equal(a:lhs[2][1:2], a:rhs[2][1:2])
endfunction


function! s:as_config(config)
	let default = {
\		"textobj" : "",
\		"is_cursor_in" : 0,
\		"noremap" : 0,
\	}
	let config
\		= type(a:config) == s:t_string ? { "textobj" : a:config }
\		: type(a:config) == s:t_dict ? a:config
\		: {}
	return extend(default, config)
endfunction



let s:region = []
let s:wise = ""


function! textobj#multitextobj#apply_next()
	return s:get_region_with_another_textobj(s:true)
endfunction

function! textobj#multitextobj#apply_prev()
	return s:get_region_with_another_textobj(s:false)
endfunction

function! s:get_region()
	return [getpos("'[")[1:2], getpos("']")[1:2]]
endfunction

function! s:get_textobj_user_form_visual_region()
	return [visualmode()] + map(s:get_region(),'s:to_cursorpos(v:val)')
endfunction

function! textobj#multitextobj#can_apply_another()
	call s:check_whether_apply_another_is_available()
	return s:apply_in_order.available
endfunction

function! s:check_whether_apply_another_is_available()
	if !empty(s:apply_in_order.region) &&
			\ s:apply_in_order.region[0] ==# visualmode() &&
			\ s:region_equal(s:apply_in_order.region, s:get_textobj_user_form_visual_region())
		let s:apply_in_order.available = s:true
		return
	endif
	let s:apply_in_order.available = s:false
endfunction

function! textobj#multitextobj#region_operator(wise)
	let reg_save = @@
	let s:wise = a:wise
	let s:region = s:get_region()
	let @@ = reg_save
endfunction


nnoremap <silent> <Plug>(textobj-multitextobj-region-operator)
\	:<C-u>set operatorfunc=textobj#multitextobj#region_operator<CR>g@


function! textobj#multitextobj#region_from_textobj(textobj)
	let s:region = []
	let config = s:as_config(a:textobj)

	let pos = getpos(".")
	try
		silent execute (config.noremap ? 'onoremap' : 'omap') '<expr>'
\			'<Plug>(textobj-multitextobj-target)' string(config.textobj)

		let tmp = &operatorfunc
		silent execute "normal \<Plug>(textobj-multitextobj-region-operator)\<Plug>(textobj-multitextobj-target)"
		let &operatorfunc = tmp

		if !empty(s:region) && !s:pos_less_equal(s:region[0], s:region[1])
			return ["", []]
		endif
		if !empty(s:region) && config.is_cursor_in && (s:pos_less(pos[1:], s:region[0]) || s:pos_less(s:region[1], pos[1:]))
			return ["", []]
		endif
		return deepcopy([s:wise, s:region])
	finally
		call setpos(".", pos)
	endtry
endfunction

function! textobj#multitextobj#regex_from_region(first, last)
	if a:first == a:last
		return printf('\%%%dl\%%%dc', a:first[0], a:first[1])
	elseif a:first[0] == a:last[0]
		return printf('\%%%dl\%%>%dc\%%<%dc', a:first[0], a:first[1]-1, a:last[1]+1)
	elseif a:last[0] - a:first[0] == 1
		return  printf('\%%%dl\%%>%dc', a:first[0], a:first[1]-1)
\		. "\\|" . printf('\%%%dl\%%<%dc', a:last[0], a:last[1]+1)
	else
		return  printf('\%%%dl\%%>%dc', a:first[0], a:first[1]-1)
\		. "\\|" . printf('\%%>%dl\%%<%dl', a:first[0], a:last[0])
\		. "\\|" . printf('\%%%dl\%%<%dc', a:last[0], a:last[1]+1)
	endif
endfunction


function! textobj#multitextobj#highlight_from_textobj(textobj, match_group)
	match none
	let region = textobj#multitextobj#region_from_textobj(a:textobj)[1]
	if empty(region)
		return
	endif
	let regex = textobj#multitextobj#regex_from_region(region[0], region[1])
	execute printf("match %s /%s/", a:match_group, regex)
endfunction

function! s:to_cursorpos(pos)
	if a:pos == s:nullpos
		return [0, 0, 0, 0]
	endif
	return [0, a:pos[0], a:pos[1], 0]
endfunction


function! s:get_inner_region(textobjects)
	let regions = map(copy(a:textobjects), "textobj#multitextobj#region_from_textobj(v:val)")
	call filter(regions, "!empty(v:val[1])")
	let regions = filter(copy(regions), 'empty(filter(copy(regions), "s:is_in(".string(v:val[1]).", v:val[1])"))')
	let result = get(regions, 0, ["", []])
	if empty(result[1])
		return ["", []]
	endif
	return result
endfunction

function! s:get_textobj_user_form_region_from_textobj(textobj)
		if type(a:textobj) == s:t_list
			let [wise, region] = s:get_inner_region(a:textobj)
		else
			let [wise, region] = textobj#multitextobj#region_from_textobj(a:textobj)
		endif
		if empty(region)
			return []
		else
			return [wise == "line" ? "V" : "v",
						\s:to_cursorpos(region[0]),
						\s:to_cursorpos(region[1])]
		endif
endfunction

function! s:select(list_or_dict_name, group_name)
	let s:apply_in_order.textobjects =
				\deepcopy(s:textobjects(a:list_or_dict_name, a:group_name))
	let s:apply_in_order.cursor_pos = getpos('.')
	let s:apply_in_order.region = []
	return s:get_region_by_applying_textobjects_in_order(s:true) " Use next textobj
endfunction

function! s:get_region_with_another_textobj(use_next_textobj)
	if !textobj#multitextobj#can_apply_another()
		return 0
	endif

	let region_save = deepcopy(s:apply_in_order.region)
	call setpos('.', s:apply_in_order.cursor_pos)
	let new_region =
				\s:get_region_by_applying_textobjects_in_order(a:use_next_textobj)
	if type(new_region) == s:t_number
		call remove(s:apply_in_order,'region')
		let s:apply_in_order.region = deepcopy(region_save)
		return s:get_zero_if_empty(region_save)
	else
		return new_region
	endif
endfunction

function! s:get_region_by_applying_textobjects_in_order(use_next_textobj)
	let view = winsaveview()
	let region = []
	let applied = []
	let textobjects = s:apply_in_order.textobjects  " Use a reference.
	let found_region = s:false
	if !a:use_next_textobj
		call reverse(textobjects)
	endif
	while !empty(textobjects)
		call add(applied, remove(textobjects, 0))
		let textobj = applied[-1]

		let region = s:get_textobj_user_form_region_from_textobj(textobj)
		if !empty(region)
			" Continue to search another region if new region is same to previous
			" region (Only when apply-another).
			if empty(s:apply_in_order.region) ||
					\ !s:region_equal(s:apply_in_order.region, region) ||
					\ s:apply_in_order.region[0] !=# region[0]
				break
			endif
			let s:found_region = s:true
		endif
		unlet textobj
	endwhile
	call extend(textobjects, applied)
	if !a:use_next_textobj
		call reverse(textobjects)  " Restore the order.
	endif
	call winrestview(view)

	" When new region wasn't found after continue to search another region
	" above, I return the old region.
	if empty(region) && s:found_region
		return s:apply_in_order.region
	endif
	call remove(s:apply_in_order,'region')
	let s:apply_in_order.region = deepcopy(region)

	return s:get_zero_if_empty(region)
endfunction

function! s:get_zero_if_empty(list)
	if empty(a:list)
		return 0
	else
		return a:list
	endif
endfunction

function! s:textobjects_default(list_name)
	return s:uniq(get(b:, a:list_name, []) + get(g:, a:list_name, []))
endfunction

function! s:textobjects_group(dict_name, group_name)
	return s:uniq(
\		get(get(b:, a:dict_name, {}), a:group_name, [])
\	  + get(get(g:, a:dict_name, {}), a:group_name, [])
\	)
endfunction

function! s:textobjects(list_or_dict_name, group_name)
	if a:group_name ==# ''
		return s:textobjects_default(a:list_or_dict_name)
	else
		return s:textobjects_group(a:list_or_dict_name, a:group_name)
	endif
endfunction

function! textobj#multitextobj#register_group_impl(range_modifier, group_name)
	if index(s:added_groups, a:group_name) != -1
		return ''
	endif
	let dict_name = 'textobj_multitextobj_textobjects_group_' . a:range_modifier
	let function_name = printf('textobj#multitextobj#select_%s_%s',
\		a:range_modifier, a:group_name)
	let g:[function_name] = function('s:select', [dict_name, a:group_name])
	let specs = { '-': {} }
	let specs['-']['select-' . a:range_modifier] = ''
	let specs['-']['select-' . a:range_modifier . '-function'] = function_name
	call textobj#user#plugin(
\			'multitextobj' . a:group_name . a:range_modifier, specs)
	return ''
endfunction

function! textobj#multitextobj#select_a()
	return s:select('textobj_multitextobj_textobjects_a', '')
endfunction
function! textobj#multitextobj#select_i()
	return s:select('textobj_multitextobj_textobjects_i', '')
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
