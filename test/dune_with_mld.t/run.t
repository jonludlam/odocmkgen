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

Build:

  $ make
  'mkdir' 'odocs'
  'odoc' 'compile' '--package' 'packages' 'prep/packages/test.mld' '-o' 'odocs/packages/page-test.odoc'
  'odoc' 'compile' '--package' 'prep' 'prep/packages.mld' '-o' 'odocs/./page-packages.odoc'
  'odoc' 'compile' '--package' 'test' 'prep/packages/test/test.cmti' '-o' 'odocs/packages/test/test.odoc'
  'mkdir' 'odocls'
  'odoc' 'link' 'odocs/packages/page-test.odoc' '-o' 'odocls/packages/page-test.odocl' '-I' 'odocs/packages/'
  'odoc' 'link' 'odocs/./page-packages.odoc' '-o' 'odocls/./page-packages.odocl' '-I' 'odocs/./'
  'odoc' 'link' 'odocs/packages/test/test.odoc' '-o' 'odocls/packages/test/test.odocl' '-I' 'odocs/packages/test/'

  $ jq_scan_references() { jq -c '.. | .["`Reference"]? | select(.) | .[0]'; }

Doesn't resolve but should:

  $ odoc_print odocls/test/page-test.odocl | jq_scan_references
  odoc_print: PATH argument: no `odocls/test/page-test.odocl' file or directory
  Usage: odoc_print [OPTION]... PATH
  Try `odoc_print --help' for more information.

Finally, render:

  $ odocmkgen generate odocls > Makefile.gen
  dir=packages file=test
  dir=test file=Test
  dir=prep file=packages

  $ make -f Makefile.gen html
  'odoc' 'support-files' '--output-dir' 'html'
  'odoc' 'html-generate' '--output-dir' 'html' 'odocls/packages/page-test.odocl'
  'odoc' 'html-generate' '--output-dir' 'html' 'odocls/packages/test/test.odocl'
  'odoc' 'html-generate' '--output-dir' 'html' 'odocls/page-packages.odocl'
