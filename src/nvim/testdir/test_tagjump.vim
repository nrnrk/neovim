" Tests for tagjump (tags and special searches)

source check.vim
source screendump.vim

" SEGV occurs in older versions.  (At least 7.4.1748 or older)
func Test_ptag_with_notagstack()
  set notagstack
  call assert_fails('ptag does_not_exist_tag_name', 'E426')
  set tagstack&vim
endfunc

func Test_cancel_ptjump()
  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "word\tfile1\tcmd1",
        \ "word\tfile2\tcmd2"],
        \ 'Xtags')

  only!
  call feedkeys(":ptjump word\<CR>\<CR>", "xt")
  help
  call assert_equal(2, winnr('$'))

  call delete('Xtags')
  set tags&
  quit
endfunc

func Test_static_tagjump()
  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "one\tXfile1\t/^one/;\"\tf\tfile:\tsignature:(void)",
        \ "word\tXfile2\tcmd2"],
        \ 'Xtags')
  new Xfile1
  call setline(1, ['empty', 'one()', 'empty'])
  write
  tag one
  call assert_equal(2, line('.'))

  bwipe!
  set tags&
  call delete('Xtags')
  call delete('Xfile1')
endfunc

func Test_duplicate_tagjump()
  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "thesame\tXfile1\t1;\"\td\tfile:",
        \ "thesame\tXfile1\t2;\"\td\tfile:",
        \ "thesame\tXfile1\t3;\"\td\tfile:",
        \ ],
        \ 'Xtags')
  new Xfile1
  call setline(1, ['thesame one', 'thesame two', 'thesame three'])
  write
  tag thesame
  call assert_equal(1, line('.'))
  tnext
  call assert_equal(2, line('.'))
  tnext
  call assert_equal(3, line('.'))

  bwipe!
  set tags&
  call delete('Xtags')
  call delete('Xfile1')
endfunc

func Test_tagjump_switchbuf()
  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "second\tXfile1\t2",
        \ "third\tXfile1\t3",],
        \ 'Xtags')
  call writefile(['first', 'second', 'third'], 'Xfile1')

  enew | only
  set switchbuf=
  stag second
  call assert_equal(2, winnr('$'))
  call assert_equal(2, line('.'))
  stag third
  call assert_equal(3, winnr('$'))
  call assert_equal(3, line('.'))

  enew | only
  set switchbuf=useopen
  stag second
  call assert_equal(2, winnr('$'))
  call assert_equal(2, line('.'))
  stag third
  call assert_equal(2, winnr('$'))
  call assert_equal(3, line('.'))

  enew | only
  set switchbuf=usetab
  tab stag second
  call assert_equal(2, tabpagenr('$'))
  call assert_equal(2, line('.'))
  1tabnext | stag third
  call assert_equal(2, tabpagenr('$'))
  call assert_equal(3, line('.'))

  tabclose!
  enew | only
  call delete('Xfile1')
  call delete('Xtags')
  set tags&
  set switchbuf&vim
endfunc

" Tests for [ CTRL-I and CTRL-W CTRL-I commands
function Test_keyword_jump()
  call writefile(["#include Xinclude", "",
	      \ "",
	      \ "/* test text test tex start here",
	      \ "		some text",
	      \ "		test text",
	      \ "		start OK if found this line",
	      \ "	start found wrong line",
	      \ "test text"], 'Xtestfile')
  call writefile(["/* test text test tex start here",
	      \ "		some text",
	      \ "		test text",
	      \ "		start OK if found this line",
	      \ "	start found wrong line",
	      \ "test text"], 'Xinclude')
  new Xtestfile
  call cursor(1,1)
  call search("start")
  exe "normal! 5[\<C-I>"
  call assert_equal("		start OK if found this line", getline('.'))
  call cursor(1,1)
  call search("start")
  exe "normal! 5\<C-W>\<C-I>"
  call assert_equal("		start OK if found this line", getline('.'))
  enew! | only
  call delete('Xtestfile')
  call delete('Xinclude')
endfunction

