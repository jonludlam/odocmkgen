open Listm

let paths_of_package all_files package =
  let all_paths =
    all_files >>= fun file ->
    match Fpath.(segs (normalize file)) with
    | "odocls" :: pkg :: _ when pkg = package -> [Fpath.add_ext "odocl" file]
    | _ -> []
  in
  setify all_paths

let run path package =
  let package_makefile = Printf.sprintf "Makefile.%s.generate" package in

  let all_files = Inputs.find_files ["odocl"] path in

  let pkg_files = paths_of_package all_files package in

  let oc = open_out package_makefile in

  let mk format =
    List.iter
      (fun f ->
        let str_format = match format with | `Html -> "html" | `Latex -> "latex" | `Man -> "man" in
        let targets = Odoc.generate_targets f format in
        let str = Format.asprintf "%s &: %a\n\todoc %s-generate %a --output-dir %s\n" (String.concat " " targets) Fpath.pp f str_format Fpath.pp f str_format in
        Printf.fprintf oc "%s" str;
        let str = Format.asprintf "%s : %s\n" str_format (String.concat " " targets) in
        Printf.fprintf oc "%s" str
        ) pkg_files;
  in

  mk `Html;
  mk `Latex;
  mk `Man;

  close_out oc

