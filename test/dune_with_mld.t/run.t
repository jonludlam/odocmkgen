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
  _build/install/default/lib/test/META
  _build/install/default/lib/test/test.cmx
  _build/install/default/lib/test/test.a
  _build/install/default/lib/test/test.cmxs
  _build/install/default/lib/test/test.cma
  _build/install/default/lib/test/test.cmt
  _build/install/default/lib/test/test.cmi
  _build/install/default/lib/test/test.cmxa
  _build/install/default/lib/test/test.cmti
  _build/install/default/lib/test/opam
  _build/install/default/lib/test/test.ml
  _build/install/default/lib/test/test.mli
  _build/install/default/lib/test/dune-package

  $ odocmkgen -D _build/install -L _build/install > Makefile
  $ odocmkgen gen -D _build/install -L _build/install
  Warning, couldn't find dep CamlinternalFormatBasics of file _build/install/default/lib/test/test.cmti
  Warning, couldn't find dep Stdlib of file _build/install/default/lib/test/test.cmti

  $ make html
  Starting link
  odocmkgen generate --package default
  odoc support-files --output-dir html
  odoc html-generate odocls/default/doc/test/odoc-pages/page-test.odocl --output-dir html
  odoc html-generate odocls/default/lib/test/test.odocl --output-dir html

  $ jq_scan_references() { jq -c '.. | .["`Reference"]? | select(.) | .[0]'; }

Doesn't resolve but should:

  $ odoc_print odocls/default/doc/test/odoc-pages/page-test.odocl | jq_scan_references
  {"`Dot":[{"`Root":["Test","`TUnknown"]},"x"]}
