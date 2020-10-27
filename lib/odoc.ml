(* Odoc *)
open Listm

(** The name and optional digest of a dependency. Modules compiled with --no-alias-deps don't have
    digests for purely aliased modules *)
type compile_dep = {
  c_unit_name : string;
  c_digest : Digest.t;
}
    
type link_dep = {
  l_package : string;
  l_name : string;
  l_digest : Digest.t;
}

let pp_link_dep fmt l =
  Format.fprintf fmt "{ %s %s }" l.l_package l.l_name

let lines_of_process p =
  let ic = Unix.open_process_in p in
  let lines = Fun.protect
    ~finally:(fun () -> ignore(Unix.close_process_in ic))
    (fun () ->
      let rec inner acc =
        try
          let l = input_line ic in
          inner (l::acc)
        with End_of_file -> List.rev acc
      in inner [])
  in
  lines

let compile_deps file =
  let process_line line =
    match Astring.String.cuts ~sep:" " line with
    | [c_unit_name; c_digest] ->
      [{c_unit_name; c_digest}]
    | _ -> []
  in
  lines_of_process (Format.asprintf "odoc compile-deps %a" Fpath.pp file)
  >>= process_line

let link_deps dir =
  let process_line line =
    Format.eprintf "line: %s\n%!" line;
    match Astring.String.cuts ~sep:" " line with
    | [parent_path; l_name; l_digest] -> begin
      match Astring.String.cuts ~sep:"/" parent_path with
      | "universes" :: _universe :: l_package :: _version :: _ ->
      [{l_package; l_name; l_digest}]
      | "packages" :: l_package :: _version :: _ ->
      [{l_package; l_name; l_digest}]
      | _ -> []
      end
    | _ -> []
  in
  lines_of_process (Format.asprintf "odoc link-deps %a" Fpath.pp dir)
  >>= process_line

let generate_targets odocl ty =
  match ty with
  | `Html -> lines_of_process (Format.asprintf "odoc html-targets %a --output-dir html" Fpath.pp odocl)
  | `Latex -> lines_of_process (Format.asprintf "odoc latex-targets %a --output-dir latex" Fpath.pp odocl)
  | `Man -> lines_of_process (Format.asprintf "odoc man-targets %a --output-dir man" Fpath.pp odocl)
