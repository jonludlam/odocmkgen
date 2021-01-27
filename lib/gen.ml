let prelude =
  let open Makefile in
  concat
    [
      phony_rule "default" ~deps:[ "link" ] [];
      phony_rule "compile" ~oo_deps:[ "odocs" ] [];
      phony_rule "link" ~deps:[ "compile" ] ~oo_deps:[ "odocls" ] [];
      phony_rule "clean" [ cmd "rm" $ "-r" $ "odocs" $ "odocls" ];
      rule [ Fpath.v "odocs" ] [ cmd "mkdir" $ "odocs" ];
      rule [ Fpath.v "odocls" ] [ cmd "mkdir" $ "odocls" ];
    ]

let run dir =
  let inputs = Inputs.find_inputs dir in
  let tree = Inputs.make_tree inputs in
  let makefile =
    let open Makefile in
    concat [ prelude; Compile.gen tree; Link.gen inputs ]
  in
  Format.printf "%a\n" Makefile.pp makefile
