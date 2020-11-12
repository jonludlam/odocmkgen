The driver works on compiled files:

  $ ocamlc -I b -I a b/b.mli b/b.ml a/a.mli a/a.ml

  $ odocmkgen -L . -D . > Makefile

  $ make html
  odocmkgen compile -L . -D .
  Warning, couldn't find dep CamlinternalFormatBasics of file a/a.cmi
  Warning, couldn't find dep Stdlib of file a/a.cmi
  Warning, couldn't find dep CamlinternalFormatBasics of file b/b.cmi
  Warning, couldn't find dep Stdlib of file b/b.cmi
  Starting link
  odocmkgen generate --package b
  Starting link
  odocmkgen generate --package a
  odoc support-files --output-dir html
  odoc html-generate odocls/a/a.odocl --output-dir html
  odoc html-generate odocls/b/b.odocl --output-dir html

  $ find
  .
  ./odocls
  ./odocls/b
  ./odocls/b/b.odocl
  ./odocls/a
  ./odocls/a/a.odocl
  ./b
  ./b/b.mli
  ./b/b.cmo
  ./b/b.ml
  ./b/b.cmi
  ./Makefile.b.link
  ./Makefile.gen
  ./html
  ./html/b
  ./html/b/B
  ./html/b/B/index.html
  ./html/odoc.css
  ./html/highlight.pack.js
  ./html/a
  ./html/a/A
  ./html/a/A/index.html
  ./Makefile
  ./Makefile.b.generate
  ./Makefile.a.generate
  ./run.t
  ./a.out
  ./Makefile.a.link
  ./a
  ./a/a.ml
  ./a/a.mli
  ./a/a.cmo
  ./a/a.cmi
  ./odocs
  ./odocs/b
  ./odocs/b/b.odoc
  ./odocs/a
  ./odocs/a/a.odoc
