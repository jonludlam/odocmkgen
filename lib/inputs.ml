open Listm

let dir_contents dir =
  Sys.readdir (Fpath.to_string dir)
  |> Array.map (Fpath.( / ) dir)
  |> Array.to_list

let filter pred item = if pred item then [item] else []

let is_dir x = Sys.is_directory (Fpath.to_string x)

let dir_exists x =
  let p = Fpath.to_string x in
  Sys.file_exists p && Sys.is_directory p

let has_ext exts f =
  List.exists (fun suffix -> Fpath.has_ext suffix f) exts

let rec find_files base_dir =
  let items = dir_contents base_dir in
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

(** Name of the index page of a package, for [--parent]. *)
let index_page_name pkg = "page-" ^ pkg

let index_page_mld pkg = Fpath.(v "odocs" / pkg / (pkg ^ ".mld"))

let index_page_odoc pkg =
  Fpath.(v "odocs" / pkg / (index_page_name pkg ^ ".odoc"))

(** Represents the necessary information about a particular compilation unit *)
type t = {
  name : string;  (** 'Astring' *)
  inppath : Fpath.t;  (** Path to the input file, contains [root]. *)
  root : Fpath.t;
      (** Root path in which this was found, e.g. /home/opam/.opam/4.10.0/lib/package_name *)
  reloutpath : Fpath.t;
      (** Relative path to use for output, extension is the same as [inppath].
          May not correspond to a input file in [root]. *)
  digest : Digest.t;  (** Digest of the compilation unit itself *)
  package : string;  (** Package in which this file lives ("astring") *)
  deps : Odoc.compile_dep list;  (** dependencies of this file *)
}

let pp fmt x =
  Format.fprintf fmt "@[<v 2>{ name: %s@,root: %a@,path: %a@,digest: %s@,package:%s }@]"
    x.name Fpath.pp x.root Fpath.pp x.inppath x.digest x.package

let input_file t = t.inppath

(** Returns the relative path to an odoc file based on an input file. For example, given
   `/home/opam/.opam/4.10.0/lib/ocaml/compiler-libs/lambda.cmi` it will return
   `odocs/ocaml/compiler-libs/lambda.odoc` *)
let compile_target t = Fpath.(v "odocs" / t.package // set_ext "odoc" t.reloutpath)

(** Like [compile_target] but goes into the "odocls" directory. *)
let link_target t = Fpath.(v "odocls" / t.package // set_ext "odocl" t.reloutpath)

(* Get info given a base file (cmt, cmti or cmi) *)
let get_cm_info ~package root inppath =
  let deps = Odoc.compile_deps inppath in
  let reloutpath =
    match Fpath.relativize ~root inppath with
    | Some p -> p
    | None -> failwith "odd"
  in
  let fname = Fpath.base reloutpath in
  let name = String.capitalize_ascii Fpath.(to_string (rem_ext fname)) in
  match List.partition (fun d -> d.Odoc.c_unit_name = name) deps with
  | [ self ], deps ->
      let digest = self.c_digest in
      [ { name; inppath; root; reloutpath; digest; package; deps } ]
  | _ ->
      Format.eprintf "Failed to find digest for self (%s)\n%!" name;
      []

let get_mld_info ~package root inppath =
  let relpath =
    match Fpath.relativize ~root inppath with
    | Some p -> p
    | None -> failwith "odd"
  in
  let fparent, fname = Fpath.split_base relpath in
  (* Prefix name and output file name with "page-" *)
  let outfname = Fpath.v ("page-" ^ Fpath.to_string fname) in
  let name = Fpath.to_string (Fpath.rem_ext outfname) in
  let reloutpath = Fpath.append fparent outfname in
  [ { name; inppath; root; reloutpath; digest = ""; deps = []; package } ]

(** Expect paths like [prefix/lib/package] or [prefix/lib/package/sub_dir].
    These paths are used in Opam and in Dune's _build/install.
    In case the [lib] part cannot be found in the last two parents, returns
    [None]. Also return the [prefix] part, that can be used to look for
    [prefix/doc] for example. *)
let package_of_path path =
  let parent = Fpath.parent path in
  let grand_parent = Fpath.parent parent in
  if Fpath.basename parent = "lib" then Some (Fpath.basename path, grand_parent)
  else if Fpath.basename grand_parent = "lib" then
    Some (Fpath.basename parent, Fpath.parent grand_parent)
  else None

let find_inputs ~whitelist roots =
  let roots = List.sort_uniq Fpath.compare roots in
  (* Several paths can be part of the same package, avoid dupplicated doc_dir. *)
  let visited_doc_dirs = ref Fpath.Set.empty in
  let infos =
    roots >>= fun root ->
    let files = dir_contents root in
    let package, prefix =
      match package_of_path root with
      | Some x -> x
      | None ->
          (* In case [root] is not recognized as a package, use the basename
             instead. This may be wrong sometimes. *)
          (Fpath.basename root, Fpath.parent root)
    in
    let doc_inputs =
      (* This directory may not exist *)
      let doc_dir = Fpath.(prefix / "doc" / package) in
      if (not (Fpath.Set.mem doc_dir !visited_doc_dirs)) && dir_exists doc_dir
      then (
        visited_doc_dirs := Fpath.Set.add doc_dir !visited_doc_dirs;
        (* [doc_dir] also contains [README.md], [CHANGES.md] and other common
           files installed by Dune, which we ignore here. *)
        get_mld_files (find_files doc_dir) >>= get_mld_info ~package doc_dir )
      else []
    in
    (get_cm_files files >>= get_cm_info ~package root) @ doc_inputs
  in
  if List.length whitelist > 0 then
    List.filter (fun info -> List.mem info.package whitelist) infos
  else infos
