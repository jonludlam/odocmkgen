The driver works on compiled files:

  $ ocamlc -I b -I a b/b.mli b/b.ml a/a.mli a/a.ml

  $ odocmkgen -L . -D . > Makefile

  $ make html
  odocmkgen gen -L . -D .
  Warning, couldn't find dep CamlinternalFormatBasics of file b/b.cmi
  Warning, couldn't find dep Stdlib of file b/b.cmi
  Warning, couldn't find dep CamlinternalFormatBasics of file a/a.cmi
  Warning, couldn't find dep Stdlib of file a/a.cmi
  Starting link
  odocmkgen generate --package b
  Starting link
  odocmkgen generate --package a
  odoc support-files --output-dir html
  odoc html-generate odocls/a/a.odocl --output-dir html
  odoc html-generate odocls/b/b.odocl --output-dir html

  $ ls Makefile*
  Makefile
  Makefile.a.generate
  Makefile.b.generate
  Makefile.gen
