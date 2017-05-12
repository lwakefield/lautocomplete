let s:wordcache = {}
let s:wordstart = 0
let s:currword = ''
let s:suggestions = { 'snippets': [], 'keywords': [] }
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

    fun! ReceiveKeywords(job_id, data, event)
        let s:suggestions['keywords'] = a:data
        call s:update()
    endfun

    fun! ReceiveSnippets(job_id, data, event)
        let snippets = UltiSnips#SnippetsInCurrentScope()
        call filter(a:data, {k, v -> v != ''})

        let s:suggestions['snippets'] = map(a:data, {k, v -> {'word': v, 'menu': snippets[v], 'kind': '<snippet>'}})
        call s:update()
    endfun

    let keywords = join(map(values(s:wordcache), {k, v -> join(v, '\\n')}), '\\n')
    call jobstart('echo "'.keywords.'" | fzy -e '.s:currword, {'on_stdout': 'ReceiveKeywords'})

    let snippet_words = join(s:get_snippet_words(), '\\n')
    call jobstart('echo "'.snippet_words.'" | fzy -e '.s:currword, {'on_stdout': 'ReceiveSnippets'})

endfun

fun! s:update()
    call complete(s:start + 1, s:suggestions['snippets'] + s:suggestions['keywords'])
endfun

fun! s:maybe_expand_snippet()
    let completed = v:completed_item
    if completed != {} && completed.kind == '<snippet>'
        call feedkeys("\<BS>")
        call UltiSnips#ExpandSnippet()
    endif
endfun

fun! s:get_snippet_words()
    let snippets = UltiSnips#SnippetsInCurrentScope()
    let filtered = filter(snippets, {k, v -> k =~ '^'.s:currword})
    return keys(filtered)
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
