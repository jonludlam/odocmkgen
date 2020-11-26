A basic test for working with Dune's _build/install.

  $ dune build -p test

  $ find _build/install
  _build/install
  _build/install/default
  _build/install/default/doc
  _build/install/default/doc/test
  _build/install/default/doc/test/odoc-pages
  _build/install/default/doc/test/odoc-pages/test.mld
  _build/install/default/lib
  _build/install/default/lib/test
  _build/install/default/lib/test/test.cmxa
  _build/install/default/lib/test/test.cmti
  _build/install/default/lib/test/test.ml
  _build/install/default/lib/test/opam
  _build/install/default/lib/test/test.cmx
  _build/install/default/lib/test/test.a
  _build/install/default/lib/test/test.cma
  _build/install/default/lib/test/test.mli
  _build/install/default/lib/test/META
  _build/install/default/lib/test/test.cmi
  _build/install/default/lib/test/test.cmxs
  _build/install/default/lib/test/dune-package
  _build/install/default/lib/test/test.cmt

Use paths found by findlib:

  $ P=$(dune exec -- ocamlfind query test)
  $ echo "$P"
  $TESTCASE_ROOT/_build/install/default/lib/test

  $ odocmkgen -- "$P" > Makefile

  $ make html
  odocmkgen gen $TESTCASE_ROOT/_build/install/default/lib/test
  Warning, couldn't find dep CamlinternalFormatBasics of file $TESTCASE_ROOT/_build/install/default/lib/test/test.cmti
  Warning, couldn't find dep Stdlib of file $TESTCASE_ROOT/_build/install/default/lib/test/test.cmti
  'mkdir' '-p' 'odocs/test'
  'odocmkgen' 'package-index' 'test' 'page-test' 'test' >'odocs/test/test.mld'
  'odoc' 'compile' '--package' 'test' '-c' 'page-test' '-c' 'test' 'odocs/test/test.mld' '-o' 'odocs/test/page-test.odoc'
  'odoc' 'compile' '--parent' 'page-test' '$TESTCASE_ROOT/_build/install/default/doc/test/odoc-pages/test.mld' '-I' 'odocs/test/' '-o' 'odocs/test/odoc-pages/page-test.odoc'
  'odoc' 'compile' '--parent' 'page-test' '$TESTCASE_ROOT/_build/install/default/lib/test/test.cmti' '-I' 'odocs/test/' '-o' 'odocs/test/test.odoc'
  'odoc' 'link' 'odocs/test/odoc-pages/page-test.odoc' '-o' 'odocls/test/odoc-pages/page-test.odocl' '-I' 'odocs/test/' '-I' 'odocs/test/odoc-pages/'
  'odoc' 'link' 'odocs/test/test.odoc' '-o' 'odocls/test/test.odocl' '-I' 'odocs/test/' '-I' 'odocs/test/odoc-pages/'
  'odocmkgen' 'generate' '--package' 'test'
  dir=test/test file=Test
  dir=test/test file=test
  odoc support-files --output-dir html
  odoc html-generate odocls/test/test.odocl --output-dir html
  odoc html-generate odocls/test/odoc-pages/page-test.odocl --output-dir html

  $ jq_scan_references() { jq -c '.. | .["`Reference"]? | select(.) | .[0]'; }

Doesn't resolve but should:

  $ odoc_print odocls/test/odoc-pages/page-test.odocl | jq_scan_references
  {"`Resolved":{"`Value":[{"`Identifier":{"`Root":[{"`Page":[{"`RootPage":"test"},"test"]},"Test"]}},"x"]}}
