(* Odoc *)
open Listm
open Util

type compile_dep = { c_unit_name : string; c_digest : Digest.t }
(** The name and optional digest of a dependency. Modules compiled with --no-alias-deps don't have
    digests for purely aliased modules, and we ignore them entirely. *)

(* *)
let compile_deps file =
  let process_line line =
    match Astring.String.cuts ~sep:" " line with
    | [ c_unit_name; c_digest ] -> [ { c_unit_name; c_digest } ]
    | _ -> []
  in
  match
    Process_util.lines_of_process "odoc"
      [ "compile-deps"; Fpath.to_string file ]
  with
  | Ok lines -> lines >>= process_line
  | Error _ -> []

let generate_targets odocl ty =
  let open Process_util in
  let odocl = Fpath.to_string odocl in
  let subcmd, output_dir =
    match ty with
    | `Html -> ("html-targets", "html")
    | `Latex -> ("latex-targets", "latex")
    | `Man -> ("man-targets", "man")
  in
  match
    lines_of_process "odoc" [ subcmd; odocl; "--output-dir"; output_dir ]
  with
  | Ok lines -> lines
  | Error _ -> (* ignore errors *) []