" Test for jumping to a tag with 'hidden' set, with symbolic link in path of
" tag.  This only works for Unix, because of the symbolic link.
func Test_tag_symbolic()
  if !has('unix')
    return
  endif
  set hidden
  call delete("Xtest.dir", "rf")
  call system("ln -s . Xtest.dir")
  " Create a tags file with the current directory name inserted.
  call writefile([
        \ "SECTION_OFF	" . getcwd() . "/Xtest.dir/Xtest.c	/^#define  SECTION_OFF  3$/",
        \ '',
        \ ], 'Xtags')
  call writefile(['#define  SECTION_OFF  3',
        \ '#define  NUM_SECTIONS 3'], 'Xtest.c')

  " Try jumping to a tag, but with a path that contains a symbolic link.  When
  " wrong, this will give the ATTENTION message.  The next space will then be
  " eaten by hit-return, instead of moving the cursor to 'd'.
  set tags=Xtags
  enew!
  call append(0, 'SECTION_OFF')
  call cursor(1,1)
  exe "normal \<C-]> "
  call assert_equal('Xtest.c', expand('%:t'))
  call assert_equal(2, col('.'))

  set nohidden
  set tags&
  enew!
  call delete('Xtags')
  call delete('Xtest.c')
  call delete("Xtest.dir", "rf")
  %bwipe!
endfunc

" Tests for tag search with !_TAG_FILE_ENCODING.
" Depends on the test83-tags2 and test83-tags3 files.
func Test_tag_file_encoding()
  throw 'skipped: Nvim removed test83-tags2, test83-tags3'
  if has('vms')
    return
  endif

  if !has('iconv') || iconv("\x82\x60", "cp932", "utf-8") != "\uff21"
    return
  endif

  let save_enc = &encoding
  set encoding=utf8

  let content = ['text for tags1', 'abcdefghijklmnopqrs']
  call writefile(content, 'Xtags1.txt')
  let content = ['text for tags2', 'ＡＢＣ']
  call writefile(content, 'Xtags2.txt')
  let content = ['text for tags3', 'ＡＢＣ']
  call writefile(content, 'Xtags3.txt')
  let content = ['!_TAG_FILE_ENCODING	utf-8	//', 'abcdefghijklmnopqrs	Xtags1.txt	/abcdefghijklmnopqrs']
  call writefile(content, 'Xtags1')

  " case1:
  new
  set tags=Xtags1
  tag abcdefghijklmnopqrs
  call assert_equal('Xtags1.txt', expand('%:t'))
  call assert_equal('abcdefghijklmnopqrs', getline('.'))
  close

  " case2:
  new
  set tags=test83-tags2
  tag /.ＢＣ
  call assert_equal('Xtags2.txt', expand('%:t'))
  call assert_equal('ＡＢＣ', getline('.'))
  close

  " case3:
  new
  set tags=test83-tags3
  tag abc50
  call assert_equal('Xtags3.txt', expand('%:t'))
  call assert_equal('ＡＢＣ', getline('.'))
  close

  set tags&
  let &encoding = save_enc
  call delete('Xtags1.txt')
  call delete('Xtags2.txt')
  call delete('Xtags3.txt')
  call delete('Xtags1')
endfunc

func Test_tagjump_etags()
  if !has('emacs_tags')
    return
  endif
  call writefile([
        \ "void foo() {}",
        \ "int main(int argc, char **argv)",
        \ "{",
        \ "\tfoo();",
        \ "\treturn 0;",
        \ "}",
        \ ], 'Xmain.c')

  call writefile([
	\ "\x0c",
        \ "Xmain.c,64",
        \ "void foo() {}\x7ffoo\x011,0",
        \ "int main(int argc, char **argv)\x7fmain\x012,14",
	\ ], 'Xtags')
  set tags=Xtags
  ta foo
  call assert_equal('void foo() {}', getline('.'))

  " Test for including another tags file
  call writefile([
        \ "\x0c",
        \ "Xmain.c,64",
        \ "void foo() {}\x7ffoo\x011,0",
        \ "\x0c",
        \ "Xnonexisting,include",
        \ "\x0c",
        \ "Xtags2,include"
        \ ], 'Xtags')
  call writefile([
        \ "\x0c",
        \ "Xmain.c,64",
        \ "int main(int argc, char **argv)\x7fmain\x012,14",
        \ ], 'Xtags2')
  tag main
  call assert_equal(2, line('.'))

  " corrupted tag line
  call writefile([
        \ "\x0c",
        \ "Xmain.c,8",
        \ "int main"
        \ ], 'Xtags', 'b')
  call assert_fails('tag foo', 'E426:')

  " invalid line number
  call writefile([
	\ "\x0c",
        \ "Xmain.c,64",
        \ "void foo() {}\x7ffoo\x0abc,0",
	\ ], 'Xtags')
  call assert_fails('tag foo', 'E426:')

  " invalid tag name
  call writefile([
	\ "\x0c",
        \ "Xmain.c,64",
        \ ";;;;\x7f1,0",
	\ ], 'Xtags')
  call assert_fails('tag foo', 'E426:')

  call delete('Xtags')
  call delete('Xtags2')
  call delete('Xmain.c')
  set tags&
  bwipe!
