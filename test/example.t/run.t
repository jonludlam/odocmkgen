The driver works on compiled files:

  $ ocamlc -I b -I a b/b.mli b/b.ml a/a.mli a/a.ml

  $ odocmkgen -L a -L b -D a > Makefile

  $ make html
  odocmkgen gen -L a -L b -D a
  Warning, couldn't find dep CamlinternalFormatBasics of file a/a.cmi
  Warning, couldn't find dep Stdlib of file a/a.cmi
  Warning, couldn't find dep CamlinternalFormatBasics of file b/b.cmi
  Warning, couldn't find dep Stdlib of file b/b.cmi
  odoc compile --package b b/b.cmi  -o odocs/b/b.odoc
  odoc link odocs/b/b.odoc -o odocls/b/b.odocl -I odocs/b/
  Starting link
  odocmkgen generate --package b
  odoc compile --package a a/a.cmi  -o odocs/a/a.odoc
  odoc link odocs/a/a.odoc -o odocls/a/a.odocl -I odocs/a/
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
