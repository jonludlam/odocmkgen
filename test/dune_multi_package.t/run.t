The driver works on compiled files:

  $ dune build

  $ dune exec -- odocmkgen prepare-packages -o prep a b
  Copy '$TESTCASE_ROOT/_build/install/default/lib/a/a.cmi' -> 'prep/packages/a/a.cmi'
  Copy '$TESTCASE_ROOT/_build/install/default/lib/a/a.cmt' -> 'prep/packages/a/a.cmt'
  Copy '$TESTCASE_ROOT/_build/install/default/lib/a/a.cmti' -> 'prep/packages/a/a.cmti'
  Create 'prep/packages/a.mld'
  Copy '$TESTCASE_ROOT/_build/install/default/lib/b/b.cmi' -> 'prep/packages/b/b.cmi'
  Copy '$TESTCASE_ROOT/_build/install/default/lib/b/b.cmt' -> 'prep/packages/b/b.cmt'
  Copy '$TESTCASE_ROOT/_build/install/default/lib/b/b.cmti' -> 'prep/packages/b/b.cmti'
  Create 'prep/packages/b.mld'
  Create 'prep/packages.mld'

  $ odocmkgen gen prep > Makefile
  Warning, couldn't find dep CamlinternalFormatBasics of file prep/packages/b/b.cmti
  Warning, couldn't find dep Stdlib of file prep/packages/b/b.cmti
  Warning, couldn't find dep CamlinternalFormatBasics of file prep/packages/a/a.cmti
  Warning, couldn't find dep Stdlib of file prep/packages/a/a.cmti

  $ make
  'mkdir' 'odocs'
  'odoc' 'compile' '--package' 'b' 'prep/packages/b/b.cmti' '-o' 'odocs/packages/b/b.odoc'
  'odoc' 'compile' '--package' 'a' 'prep/packages/a/a.cmti' '-I' 'odocs/packages/b/' '-o' 'odocs/packages/a/a.odoc'
  'odoc' 'compile' '--package' 'packages' 'prep/packages/a.mld' '-o' 'odocs/packages/page-a.odoc'
  'odoc' 'compile' '--package' 'packages' 'prep/packages/b.mld' '-o' 'odocs/packages/page-b.odoc'
  'odoc' 'compile' '--package' 'prep' 'prep/packages.mld' '-o' 'odocs/./page-packages.odoc'
  'mkdir' 'odocls'
  'odoc' 'link' 'odocs/packages/a/a.odoc' '-o' 'odocls/packages/a/a.odocl' '-I' 'odocs/packages/a/' '-I' 'odocs/packages/b/'
  'odoc' 'link' 'odocs/packages/b/b.odoc' '-o' 'odocls/packages/b/b.odocl' '-I' 'odocs/packages/b/'
  'odoc' 'link' 'odocs/packages/page-b.odoc' '-o' 'odocls/packages/page-b.odocl' '-I' 'odocs/packages/'
  'odoc' 'link' 'odocs/packages/page-a.odoc' '-o' 'odocls/packages/page-a.odocl' '-I' 'odocs/packages/'
  'odoc' 'link' 'odocs/./page-packages.odoc' '-o' 'odocls/./page-packages.odocl' '-I' 'odocs/./'

  $ odocmkgen generate odocls > Makefile.generate
  dir=a file=A
  dir=b file=B
  dir=packages file=a
  dir=packages file=b
  dir=prep file=packages

  $ make -f Makefile.generate html
  'odoc' 'support-files' '--output-dir' 'html'
  'odoc' 'html-generate' '--output-dir' 'html' 'odocls/packages/a/a.odocl'
  'odoc' 'html-generate' '--output-dir' 'html' 'odocls/packages/b/b.odocl'
  'odoc' 'html-generate' '--output-dir' 'html' 'odocls/packages/page-a.odocl'
  'odoc' 'html-generate' '--output-dir' 'html' 'odocls/packages/page-b.odocl'
  'odoc' 'html-generate' '--output-dir' 'html' 'odocls/page-packages.odocl'

  $ make -f Makefile.generate latex
  'odoc' 'latex-generate' '--output-dir' 'latex' 'odocls/packages/a/a.odocl'
  dir=a file=A
  'odoc' 'latex-generate' '--output-dir' 'latex' 'odocls/packages/b/b.odocl'
  dir=b file=B
  'odoc' 'latex-generate' '--output-dir' 'latex' 'odocls/packages/page-a.odocl'
  dir=packages file=a
  'odoc' 'latex-generate' '--output-dir' 'latex' 'odocls/packages/page-b.odocl'
  dir=packages file=b
  'odoc' 'latex-generate' '--output-dir' 'latex' 'odocls/page-packages.odocl'
  dir=prep file=packages

  $ make -f Makefile.generate man
  'odoc' 'man-generate' '--output-dir' 'man' 'odocls/packages/a/a.odocl'
  'odoc' 'man-generate' '--output-dir' 'man' 'odocls/packages/b/b.odocl'
  'odoc' 'man-generate' '--output-dir' 'man' 'odocls/packages/page-a.odocl'
  'odoc' 'man-generate' '--output-dir' 'man' 'odocls/packages/page-b.odocl'
  'odoc' 'man-generate' '--output-dir' 'man' 'odocls/page-packages.odocl'

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
  html/packages
  html/packages/a.html
  html/packages/b.html
  html/prep
  html/prep/packages.html
  latex
  latex/a
  latex/a/A.tex
  latex/b
  latex/b/B.tex
  latex/packages
  latex/packages/a.tex
  latex/packages/b.tex
  latex/prep
  latex/prep/packages.tex
  man
  man/a
  man/a/A.3o
  man/b
  man/b/B.3o
  man/packages
  man/packages/a.3o
  man/packages/b.3o
  man/prep
  man/prep/packages.3o
