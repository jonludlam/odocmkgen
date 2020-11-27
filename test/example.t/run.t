The driver works on compiled files:

  $ ocamlc -I b -I a b/b.mli b/b.ml a/a.mli a/a.ml

  $ odocmkgen -- a b > Makefile

  $ make html
  odocmkgen gen a b
  Warning, couldn't find dep CamlinternalFormatBasics of file b/b.cmi
  Warning, couldn't find dep Stdlib of file b/b.cmi
  Warning, couldn't find dep CamlinternalFormatBasics of file a/a.cmi
  Warning, couldn't find dep Stdlib of file a/a.cmi
  'mkdir' '-p' 'odocs/b'
  'odocmkgen' 'package-index' 'b' 'b' >'odocs/b/b.mld'
  'odoc' 'compile' '--package' 'b' '-c' 'b' 'odocs/b/b.mld' '-o' 'odocs/b/page-b.odoc'
  'odoc' 'compile' '--parent' 'page-b' 'b/b.cmi' '-I' 'odocs/b/' '-o' 'odocs/b/b.odoc'
  'odoc' 'link' 'odocs/b/page-b.odoc' '-o' 'odocls/b/page-b.odocl' '-I' 'odocs/b/'
  'odoc' 'link' 'odocs/b/b.odoc' '-o' 'odocls/b/b.odocl' '-I' 'odocs/b/'
  'odocmkgen' 'generate' '--package' 'b'
  dir=b/b file=
  dir=b/b file=B
  'mkdir' '-p' 'odocs/a'
  'odocmkgen' 'package-index' 'a' 'a' >'odocs/a/a.mld'
  'odoc' 'compile' '--package' 'a' '-c' 'a' 'odocs/a/a.mld' '-o' 'odocs/a/page-a.odoc'
  'odoc' 'compile' '--parent' 'page-a' 'a/a.cmi' '-I' 'odocs/a/' '-o' 'odocs/a/a.odoc'
  'odoc' 'link' 'odocs/a/page-a.odoc' '-o' 'odocls/a/page-a.odocl' '-I' 'odocs/a/'
  'odoc' 'link' 'odocs/a/a.odoc' '-o' 'odocls/a/a.odocl' '-I' 'odocs/a/'
  'odocmkgen' 'generate' '--package' 'a'
  dir=a/a file=
  dir=a/a file=A
  odoc support-files --output-dir html
  odoc html-generate odocls/a/page-a.odocl --output-dir html
  odoc html-generate odocls/a/a.odocl --output-dir html
  odoc html-generate odocls/b/page-b.odocl --output-dir html
  odoc html-generate odocls/b/b.odocl --output-dir html

  $ ls Makefile*
  Makefile
  Makefile.a.generate
  Makefile.b.generate
  Makefile.gen
