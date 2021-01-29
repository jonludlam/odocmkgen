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
  
  odocs/packages/page-b.odoc : prep/packages/b.mld odocs/./page-packages.odoc
  	'odoc' 'compile' '--parent' 'page-packages' '$<' '-I' 'odocs/./' '-o' '$@'
  
  odocs/packages/page-a.odoc : prep/packages/a.mld odocs/./page-packages.odoc
  	'odoc' 'compile' '--parent' 'page-packages' '$<' '-I' 'odocs/./' '-o' '$@'
  
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
  
  
  odocls/./page-packages.odocl : odocs/./page-packages.odoc | compile- compile-packages compile-packages-a compile-packages-b
  	'odoc' 'link' '$<' '-o' '$@' '-I' 'odocs/.' '-I' 'odocs/./packages' '-I' 'odocs/./packages/a' '-I' 'odocs/./packages/b'
  
  link : odocls/./page-packages.odocl
  
  .PHONY : link
  
  odocls/packages/page-b.odocl : odocs/packages/page-b.odoc | compile- compile-packages compile-packages-a compile-packages-b
  	'odoc' 'link' '$<' '-o' '$@' '-I' 'odocs/.' '-I' 'odocs/./packages' '-I' 'odocs/./packages/a' '-I' 'odocs/./packages/b'
  
  odocls/packages/page-a.odocl : odocs/packages/page-a.odoc | compile- compile-packages compile-packages-a compile-packages-b
  	'odoc' 'link' '$<' '-o' '$@' '-I' 'odocs/.' '-I' 'odocs/./packages' '-I' 'odocs/./packages/a' '-I' 'odocs/./packages/b'
  
  link : odocls/packages/page-b.odocl odocls/packages/page-a.odocl
  
  .PHONY : link
  
  odocls/packages/a/a.odocl : odocs/packages/a/a.odoc | compile- compile-packages compile-packages-a compile-packages-b
  	'odoc' 'link' '$<' '-o' '$@' '-I' 'odocs/.' '-I' 'odocs/./packages' '-I' 'odocs/./packages/a' '-I' 'odocs/./packages/b'
  
  link : odocls/packages/a/a.odocl
  
  .PHONY : link
  
  odocls/packages/b/b.odocl : odocs/packages/b/b.odoc | compile- compile-packages compile-packages-a compile-packages-b
  	'odoc' 'link' '$<' '-o' '$@' '-I' 'odocs/.' '-I' 'odocs/./packages' '-I' 'odocs/./packages/a' '-I' 'odocs/./packages/b'
  
  link : odocls/packages/b/b.odocl
  
  .PHONY : link
  

  $ make
  'mkdir' 'odocs'
  'odoc' 'compile' '--child' 'B' '--child' 'A' 'prep/packages.mld' '-o' 'odocs/./page-packages.odoc'
  'odoc' 'compile' '--parent' 'page-packages' 'prep/packages/b.mld' '-I' 'odocs/./' '-o' 'odocs/packages/page-b.odoc'
  ERROR: Specified parent is not a parent of this file
  make: *** [Makefile:33: odocs/packages/page-b.odoc] Error 1
  [2]

  $ odocmkgen generate odocls > Makefile.generate
  gen: PACKAGES... arguments: no `odocls' directory
  Usage: gen generate [OPTION]... PACKAGES...
  Try `gen generate --help' or `gen --help' for more information.
  [124]

  $ make -f Makefile.generate html
  make: *** No rule to make target 'html'.  Stop.
  [2]

  $ make -f Makefile.generate latex
  make: *** No rule to make target 'latex'.  Stop.
  [2]

  $ make -f Makefile.generate man
  make: *** No rule to make target 'man'.  Stop.
  [2]

  $ find html latex man | sort
  find: 'html': No such file or directory
  find: 'latex': No such file or directory
  find: 'man': No such file or directory
