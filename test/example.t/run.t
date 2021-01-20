The driver works on compiled files:

  $ ocamlc -I b -I a b/b.mli b/b.ml a/a.mli a/a.ml

  $ odocmkgen gen . > Makefile
  Warning, couldn't find dep CamlinternalFormatBasics of file ./b/b.cmi
  Warning, couldn't find dep Stdlib of file ./b/b.cmi
  Warning, couldn't find dep CamlinternalFormatBasics of file ./a/a.cmi
  Warning, couldn't find dep Stdlib of file ./a/a.cmi

  $ make
  'mkdir' 'odocs'
  'odoc' 'compile' '--package' 'a' 'a/a.cmi' '-o' 'odocs/a/a.odoc'
  'odoc' 'compile' '--package' 'b' 'b/b.cmi' '-o' 'odocs/b/b.odoc'
  'mkdir' 'odocls'
  'odoc' 'link' 'odocs/a/a.odoc' '-o' 'odocls/a/a.odocl' '-I' 'odocs/a/'
  'odoc' 'link' 'odocs/b/b.odoc' '-o' 'odocls/b/b.odocl' '-I' 'odocs/b/'

  $ odocmkgen generate odocls/* > Makefile.generate
  dir=a file=A
  dir=b file=B

  $ make -f Makefile.generate html
  'odoc' 'support-files' '--output-dir' 'html'
  'odoc' 'html-generate' '--output-dir' 'html' 'odocls/a/a.odocl'
  'odoc' 'html-generate' '--output-dir' 'html' 'odocls/b/b.odocl'

  $ make -f Makefile.generate latex
  'odoc' 'latex-generate' '--output-dir' 'latex' 'odocls/a/a.odocl'
  dir=a file=A
  'odoc' 'latex-generate' '--output-dir' 'latex' 'odocls/b/b.odocl'
  dir=b file=B

  $ make -f Makefile.generate man
  'odoc' 'man-generate' '--output-dir' 'man' 'odocls/a/a.odocl'
  'odoc' 'man-generate' '--output-dir' 'man' 'odocls/b/b.odocl'

  $ find html latex man | sort
  html
  html/a
  html/a/A
  html/a/A/index.html
  html/b
  html/b/B
  html/b/B/index.html
  html/highlight.pack.js
  html/odoc.css
  latex
  latex/a
  latex/a/A.tex
  latex/b
  latex/b/B.tex
  man
  man/a
  man/a/A.3o
  man/b
  man/b/B.3o