endfunc

" Test for getting and modifying the tag stack
func Test_getsettagstack()
  call writefile(['line1', 'line2', 'line3'], 'Xfile1')
  call writefile(['line1', 'line2', 'line3'], 'Xfile2')
  call writefile(['line1', 'line2', 'line3'], 'Xfile3')

  enew | only
  call settagstack(1, {'items' : []})
  call assert_equal(0, gettagstack(1).length)
  call assert_equal([], gettagstack(1).items)
  " Error cases
  call assert_equal({}, gettagstack(100))
  call assert_equal(-1, settagstack(100, {'items' : []}))
  call assert_fails('call settagstack(1, [1, 10])', 'E715')
  call assert_fails("call settagstack(1, {'items' : 10})", 'E714')
  call assert_fails("call settagstack(1, {'items' : []}, 10)", 'E928')
  call assert_fails("call settagstack(1, {'items' : []}, 'b')", 'E962')

  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "one\tXfile1\t1",
        \ "three\tXfile3\t3",
        \ "two\tXfile2\t2"],
        \ 'Xtags')

  let stk = []
  call add(stk, {'bufnr' : bufnr('%'), 'tagname' : 'one',
	\ 'from' : [bufnr('%'), line('.'), col('.'), 0], 'matchnr' : 1})
  tag one
  call add(stk, {'bufnr' : bufnr('%'), 'tagname' : 'two',
	\ 'from' : [bufnr('%'), line('.'), col('.'), 0], 'matchnr' : 1})
  tag two
  call add(stk, {'bufnr' : bufnr('%'), 'tagname' : 'three',
	\ 'from' : [bufnr('%'), line('.'), col('.'), 0], 'matchnr' : 1})
  tag three
  call assert_equal(3, gettagstack(1).length)
  call assert_equal(stk, gettagstack(1).items)
  " Check for default - current window
  call assert_equal(3, gettagstack().length)
  call assert_equal(stk, gettagstack().items)

  " Try to set current index to invalid values
  call settagstack(1, {'curidx' : -1})
  call assert_equal(1, gettagstack().curidx)
  call settagstack(1, {'curidx' : 50})
  call assert_equal(4, gettagstack().curidx)

  " Try pushing invalid items onto the stack
  call settagstack(1, {'items' : []})
  call settagstack(1, {'items' : ["plate"]}, 'a')
  call assert_equal(0, gettagstack().length)
  call assert_equal([], gettagstack().items)
  call settagstack(1, {'items' : [{"tagname" : "abc"}]}, 'a')
  call assert_equal(0, gettagstack().length)
  call assert_equal([], gettagstack().items)
  call settagstack(1, {'items' : [{"from" : 100}]}, 'a')
  call assert_equal(0, gettagstack().length)
  call assert_equal([], gettagstack().items)
  call settagstack(1, {'items' : [{"from" : [2, 1, 0, 0]}]}, 'a')
  call assert_equal(0, gettagstack().length)
  call assert_equal([], gettagstack().items)

  " Push one item at a time to the stack
  call settagstack(1, {'items' : []})
  call settagstack(1, {'items' : [stk[0]]}, 'a')
  call settagstack(1, {'items' : [stk[1]]}, 'a')
  call settagstack(1, {'items' : [stk[2]]}, 'a')
  call settagstack(1, {'curidx' : 4})
  call assert_equal({'length' : 3, 'curidx' : 4, 'items' : stk},
        \ gettagstack(1))

  " Try pushing items onto a full stack
  for i in range(7)
    call settagstack(1, {'items' : stk}, 'a')
  endfor
  call assert_equal(20, gettagstack().length)
  call settagstack(1,
        \ {'items' : [{'tagname' : 'abc', 'from' : [1, 10, 1, 0]}]}, 'a')
  call assert_equal('abc', gettagstack().items[19].tagname)

  " truncate the tag stack
  call settagstack(1,
        \ {'curidx' : 9,
        \  'items' : [{'tagname' : 'abc', 'from' : [1, 10, 1, 0]}]}, 't')
  let t = gettagstack()
  call assert_equal(9, t.length)
  call assert_equal(10, t.curidx)

  " truncate the tag stack without pushing any new items
  call settagstack(1, {'curidx' : 5}, 't')
  let t = gettagstack()
  call assert_equal(4, t.length)
  call assert_equal(5, t.curidx)

  " truncate an empty tag stack and push new items
  call settagstack(1, {'items' : []})
  call settagstack(1,
        \ {'items' : [{'tagname' : 'abc', 'from' : [1, 10, 1, 0]}]}, 't')
  let t = gettagstack()
  call assert_equal(1, t.length)
  call assert_equal(2, t.curidx)

  " Tag with multiple matches
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "two\tXfile1\t1",
        \ "two\tXfile2\t3",
        \ "two\tXfile3\t2"],
        \ 'Xtags')
  call settagstack(1, {'items' : []})
  tag two
  tnext
  tnext
  call assert_equal(1, gettagstack().length)
  call assert_equal(3, gettagstack().items[0].matchnr)

  call settagstack(1, {'items' : []})
  call delete('Xfile1')
  call delete('Xfile2')
  call delete('Xfile3')
  call delete('Xtags')
  set tags&
