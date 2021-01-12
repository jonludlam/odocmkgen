Automatic generation of the package index page.

  $ dune build -p test

  $ odocmkgen -- "`dune exec -- ocamlfind query test`" > Makefile

  $ make html
  odocmkgen gen $TESTCASE_ROOT/_build/install/default/lib/test
  Warning, couldn't find dep Stdlib of file $TESTCASE_ROOT/_build/install/default/lib/test/test.cmt
  Warning, couldn't find dep CamlinternalFormatBasics of file $TESTCASE_ROOT/_build/install/default/lib/test/test.cmt
  'mkdir' '-p' 'odocs/test'
  'odocmkgen' 'package-index' 'test' 'test' >'odocs/test/test.mld'
  'odoc' 'compile' '--package' 'test' '-c' 'test' 'odocs/test/test.mld' '-o' 'odocs/test/page-test.odoc'
  'odoc' 'compile' '--parent' 'page-test' '$TESTCASE_ROOT/_build/install/default/lib/test/test.cmt' '-I' 'odocs/test/' '-o' 'odocs/test/test.odoc'
  'odoc' 'link' 'odocs/test/page-test.odoc' '-o' 'odocls/test/page-test.odocl' '-I' 'odocs/test/'
  'odoc' 'link' 'odocs/test/test.odoc' '-o' 'odocls/test/test.odocl' '-I' 'odocs/test/'
  'odocmkgen' 'generate' '--package' 'test'
  dir=test/test file=
  dir=test/test file=Test
  odoc support-files --output-dir html
  odoc html-generate odocls/test/page-test.odocl --output-dir html
  odoc html-generate odocls/test/test.odocl --output-dir html

  $ cat odocs/test/test.mld
  {0 test}
  
  - {!module-test}
  - {!module-test}

  $ odoc_print odocls/test/page-test.odocl
  {
    "name": { "`Page": [ { "`RootPage": "test" }, "test" ] },
    "root": "<root>",
    "content": [
      [
        "odocs/test/test.mld 0:0 0:8",
        {
          "`Heading": [
            "`Title",
            {
              "`Label": [
                { "`Page": [ { "`RootPage": "test" }, "test" ] },
                "test"
              ]
            },
            [ [ "odocs/test/test.mld 0:3 0:7", { "`Word": "test" } ] ]
          ]
        }
      ],
      [
        "odocs/test/test.mld 2:0 3:16",
        {
          "`List": [
            "`Unordered",
            [
              [
                [
                  "odocs/test/test.mld 2:2 2:16",
                  {
                    "`Paragraph": [
                      [
                        "odocs/test/test.mld 2:2 2:16",
                        {
                          "`Reference": [
                            {
                              "`Resolved": {
                                "`Identifier": {
                                  "`Root": [
                                    {
                                      "`Page": [
                                        { "`RootPage": "test" },
                                        "test"
                                      ]
                                    },
                                    "Test"
                                  ]
                                }
                              }
                            },
                            []
                          ]
                        }
                      ]
                    ]
                  }
                ]
              ],
              [
                [
                  "odocs/test/test.mld 3:2 3:16",
                  {
                    "`Paragraph": [
                      [
                        "odocs/test/test.mld 3:2 3:16",
                        {
                          "`Reference": [
                            {
                              "`Resolved": {
                                "`Identifier": {
                                  "`Root": [
                                    {
                                      "`Page": [
                                        { "`RootPage": "test" },
                                        "test"
                                      ]
                                    },
                                    "Test"
                                  ]
                                }
                              }
                            },
                            []
                          ]
                        }
                      ]
                    ]
                  }
                ]
              ]
            ]
          ]
        }
      ]
    ],
    "digest": "<digest>"
  }
