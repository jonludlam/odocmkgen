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
  Process_util.lines_of_process
    (Format.asprintf "odoc compile-deps %a" Fpath.pp file)
  >>= process_line

let generate_targets odocl ty =
  let open Process_util in
  match ty with
  | `Html ->
      lines_of_process
        (Format.asprintf "odoc html-targets %a --output-dir html" Fpath.pp
           odocl)
  | `Latex ->
      lines_of_process
        (Format.asprintf "odoc latex-targets %a --output-dir latex" Fpath.pp
           odocl)
  | `Man ->
      lines_of_process
        (Format.asprintf "odoc man-targets %a --output-dir man" Fpath.pp odocl)