endfunc

func Test_tag_with_count()
  call writefile([
	\ 'test	Xtest.h	/^void test();$/;"	p	typeref:typename:void	signature:()',
	\ ], 'Xtags')
  call writefile([
	\ 'main	Xtest.c	/^int main()$/;"	f	typeref:typename:int	signature:()',
	\ 'test	Xtest.c	/^void test()$/;"	f	typeref:typename:void	signature:()',
	\ ], 'Ytags')
  cal writefile([
	\ 'int main()',
	\ 'void test()',
	\ ], 'Xtest.c')
  cal writefile([
	\ 'void test();',
	\ ], 'Xtest.h')
  set tags=Xtags,Ytags

  new Xtest.c
  let tl = taglist('test', 'Xtest.c')
  call assert_equal(tl[0].filename, 'Xtest.c')
  call assert_equal(tl[1].filename, 'Xtest.h')

  tag test
  call assert_equal(bufname('%'), 'Xtest.c')
  1tag test
  call assert_equal(bufname('%'), 'Xtest.c')
  2tag test
  call assert_equal(bufname('%'), 'Xtest.h')

  set tags&
  call delete('Xtags')
  call delete('Ytags')
  bwipe Xtest.h
  bwipe Xtest.c
  call delete('Xtest.h')
  call delete('Xtest.c')
endfunc

func Test_tagnr_recall()
  call writefile([
	\ 'test	Xtest.h	/^void test();$/;"	p',
	\ 'main	Xtest.c	/^int main()$/;"	f',
	\ 'test	Xtest.c	/^void test()$/;"	f',
	\ ], 'Xtags')
  cal writefile([
	\ 'int main()',
	\ 'void test()',
	\ ], 'Xtest.c')
  cal writefile([
	\ 'void test();',
	\ ], 'Xtest.h')
  set tags=Xtags

  new Xtest.c
  let tl = taglist('test', 'Xtest.c')
  call assert_equal(tl[0].filename, 'Xtest.c')
  call assert_equal(tl[1].filename, 'Xtest.h')

  2tag test
  call assert_equal(bufname('%'), 'Xtest.h')
  pop
  call assert_equal(bufname('%'), 'Xtest.c')
  tag
  call assert_equal(bufname('%'), 'Xtest.h')

  set tags&
  call delete('Xtags')
  bwipe Xtest.h
  bwipe Xtest.c
  call delete('Xtest.h')
  call delete('Xtest.c')
