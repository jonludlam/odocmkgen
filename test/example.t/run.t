The driver works on compiled files:

  $ ocamlc -I b -I a b/b.mli b/b.ml a/a.mli a/a.ml

  $ odocmkgen -L . -D . > Makefile

  $ make html
  odocmkgen compile -L . -D .
  Warning, couldn't find dep CamlinternalFormatBasics of file b/b.cmi
  Warning, couldn't find dep Stdlib of file b/b.cmi
  Warning, couldn't find dep CamlinternalFormatBasics of file a/a.cmi
  Warning, couldn't find dep Stdlib of file a/a.cmi
  Starting link
  odocmkgen generate --package a
  Starting link
  odocmkgen generate --package b
  odoc support-files --output-dir html
  odoc html-generate odocls/b/b.odocl --output-dir html
  odoc html-generate odocls/a/a.odocl --output-dir html

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

  $ cat Makefile*
  
  default: generate
  .PHONY: compile link generate clean html latex man
  compile: odocs
  link: compile odocls
  Makefile.gen : Makefile
  	odocmkgen compile -L . -D .
  generate: link
  odocs:
  	mkdir odocs
  odocls:
  	mkdir odocls
  clean:
  	rm -rf odocs odocls html latex man Makefile.*link Makefile.gen Makefile.*generate
  html: html/odoc.css
  html/odoc.css:
  	odoc support-files --output-dir html
  ifneq ($(MAKECMDGOALS),clean)
  -include Makefile.gen
  endif
  html/a/A/index.html &: odocls/a/a.odocl
  	odoc html-generate odocls/a/a.odocl --output-dir html
  html : html/a/A/index.html
  latex/a/A.tex &: odocls/a/a.odocl
  	odoc latex-generate odocls/a/a.odocl --output-dir latex
  latex : latex/a/A.tex
  man/a/A.3o &: odocls/a/a.odocl
  	odoc man-generate odocls/a/a.odocl --output-dir man
  man : man/a/A.3o
  odocls/a/a.odocl : odocs/a/a.odoc
  	@odoc link odocs/a/a.odoc -o odocls/a/a.odocl 
  link: odocls/a/a.odocl
  Makefile.a.generate: odocls/a/a.odocl
  	odocmkgen generate --package a
  -include Makefile.a.generate
  html/b/B/index.html &: odocls/b/b.odocl
  	odoc html-generate odocls/b/b.odocl --output-dir html
  html : html/b/B/index.html
  latex/b/B.tex &: odocls/b/b.odocl
  	odoc latex-generate odocls/b/b.odocl --output-dir latex
  latex : latex/b/B.tex
  man/b/B.3o &: odocls/b/b.odocl
  	odoc man-generate odocls/b/b.odocl --output-dir man
  man : man/b/B.3o
  odocls/b/b.odocl : odocs/b/b.odoc
  	@odoc link odocs/b/b.odoc -o odocls/b/b.odocl 
  link: odocls/b/b.odocl
  Makefile.b.generate: odocls/b/b.odocl
  	odocmkgen generate --package b
  -include Makefile.b.generate
  odocs/b/b.odoc : ./b/b.cmi 
  	@odoc compile --package b $<  -o odocs/b/b.odoc
  compile : odocs/b/b.odoc
  Makefile.b.link : odocs/b/b.odoc
  odocs/a/a.odoc : ./a/a.cmi 
  	@odoc compile --package a $<  -o odocs/a/a.odoc
  compile : odocs/a/a.odoc
  Makefile.a.link : odocs/a/a.odoc
  ifneq ($(MAKECMDGOALS),compile)
  -include Makefile.b.link
  endif
  Makefile.b.link:
  	@odocmkgen link --package b
  ifneq ($(MAKECMDGOALS),compile)
  -include Makefile.a.link
  endif
  Makefile.a.link:
  	@odocmkgen link --package a
