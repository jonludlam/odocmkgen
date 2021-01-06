A basic test for working with Dune's _build/install.

  $ dune build -p test

Use paths found by findlib:

  $ P=$(dune exec -- ocamlfind query test)
  $ echo "$P"
  $TESTCASE_ROOT/_build/install/default/lib/test

  $ odocmkgen -- "$P" > Makefile

  $ make
  odocmkgen gen $TESTCASE_ROOT/_build/install/default/lib/test
  Warning, couldn't find dep CamlinternalFormatBasics of file $TESTCASE_ROOT/_build/install/default/lib/test/test.cmti
  Warning, couldn't find dep Stdlib of file $TESTCASE_ROOT/_build/install/default/lib/test/test.cmti
  mkdir odocs
  'odoc' 'compile' '--package' 'test' '$TESTCASE_ROOT/_build/install/default/lib/test/test.cmti' '-o' 'odocs/test/test.odoc'
  'odoc' 'compile' '--package' 'test' '$TESTCASE_ROOT/_build/install/default/doc/test/odoc-pages/test.mld' '-o' 'odocs/test/odoc-pages/page-test.odoc'
  mkdir odocls
  'odoc' 'link' 'odocs/test/odoc-pages/page-test.odoc' '-o' 'odocls/test/odoc-pages/page-test.odocl' '-I' 'odocs/test/' '-I' 'odocs/test/odoc-pages/'
  'odoc' 'link' 'odocs/test/test.odoc' '-o' 'odocls/test/test.odocl' '-I' 'odocs/test/' '-I' 'odocs/test/odoc-pages/'

  $ jq_scan_references() { jq -c '.. | .["`Reference"]? | select(.) | .[0]'; }

Doesn't resolve but should:

  $ odoc_print odocls/test/odoc-pages/page-test.odocl | jq_scan_references
  {"`Resolved":{"`Value":[{"`Identifier":{"`Root":[{"`RootPage":"test"},"Test"]}},"x"]}}