endfunc

func Test_tag_line_toolong()
  call writefile([
	\ '1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678	django/contrib/admin/templates/admin/edit_inline/stacked.html	16;"	j	line:16	language:HTML'
	\ ], 'Xtags')
  set tags=Xtags
  let old_vbs = &verbose
  set verbose=5
  " ":tjump" should give "tag not found" not "Format error in tags file"
  call assert_fails('tj /foo', 'E426')
  try
    tj /foo
  catch /^Vim\%((\a\+)\)\=:E431/
    call assert_report(v:exception)
  catch /.*/
  endtry
  call assert_equal('Searching tags file Xtags', split(execute('messages'), '\n')[-1])

  call writefile([
	\ '123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567	django/contrib/admin/templates/admin/edit_inline/stacked.html	16;"	j	line:16	language:HTML'
	\ ], 'Xtags')
  call assert_fails('tj /foo', 'E426')
  try
    tj /foo
  catch /^Vim\%((\a\+)\)\=:E431/
    call assert_report(v:exception)
  catch /.*/
  endtry
  call assert_equal('Searching tags file Xtags', split(execute('messages'), '\n')[-1])

  " binary search works in file with long line
  call writefile([
        \ 'asdfasfd	nowhere	16',
	\ 'foobar	Xsomewhere	3; " 12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567',
        \ 'zasdfasfd	nowhere	16',
	\ ], 'Xtags')
  call writefile([
        \ 'one',
        \ 'two',
        \ 'trhee',
        \ 'four',
        \ ], 'Xsomewhere')
  tag foobar
  call assert_equal('Xsomewhere', expand('%'))
  call assert_equal(3, getcurpos()[1])

  call delete('Xtags')
  call delete('Xsomewhere')
  set tags&
  let &verbose = old_vbs
endfunc

" Check that using :tselect does not run into the hit-enter prompt.
" Requires a terminal to trigger that prompt.
func Test_tselect()
  CheckScreendump

  call writefile([
	\ 'main	Xtest.h	/^void test();$/;"	f',
	\ 'main	Xtest.c	/^int main()$/;"	f',
	\ 'main	Xtest.x	/^void test()$/;"	f',
	\ ], 'Xtags')
  cal writefile([
	\ 'int main()',
	\ 'void test()',
	\ ], 'Xtest.c')

  let lines =<< trim [SCRIPT]
    set tags=Xtags
  [SCRIPT]
  call writefile(lines, 'XTest_tselect')
  let buf = RunVimInTerminal('-S XTest_tselect', {'rows': 10, 'cols': 50})

  call term_wait(buf, 100)
  call term_sendkeys(buf, ":tselect main\<CR>2\<CR>")
  call VerifyScreenDump(buf, 'Test_tselect_1', {})

  call StopVimInTerminal(buf)
  call delete('Xtags')
  call delete('Xtest.c')
  call delete('XTest_tselect')
endfunc

func Test_tagline()
  call writefile([
	\ 'provision	Xtest.py	/^    def provision(self, **kwargs):$/;"	m	line:1	language:Python class:Foo',
	\ 'provision	Xtest.py	/^    def provision(self, **kwargs):$/;"	m	line:3	language:Python class:Bar',
	\], 'Xtags')
  call writefile([
	\ '    def provision(self, **kwargs):',
	\ '        pass',
	\ '    def provision(self, **kwargs):',
	\ '        pass',
	\], 'Xtest.py')

  set tags=Xtags

  1tag provision
  call assert_equal(line('.'), 1)
  2tag provision
  call assert_equal(line('.'), 3)

  call delete('Xtags')
  call delete('Xtest.py')
  set tags&
endfunc

" Test for expanding environment variable in a tag file name
func Test_tag_envvar()
  call writefile(["Func1\t$FOO\t/^Func1/"], 'Xtags')
  set tags=Xtags

  let $FOO='TagTestEnv'

  let caught_exception = v:false
  try
    tag Func1
  catch /E429:/
    call assert_match('E429:.*"TagTestEnv".*', v:exception)
    let caught_exception = v:true
  endtry
  call assert_true(caught_exception)

  set tags&
  call delete('Xtags')
  unlet $FOO
