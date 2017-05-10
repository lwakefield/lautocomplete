let s:wordcache = {}
let s:wordstart = 0
let s:currword = ''
let s:available_snippets = []
let s:timer = -1

fun! lautocomplete#init()
    augroup autocomp
        autocmd!
        autocmd TextChangedI * call s:async_comp()

        autocmd BufEnter * call s:cache_words()
        autocmd TextChanged * call s:cache_words()
        autocmd InsertLeave * call s:cache_words()

        autocmd CompleteDone * call s:maybe_expand_snippet()
    augroup end
endfun

fun! s:async_comp()
    let line = getline('.')
    let end = col('.')
    let s:start = end - 1
    while s:start > 0 && line[s:start - 1] =~ '\w'
        let s:start -= 1
    endwhile

    let s:currword = strpart(line, s:start, end - s:start - 1)
    if s:currword == ''
        return
    end

    fun! Receieve(job_id, data, event)
        call complete(s:start + 1, s:available_snippets + a:data)
    endfun

    let s:available_snippets = s:get_snippets()
    let words = join(map(values(s:wordcache), {k, v -> join(v, '\\n')}), '\\n')
    call jobstart('echo "'.words.'" | fzy -e '.s:currword, {'on_stdout': 'Receieve'})
endfun

fun! s:maybe_expand_snippet()
    let completed = v:completed_item
    if completed != {} && completed.kind == '<snippet>'
        call feedkeys("\<BS>")
        call UltiSnips#ExpandSnippet()
    endif
endfun

fun! s:get_snippets()
    let snippets = UltiSnips#SnippetsInCurrentScope()
    let filtered = filter(snippets, {k, v -> k =~ '^'.s:currword})
    return values(map(filtered, {k, v -> {'word': k, 'menu': v, 'kind': '<snippet>'}}))
endfun

fun! s:cache_words()
    let bufnr = bufnr('%')
    let s:wordcache[bufnr] = s:get_words(getbufline(bufnr, 1, '$'))
endfun

fun! s:get_words(lines)
    let word_map = {}
    for line in a:lines
        for word in split(line, '\W\+')
            let word_map[word] = 1
        endfor
    endfor
    return keys(word_map)
endfun
