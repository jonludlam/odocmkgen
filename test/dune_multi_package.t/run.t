The driver works on compiled files:

  $ dune build

  $ dune exec -- odocmkgen prepare-packages -o prep a b
  Copy '$TESTCASE_ROOT/_build/install/default/lib/a/a.cmi' -> 'prep/packages/a/a.cmi'
  Copy '$TESTCASE_ROOT/_build/install/default/lib/a/a.cmt' -> 'prep/packages/a/a.cmt'
  Copy '$TESTCASE_ROOT/_build/install/default/lib/a/a.cmti' -> 'prep/packages/a/a.cmti'
  Create 'prep/packages/a.mld'
  Copy '$TESTCASE_ROOT/_build/install/default/lib/b/b.cmi' -> 'prep/packages/b/b.cmi'
  Copy '$TESTCASE_ROOT/_build/install/default/lib/b/b.cmt' -> 'prep/packages/b/b.cmt'
  Copy '$TESTCASE_ROOT/_build/install/default/lib/b/b.cmti' -> 'prep/packages/b/b.cmti'
  Create 'prep/packages/b.mld'
  Create 'prep/packages.mld'

  $ odocmkgen gen prep > Makefile
  Warning, couldn't find dep CamlinternalFormatBasics of file prep/packages/b/b.cmti
  Warning, couldn't find dep Stdlib of file prep/packages/b/b.cmti
  Warning, couldn't find dep CamlinternalFormatBasics of file prep/packages/a/a.cmti
  Warning, couldn't find dep Stdlib of file prep/packages/a/a.cmti

  $ cat Makefile
  default : link
  
  .PHONY : default
  
  compile :  | odocs
  
  .PHONY : compile
  
  link : compile | odocls
  
  .PHONY : link
  
  clean : 
  	'rm' '-r' 'odocs' 'odocls'
  
  .PHONY : clean
  
  odocs : 
  	'mkdir' 'odocs'
  
  odocls : 
  	'mkdir' 'odocls'
  
  
  odocs/./page-packages.odoc : prep/packages.mld
  	'odoc' 'compile' '--child' 'page-b' '--child' 'page-a' '$<' '-o' '$@'
  
  compile- : odocs/./page-packages.odoc
  
  .PHONY : compile-
  
  odocs/packages/page-b.odoc : prep/packages/b.mld odocs/./page-packages.odoc
  	'odoc' 'compile' '--parent' 'page-packages' '--child' 'B' '$<' '-I' 'odocs/./' '-o' '$@'
  
  odocs/packages/page-a.odoc : prep/packages/a.mld odocs/./page-packages.odoc
  	'odoc' 'compile' '--parent' 'page-packages' '--child' 'A' '$<' '-I' 'odocs/./' '-o' '$@'
  
  compile-packages : odocs/packages/page-b.odoc odocs/packages/page-a.odoc
  
  .PHONY : compile-packages
  
  odocs/packages/a/a.odoc : prep/packages/a/a.cmti odocs/packages/page-a.odoc odocs/packages/b/b.odoc
  	'odoc' 'compile' '--parent' 'page-a' '$<' '-I' 'odocs/packages/' '-I' 'odocs/packages/b/' '-o' '$@'
  
  compile-packages-a : odocs/packages/a/a.odoc
  
  .PHONY : compile-packages-a
  
  odocs/packages/b/b.odoc : prep/packages/b/b.cmti odocs/packages/page-b.odoc
  	'odoc' 'compile' '--parent' 'page-b' '$<' '-I' 'odocs/packages/' '-o' '$@'
  
  compile-packages-b : odocs/packages/b/b.odoc
  
  .PHONY : compile-packages-b
  
  compile : compile- compile-packages compile-packages-a compile-packages-b
  
  .PHONY : compile
  
  
  odocls/./page-packages.odocl : odocs/./page-packages.odoc | compile-packages compile-packages-a compile-packages-b
  	'odoc' 'link' '$<' '-o' '$@' '-I' 'odocs/packages/' '-I' 'odocs/packages/a/' '-I' 'odocs/packages/b/'
  
  link : odocls/./page-packages.odocl
  
  .PHONY : link
  
  odocls/packages/page-b.odocl : odocs/packages/page-b.odoc | compile-packages-a compile-packages-b
  	'odoc' 'link' '$<' '-o' '$@' '-I' 'odocs/packages/a/' '-I' 'odocs/packages/b/'
  
  odocls/packages/page-a.odocl : odocs/packages/page-a.odoc | compile-packages-a compile-packages-b
  	'odoc' 'link' '$<' '-o' '$@' '-I' 'odocs/packages/a/' '-I' 'odocs/packages/b/'
  
  link : odocls/packages/page-b.odocl odocls/packages/page-a.odocl
  
  .PHONY : link
  
  odocls/packages/a/a.odocl : odocs/packages/a/a.odoc | compile-packages-b
  	'odoc' 'link' '$<' '-o' '$@' '-I' 'odocs/packages/b/'
  
  link : odocls/packages/a/a.odocl
  
  .PHONY : link
  
  odocls/packages/b/b.odocl : odocs/packages/b/b.odoc
  	'odoc' 'link' '$<' '-o' '$@'
  
  link : odocls/packages/b/b.odocl
  
  .PHONY : link
  

  $ make
  'mkdir' 'odocs'
  'odoc' 'compile' '--child' 'page-b' '--child' 'page-a' 'prep/packages.mld' '-o' 'odocs/./page-packages.odoc'
  'odoc' 'compile' '--parent' 'page-packages' '--child' 'B' 'prep/packages/b.mld' '-I' 'odocs/./' '-o' 'odocs/packages/page-b.odoc'
  'odoc' 'compile' '--parent' 'page-packages' '--child' 'A' 'prep/packages/a.mld' '-I' 'odocs/./' '-o' 'odocs/packages/page-a.odoc'
  'odoc' 'compile' '--parent' 'page-b' 'prep/packages/b/b.cmti' '-I' 'odocs/packages/' '-o' 'odocs/packages/b/b.odoc'
  'odoc' 'compile' '--parent' 'page-a' 'prep/packages/a/a.cmti' '-I' 'odocs/packages/' '-I' 'odocs/packages/b/' '-o' 'odocs/packages/a/a.odoc'
  'mkdir' 'odocls'
  'odoc' 'link' 'odocs/./page-packages.odoc' '-o' 'odocls/./page-packages.odocl' '-I' 'odocs/packages/' '-I' 'odocs/packages/a/' '-I' 'odocs/packages/b/'
  'odoc' 'link' 'odocs/packages/page-b.odoc' '-o' 'odocls/packages/page-b.odocl' '-I' 'odocs/packages/a/' '-I' 'odocs/packages/b/'
  'odoc' 'link' 'odocs/packages/page-a.odoc' '-o' 'odocls/packages/page-a.odocl' '-I' 'odocs/packages/a/' '-I' 'odocs/packages/b/'
  'odoc' 'link' 'odocs/packages/a/a.odoc' '-o' 'odocls/packages/a/a.odocl' '-I' 'odocs/packages/b/'
  'odoc' 'link' 'odocs/packages/b/b.odoc' '-o' 'odocls/packages/b/b.odocl'

  $ odocmkgen generate odocls > Makefile.generate
  dir=packages/a file=A
  dir=packages/b file=B
  dir=packages/a file=
  dir=packages/b file=
  dir=packages file=

  $ make -f Makefile.generate html
  'odoc' 'support-files' '--output-dir' 'html'
  'odoc' 'html-generate' '--output-dir' 'html' 'odocls/packages/a/a.odocl'
  'odoc' 'html-generate' '--output-dir' 'html' 'odocls/packages/b/b.odocl'
  'odoc' 'html-generate' '--output-dir' 'html' 'odocls/packages/page-a.odocl'
  'odoc' 'html-generate' '--output-dir' 'html' 'odocls/packages/page-b.odocl'
  'odoc' 'html-generate' '--output-dir' 'html' 'odocls/page-packages.odocl'

  $ make -f Makefile.generate latex
  'odoc' 'latex-generate' '--output-dir' 'latex' 'odocls/packages/a/a.odocl'
  dir=packages/a file=A
  'odoc' 'latex-generate' '--output-dir' 'latex' 'odocls/packages/b/b.odocl'
  dir=packages/b file=B
  'odoc' 'latex-generate' '--output-dir' 'latex' 'odocls/packages/page-a.odocl'
  dir=packages/a file=
  'odoc' 'latex-generate' '--output-dir' 'latex' 'odocls/packages/page-b.odocl'
  dir=packages/b file=
  'odoc' 'latex-generate' '--output-dir' 'latex' 'odocls/page-packages.odocl'
  dir=packages file=

  $ make -f Makefile.generate man
  'odoc' 'man-generate' '--output-dir' 'man' 'odocls/packages/a/a.odocl'
  'odoc' 'man-generate' '--output-dir' 'man' 'odocls/packages/b/b.odocl'
  'odoc' 'man-generate' '--output-dir' 'man' 'odocls/packages/page-a.odocl'
  'odoc' 'man-generate' '--output-dir' 'man' 'odocls/packages/page-b.odocl'
  'odoc' 'man-generate' '--output-dir' 'man' 'odocls/page-packages.odocl'
  odoc: internal error, uncaught exception:
        Sys_error("man/packages.3o/: Is a directory")
        Raised by primitive operation at Stdlib.open_out_gen in file "stdlib.ml", line 324, characters 29-55
        Called from Stdlib.open_out in file "stdlib.ml" (inlined), line 329, characters 2-74
        Called from Odoc_odoc__Rendering.render_document.(fun) in file "src/odoc/rendering.ml", line 63, characters 15-52
        Called from Odoc_document__Renderer.traverse.aux in file "src/document/renderer.ml", line 15, characters 4-32
        Called from Odoc_odoc__Rendering.render_document in file "src/odoc/rendering.ml", line 59, characters 2-388
        Called from Cmdliner_term.app.(fun) in file "cmdliner_term.ml", line 25, characters 19-24
        Called from Cmdliner_term.app.(fun) in file "cmdliner_term.ml", line 23, characters 12-19
        Called from Cmdliner.Term.run in file "cmdliner.ml", line 117, characters 32-39
  make: *** [Makefile.generate:115: man/packages.3o/] Error 2
  [2]

  $ find html latex man | sort
  html
  html/highlight.pack.js
  html/odoc.css
  html/packages
  html/packages/a
  html/packages/a/A
  html/packages/a/A/index.html
  html/packages/a/index.html
  html/packages/b
  html/packages/b/B
  html/packages/b/B/index.html
  html/packages/b/index.html
  html/packages/index.html
  latex
  latex/packages
  latex/packages.tex
  latex/packages/a
  latex/packages/a.tex
  latex/packages/a/A.tex
  latex/packages/b
  latex/packages/b.tex
  latex/packages/b/B.tex
  man
  man/packages
  man/packages/a.3o
  man/packages/a.A.3o
  man/packages/b.3o
  man/packages/b.B.3o