endfunc

" Test for :ptag
func Test_ptag()
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "second\tXfile1\t2",
        \ "third\tXfile1\t3",],
        \ 'Xtags')
  set tags=Xtags
  call writefile(['first', 'second', 'third'], 'Xfile1')

  enew | only
  ptag third
  call assert_equal(2, winnr())
  call assert_equal(2, winnr('$'))
  call assert_equal(1, getwinvar(1, '&previewwindow'))
  call assert_equal(0, getwinvar(2, '&previewwindow'))
  wincmd w
  call assert_equal(3, line('.'))

  " jump to the tag again
  ptag third
  call assert_equal(3, line('.'))

  " close the preview window
  pclose
  call assert_equal(1, winnr('$'))

  call delete('Xfile1')
  call delete('Xtags')
  set tags&
endfunc

" Tests for guessing the tag location
func Test_tag_guess()
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "func1\tXfoo\t/^int func1(int x)/",
        \ "func2\tXfoo\t/^int func2(int y)/",
        \ "func3\tXfoo\t/^func3/",
        \ "func4\tXfoo\t/^func4/"],
        \ 'Xtags')
  set tags=Xtags
  let code =<< trim [CODE]

    int FUNC1  (int x) { }
    int 
    func2   (int y) { }
    int * func3 () { }

  [CODE]
  call writefile(code, 'Xfoo')

  let v:statusmsg = ''
  ta func1
  call assert_match('E435:', v:statusmsg)
  call assert_equal(2, line('.'))
  let v:statusmsg = ''
  ta func2
  call assert_match('E435:', v:statusmsg)
  call assert_equal(4, line('.'))
  let v:statusmsg = ''
  ta func3
  call assert_match('E435:', v:statusmsg)
  call assert_equal(5, line('.'))
  call assert_fails('ta func4', 'E434:')

  call delete('Xtags')
  call delete('Xfoo')
  set tags&
endfunc

" Test for an unsorted tags file
func Test_tag_sort()
  call writefile([
        \ "first\tXfoo\t1",
        \ "ten\tXfoo\t3",
        \ "six\tXfoo\t2"],
        \ 'Xtags')
  set tags=Xtags
  let code =<< trim [CODE]
    int first() {}
    int six() {}
    int ten() {}
  [CODE]
  call writefile(code, 'Xfoo')

  call assert_fails('tag first', 'E432:')

  call delete('Xtags')
  call delete('Xfoo')
  set tags&
  %bwipe
endfunc

" Test for an unsorted tags file
func Test_tag_fold()
  call writefile([
        \ "!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "!_TAG_FILE_SORTED\t2\t/0=unsorted, 1=sorted, 2=foldcase/",
        \ "first\tXfoo\t1",
        \ "second\tXfoo\t2",
        \ "third\tXfoo\t3"],
        \ 'Xtags')
  set tags=Xtags
  let code =<< trim [CODE]
    int first() {}
    int second() {}
    int third() {}
  [CODE]
  call writefile(code, 'Xfoo')

  enew
  tag second
  call assert_equal('Xfoo', bufname(''))
  call assert_equal(2, line('.'))

  call delete('Xtags')
  call delete('Xfoo')
  set tags&
  %bwipe
endfunc

" Test for the :ltag command
func Test_ltag()
  call writefile([
        \ "!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "first\tXfoo\t1",
        \ "second\tXfoo\t/^int second() {}$/",
        \ "third\tXfoo\t3"],
        \ 'Xtags')
  set tags=Xtags
  let code =<< trim [CODE]
    int first() {}
    int second() {}
    int third() {}
  [CODE]
  call writefile(code, 'Xfoo')

  enew
  call setloclist(0, [], 'f')
  ltag third
  call assert_equal('Xfoo', bufname(''))
  call assert_equal(3, line('.'))
  call assert_equal([{'lnum': 3, 'end_lnum': 0, 'bufnr': bufnr('Xfoo'),
        \ 'col': 0, 'end_col': 0, 'pattern': '', 'valid': 1, 'vcol': 0,
        \ 'nr': 0, 'type': '', 'module': '', 'text': 'third'}], getloclist(0))

  ltag second
  call assert_equal(2, line('.'))
  call assert_equal([{'lnum': 0, 'end_lnum': 0, 'bufnr': bufnr('Xfoo'),
        \ 'col': 0, 'end_col': 0, 'pattern': '^\Vint second() {}\$',
        \ 'valid': 1, 'vcol': 0, 'nr': 0, 'type': '', 'module': '',
        \ 'text': 'second'}], getloclist(0))

  call delete('Xtags')
  call delete('Xfoo')
  set tags&
  %bwipe
