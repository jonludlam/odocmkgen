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
  	'odoc' 'compile' '--child' 'B' '--child' 'A' '$<' '-o' '$@'
  
  compile- : odocs/./page-packages.odoc
  
  .PHONY : compile-
  
  
  compile-packages : 
  
  .PHONY : compile-packages
  
  odocs/packages/a/a.odoc : prep/packages/a/a.cmti odocs/./page-packages.odoc odocs/packages/b/b.odoc
  	'odoc' 'compile' '--parent' 'page-packages' '$<' '-I' 'odocs/./' '-I' 'odocs/packages/b/' '-o' '$@'
  
  compile-packages-a : odocs/packages/a/a.odoc
  
  .PHONY : compile-packages-a
  
  odocs/packages/b/b.odoc : prep/packages/b/b.cmti odocs/./page-packages.odoc
  	'odoc' 'compile' '--parent' 'page-packages' '$<' '-I' 'odocs/./' '-o' '$@'
  
  compile-packages-b : odocs/packages/b/b.odoc
  
  .PHONY : compile-packages-b
  
  compile : compile- compile-packages compile-packages-a compile-packages-b
  
  .PHONY : compile
  
  
  odocls/./page-packages.odocl : odocs/./page-packages.odoc | compile-
  	'odoc' 'link' '$<' '-o' '$@' '-I' 'odocs/.'
  
  link : odocls/./page-packages.odocl
  
  .PHONY : link
  
  odocls/packages/a/a.odocl : odocs/packages/a/a.odoc | compile-
  	'odoc' 'link' '$<' '-o' '$@' '-I' 'odocs/.'
  
  link : odocls/packages/a/a.odocl
  
  .PHONY : link
  
  odocls/packages/b/b.odocl : odocs/packages/b/b.odoc | compile-
  	'odoc' 'link' '$<' '-o' '$@' '-I' 'odocs/.'
  
  link : odocls/packages/b/b.odocl
  
  .PHONY : link
  

  $ make
  'mkdir' 'odocs'
  'odoc' 'compile' '--child' 'B' '--child' 'A' 'prep/packages.mld' '-o' 'odocs/./page-packages.odoc'
  'odoc' 'compile' '--parent' 'page-packages' 'prep/packages/b/b.cmti' '-I' 'odocs/./' '-o' 'odocs/packages/b/b.odoc'
  'odoc' 'compile' '--parent' 'page-packages' 'prep/packages/a/a.cmti' '-I' 'odocs/./' '-I' 'odocs/packages/b/' '-o' 'odocs/packages/a/a.odoc'
  'mkdir' 'odocls'
  'odoc' 'link' 'odocs/./page-packages.odoc' '-o' 'odocls/./page-packages.odocl' '-I' 'odocs/.'
  File "odocs/./page-packages.odoc":
  Failed to resolve child reference unresolvedroot(B)
  File "odocs/./page-packages.odoc":
  Failed to resolve child reference unresolvedroot(A)
  'odoc' 'link' 'odocs/packages/a/a.odoc' '-o' 'odocls/packages/a/a.odocl' '-I' 'odocs/.'
  'odoc' 'link' 'odocs/packages/b/b.odoc' '-o' 'odocls/packages/b/b.odocl' '-I' 'odocs/.'

  $ odocmkgen generate odocls > Makefile.generate
  dir=packages file=A
  dir=packages file=B
  dir=packages file=

  $ make -f Makefile.generate html
  'odoc' 'support-files' '--output-dir' 'html'
  'odoc' 'html-generate' '--output-dir' 'html' 'odocls/packages/a/a.odocl'
  'odoc' 'html-generate' '--output-dir' 'html' 'odocls/packages/b/b.odocl'
  'odoc' 'html-generate' '--output-dir' 'html' 'odocls/page-packages.odocl'

  $ make -f Makefile.generate latex
  'odoc' 'latex-generate' '--output-dir' 'latex' 'odocls/packages/a/a.odocl'
  dir=packages file=A
  'odoc' 'latex-generate' '--output-dir' 'latex' 'odocls/packages/b/b.odocl'
  dir=packages file=B
  'odoc' 'latex-generate' '--output-dir' 'latex' 'odocls/page-packages.odocl'
  dir=packages file=

  $ make -f Makefile.generate man
  'odoc' 'man-generate' '--output-dir' 'man' 'odocls/packages/a/a.odocl'
  'odoc' 'man-generate' '--output-dir' 'man' 'odocls/packages/b/b.odocl'
  'odoc' 'man-generate' '--output-dir' 'man' 'odocls/page-packages.odocl'
  odoc: internal error, uncaught exception:
        Sys_error("man/packages.3o/: Is a directory")
        Raised by primitive operation at Stdlib.open_out_gen in file "stdlib.ml", line 324, characters 29-55
        Called from Stdlib.open_out in file "stdlib.ml" (inlined), line 329, characters 2-74
        Called from Odoc_odoc__Rendering.render_document.(fun) in file "src/odoc/rendering.ml", line 61, characters 15-52
        Called from Odoc_document__Renderer.traverse.aux in file "src/document/renderer.ml", line 15, characters 4-32
        Called from Odoc_odoc__Rendering.render_document in file "src/odoc/rendering.ml", line 57, characters 2-388
        Called from Cmdliner_term.app.(fun) in file "cmdliner_term.ml", line 25, characters 19-24
        Called from Cmdliner_term.app.(fun) in file "cmdliner_term.ml", line 23, characters 12-19
        Called from Cmdliner.Term.run in file "cmdliner.ml", line 117, characters 32-39
  make: *** [Makefile.generate:73: man/packages.3o/] Error 2
  [2]

  $ find html latex man | sort
  html
  html/highlight.pack.js
  html/odoc.css
  html/packages
  html/packages/A
  html/packages/A/index.html
  html/packages/B
  html/packages/B/index.html
  html/packages/index.html
  latex
  latex/packages
  latex/packages.tex
  latex/packages/A.tex
  latex/packages/B.tex
  man
  man/packages
  man/packages/A.3o
  man/packages/B.3o
