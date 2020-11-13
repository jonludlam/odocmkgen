open Listm

let contents dir =
  Sys.readdir (Fpath.to_string dir)
  |> Array.map (Fpath.( / ) dir)
  |> Array.to_list

let filter pred item = if pred item then [item] else []

let is_dir x = Sys.is_directory (Fpath.to_string x)

let has_ext exts f =
  List.exists (fun suffix -> Fpath.has_ext suffix f) exts

let rec find_files base_dir =
  let items = contents base_dir in
  let dirs, files = List.partition is_dir items in
  let subitems = dirs >>= find_files in
  files @ subitems

(** Lower is better *)
let cm_file_preference = function
  | ".cmti" -> Some 1
  | ".cmt" -> Some 2
  | ".cmi" -> Some 3
  | _ -> None

(** Get cm* files out of a list of files.
    Given the choice between a cmti, a cmt and a cmi file, we chose them according to [cm_file_preference] above *)
let get_cm_files files =
  let rec skip f = function hd :: tl when f hd -> skip f tl | x -> x in
  (* Take the first of each group. *)
  let rec dedup acc = function
    | (base, _, p) :: tl ->
        let tl = skip (fun (base', _, _) -> base = base') tl in
        dedup (p :: acc) tl
    | [] -> acc
  in
  (* Sort files by their basename and preference, remove other files *)
  files
  >>= (fun p ->
        let without_ext, ext = Fpath.split_ext p in
        match cm_file_preference ext with
        | Some pref -> [ (Fpath.basename without_ext, pref, p) ]
        | None -> [])
  |> List.sort compare |> dedup []

(** Get mld files out of a list of files. *)
let get_mld_files = List.filter (Fpath.has_ext ".mld")

(* This assumes that the directory immediately below the 'root' is the name of the package.
   Note that for some older packages this is not always true (e.g. ocamlfind, oasis).
   Be warned! *)
let package_of_relpath relpath =
  match Fpath.segs relpath with
  | pkg :: _ -> pkg
  | _ ->
    Format.eprintf "Invalid path, unable to determine package: %a\n%!" Fpath.pp relpath;
    failwith "Invalid path"

(** Represents the necessary information about a particular compilation unit *)
type t = {
  name : string; (** 'Astring' *)

  root : Fpath.t;   (** Root path in which this was found, e.g. /home/opam/.opam/4.10.0/lib *)
  dir : Fpath.t;    (** Containing dir path relative to root 'astring/' *)
  fname : Fpath.t;  (** Filename with extension. The full path is [root]/[dir]/[fname] *)
  outname : Fpath.t; (** Output filename *)
  outnamel : Fpath.t; (** Link output filename *)

  digest : Digest.t; (** Digest of the compilation unit itself *)
  package : string;  (** Package in which this file lives ("astring") *)
  deps : Odoc.compile_dep list; (** dependencies of this file *)
}

let pp fmt x =
  Format.fprintf fmt "@[<v 2>{ name: %s@,root: %a@,dir: %a@,fname: %a@,digest: %s@,package:%s }@]"
    x.name Fpath.pp x.root Fpath.pp x.dir Fpath.pp x.fname x.digest x.package

(** Returns the relative path to an odoc file based on an input file. For example, given
   `/home/opam/.opam/4.10.0/lib/ocaml/compiler-libs/lambda.cmi` it will return
   `odocs/ocaml/compiler-libs/lambda.odoc` *)
let compile_target t = Fpath.(v "odocs" // t.dir // set_ext "odoc" t.outname)

(** Like [compile_target] but goes into the "odocls" directory. *)
let link_target t = Fpath.(v "odocls" // t.dir // set_ext "odocl" t.outname)

(* Get info given a base file (cmt, cmti or cmi) *)
let get_cm_info root file =
  let deps = Odoc.compile_deps file in
  let relpath =
    match Fpath.relativize ~root file with
    | Some p -> p
    | None -> failwith "odd"
  in
  let dir, fname = Fpath.split_base relpath in
  let name = String.capitalize_ascii Fpath.(to_string (rem_ext fname)) in
  let outname = Fpath.set_ext "odoc" fname in
  let outnamel = Fpath.set_ext "odocl" fname in
  let package = package_of_relpath relpath in
  match List.partition (fun d -> d.Odoc.c_unit_name = name) deps with
  | [ self ], deps ->
      let digest = self.c_digest in
      let result = { root; name; dir; digest; deps; package; fname; outname; outnamel } in
      (* Format.eprintf "%a\n%!" pp result; *)
      [ result ]
  | _ ->
      Format.eprintf "Failed to find digest for self (%s)\n%!" name;
      []

let get_mld_info root file =
  let relpath =
    match Fpath.relativize ~root file with
    | Some p -> p
    | None -> failwith "odd"
  in
  let dir, fname = Fpath.split_base relpath in
  let name = Format.asprintf "page-%a" Fpath.pp (Fpath.rem_ext fname) in
  let package = package_of_relpath relpath in
  let outname = Fpath.add_ext "odoc" (Fpath.v name) in
  let outnamel = Fpath.add_ext "odocl" (Fpath.v name) in
  [ { root; name; dir; digest = ""; deps = []; package; fname; outname; outnamel } ]

let find_inputs ~whitelist roots =
  let roots = List.sort_uniq Fpath.compare roots in
  let infos =
    roots >>= fun root ->
    let files = find_files root in
    (get_cm_files files >>= get_cm_info root)
    @ (get_mld_files files >>= get_mld_info root)
  in
  if List.length whitelist > 0 then
    List.filter (fun info -> List.mem info.package whitelist) infos
  else infos