endfunc

" Test for setting the last search pattern to the tag search pattern
" when cpoptions has 't'
func Test_tag_last_search_pat()
  call writefile([
        \ "!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "first\tXfoo\t/^int first() {}/",
        \ "second\tXfoo\t/^int second() {}/",
        \ "third\tXfoo\t/^int third() {}/"],
        \ 'Xtags')
  set tags=Xtags
  let code =<< trim [CODE]
    int first() {}
    int second() {}
    int third() {}
  [CODE]
  call writefile(code, 'Xfoo')

  enew
  let save_cpo = &cpo
  set cpo+=t
  let @/ = ''
  tag second
  call assert_equal('^int second() {}', @/)
  let &cpo = save_cpo

  call delete('Xtags')
  call delete('Xfoo')
  set tags&
  %bwipe
endfunc

" Test for jumping to a tag when the tag stack is full
func Test_tag_stack_full()
  let l = []
  for i in range(10, 31)
    let l += ["var" .. i .. "\tXfoo\t/^int var" .. i .. ";$/"]
  endfor
  call writefile(l, 'Xtags')
  set tags=Xtags

  let l = []
  for i in range(10, 31)
    let l += ["int var" .. i .. ";"]
  endfor
  call writefile(l, 'Xfoo')

  enew
  for i in range(10, 30)
    exe "tag var" .. i
  endfor
  let l = gettagstack()
  call assert_equal(20, l.length)
  call assert_equal('var11', l.items[0].tagname)
  tag var31
  let l = gettagstack()
  call assert_equal('var12', l.items[0].tagname)
  call assert_equal('var31', l.items[19].tagname)

  " Jump from the top of the stack
  call assert_fails('tag', 'E556:')

  " Pop from an unsaved buffer
  enew!
  call append(1, "sample text")
  call assert_fails('pop', 'E37:')
  call assert_equal(21, gettagstack().curidx)
  enew!

  " Pop all the entries in the tag stack
  call assert_fails('30pop', 'E555:')

  " Pop the tag stack when it is empty
  call settagstack(1, {'items' : []})
  call assert_fails('pop', 'E73:')

  call delete('Xtags')
  call delete('Xfoo')
  set tags&
  %bwipe
endfunc

" Test for browsing multiple matching tags
func Test_tag_multimatch()
  call writefile([
        \ "!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "first\tXfoo\t1",
        \ "first\tXfoo\t2",
        \ "first\tXfoo\t3"],
        \ 'Xtags')
  set tags=Xtags
  let code =<< trim [CODE]
    int first() {}
    int first() {}
    int first() {}
  [CODE]
  call writefile(code, 'Xfoo')

  tag first
  tlast
  call assert_equal(3, line('.'))
  call assert_fails('tnext', 'E428:')
  tfirst
  call assert_equal(1, line('.'))
  call assert_fails('tprev', 'E425:')

  call delete('Xtags')
  call delete('Xfoo')
  set tags&
  %bwipe
endfunc

" Test for the 'taglength' option
func Test_tag_length()
  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "tame\tXfile1\t1;",
        \ "tape\tXfile2\t1;"], 'Xtags')
  call writefile(['tame'], 'Xfile1')
  call writefile(['tape'], 'Xfile2')

  " Jumping to the tag 'tape', should instead jump to 'tame'
  new
  set taglength=2
  tag tape
  call assert_equal('Xfile1', @%)
  " Tag search should jump to the right tag
  enew
  tag /^tape$
  call assert_equal('Xfile2', @%)

  call delete('Xtags')
  call delete('Xfile1')
  call delete('Xfile2')
  set tags& taglength&
endfunc

" vim: shiftwidth=2 sts=2 expandtab
