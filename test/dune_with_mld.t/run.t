A basic test for working with Dune's _build/install.

  $ dune build -p test

Prepare packages:

  $ dune exec -- odocmkgen prepare-packages -o prep test
  Copy '$TESTCASE_ROOT/_build/install/default/lib/test/test.cmi' -> 'prep/test/test.cmi'
  Copy '$TESTCASE_ROOT/_build/install/default/lib/test/test.cmt' -> 'prep/test/test.cmt'
  Copy '$TESTCASE_ROOT/_build/install/default/lib/test/test.cmti' -> 'prep/test/test.cmti'
  Copy '$TESTCASE_ROOT/_build/install/default/doc/test/odoc-pages/test.mld' -> 'prep/test/test.mld'

Generate the Makefile:

  $ odocmkgen gen prep > Makefile
  Warning, couldn't find dep CamlinternalFormatBasics of file prep/test/test.cmti
  Warning, couldn't find dep Stdlib of file prep/test/test.cmti

Build:

  $ make
  'mkdir' 'odocs'
  'odoc' 'compile' '--package' 'test' 'prep/test/test.cmti' '-o' 'odocs/test/test.odoc'
  'odoc' 'compile' '--package' 'test' 'prep/test/test.mld' '-o' 'odocs/test/page-test.odoc'
  'mkdir' 'odocls'
  'odoc' 'link' 'odocs/test/page-test.odoc' '-o' 'odocls/test/page-test.odocl' '-I' 'odocs/test/'
  'odoc' 'link' 'odocs/test/test.odoc' '-o' 'odocls/test/test.odocl' '-I' 'odocs/test/'

  $ jq_scan_references() { jq -c '.. | .["`Reference"]? | select(.) | .[0]'; }

Doesn't resolve but should:

  $ odoc_print odocls/test/page-test.odocl | jq_scan_references
  {"`Resolved":{"`Value":[{"`Identifier":{"`Root":[{"`RootPage":"test"},"Test"]}},"x"]}}

Finally, render:

  $ odocmkgen generate odocls > Makefile.gen
  dir=test file=test
  dir=test file=Test

  $ make -f Makefile.gen html
  'odoc' 'support-files' '--output-dir' 'html'
  'odoc' 'html-generate' '--output-dir' 'html' 'odocls/test/page-test.odocl'
  'odoc' 'html-generate' '--output-dir' 'html' 'odocls/test/test.odocl'
