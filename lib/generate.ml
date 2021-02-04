open Listm
open Util

let output_dir = function `Html -> "html" | `Latex -> "latex" | `Man -> "man"

let generate_command = function
  | `Html -> "html-generate"
  | `Latex -> "latex-generate"
  | `Man -> "man-generate"

let make_target = function `Html -> "html" | `Latex -> "latex" | `Man -> "man"

let mk_pkg target path =
  let files =
    Fs_util.dir_contents_rec path >>= fun p ->
    if Fpath.has_ext ".odocl" p then [ p ] else []
  in
  List.map
    (fun f ->
      let outputs = List.map Fpath.v (Odoc.generate_targets f target) in
      Makefile.(
        concat
          [
            phony_rule (make_target target) ~fdeps:outputs [];
            rule outputs ~fdeps:[ f ]
              [
                cmd "odoc" $ generate_command target $ "--output-dir"
                $ output_dir target $ "$<";
              ];
          ]))
    files
  |> Makefile.concat

let prelude =
  let open Makefile in
  let odoc_css = Fpath.v "html/odoc.css" in
  concat
    [
      phony_rule "default" ~deps:[ "html" ] [];
      phony_rule "html" ~fdeps:[ odoc_css ] [];
      rule [ odoc_css ]
        [ cmd "odoc" $ "support-files" $ "--output-dir" $ "html" ];
    ]

let run paths =
  let makefile =
    let mk target = Makefile.concat (List.map (mk_pkg target) paths) in
    Makefile.concat [ prelude; mk `Html; mk `Latex; mk `Man ]
  in
  Format.printf "%a\n" Makefile.pp makefile
