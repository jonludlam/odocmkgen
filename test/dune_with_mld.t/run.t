A basic test for working with Dune's _build/install.

  $ dune build -p test

Prepare packages:

  $ dune exec -- odocmkgen prepare-packages -o prep test
  Copy '$TESTCASE_ROOT/_build/install/default/lib/test/test.cmi' -> 'prep/packages/test/test.cmi'
  Copy '$TESTCASE_ROOT/_build/install/default/lib/test/test.cmt' -> 'prep/packages/test/test.cmt'
  Copy '$TESTCASE_ROOT/_build/install/default/lib/test/test.cmti' -> 'prep/packages/test/test.cmti'
  Copy '$TESTCASE_ROOT/_build/install/default/doc/test/odoc-pages/test.mld' -> 'prep/packages/test.mld'
  Create 'prep/packages.mld'

Generate the Makefile:

  $ odocmkgen gen prep > Makefile
  Warning, couldn't find dep CamlinternalFormatBasics of file prep/packages/test/test.cmti
  Warning, couldn't find dep Stdlib of file prep/packages/test/test.cmti

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
  	'odoc' 'compile' '--child' 'Test' '$<' '-o' '$@'
  
  compile- : odocs/./page-packages.odoc
  
  .PHONY : compile-
  
  
  compile-packages : 
  
  .PHONY : compile-packages
  
  odocs/packages/test/test.odoc : prep/packages/test/test.cmti odocs/./page-packages.odoc
  	'odoc' 'compile' '--parent' 'page-packages' '$<' '-I' 'odocs/./' '-o' '$@'
  
  compile-packages-test : odocs/packages/test/test.odoc
  
  .PHONY : compile-packages-test
  
  compile : compile-packages compile-prep compile-test
  
  .PHONY : compile
  
  
  odocls/packages/page-test.odocl : odocs/packages/page-test.odoc | compile-packages
  	'odoc' 'link' '$<' '-o' '$@' '-I' 'odocs/packages/'
  
  link : odocls/packages/page-test.odocl
  
  .PHONY : link
  
  odocls/./page-packages.odocl : odocs/./page-packages.odoc | compile-prep
  	'odoc' 'link' '$<' '-o' '$@' '-I' 'odocs/./'
  
  link : odocls/./page-packages.odocl
  
  .PHONY : link
  
  odocls/packages/test/test.odocl : odocs/packages/test/test.odoc | compile-test
  	'odoc' 'link' '$<' '-o' '$@' '-I' 'odocs/packages/test/'
  
  link : odocls/packages/test/test.odocl
  
  .PHONY : link
  

Build:

  $ make
  'mkdir' 'odocs'
  make: *** No rule to make target 'compile-prep', needed by 'compile'.  Stop.
  [2]

  $ jq_scan_references() { jq -c '.. | .["`Reference"]? | select(.) | .[0]'; }

Doesn't resolve but should:

  $ odoc_print odocls/test/page-test.odocl | jq_scan_references
  odoc_print: PATH argument: no `odocls/test/page-test.odocl' file or directory
  Usage: odoc_print [OPTION]... PATH
  Try `odoc_print --help' for more information.

Finally, render:

  $ odocmkgen generate odocls > Makefile.gen
  gen: PACKAGES... arguments: no `odocls' directory
  Usage: gen generate [OPTION]... PACKAGES...
  Try `gen generate --help' or `gen --help' for more information.
  [124]

  $ make -f Makefile.gen html
  make: *** No rule to make target 'html'.  Stop.
  [2]
