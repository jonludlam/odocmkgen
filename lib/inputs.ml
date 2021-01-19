open Listm
open Util

let filter pred item = if pred item then [item] else []

let has_ext exts f =
  List.exists (fun suffix -> Fpath.has_ext suffix f) exts

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
let compile_target t = Fpath.(v "odocs" // set_ext "odoc" t.reloutpath)

(** Like [compile_target] but goes into the "odocls" directory. *)
let link_target t = Fpath.(v "odocls" // set_ext "odocl" t.reloutpath)

(* Get info given a base file (cmt, cmti or cmi) *)
let get_cm_info root inppath =
  let deps = Odoc.compile_deps inppath in
  let package = Fpath.(basename (parent inppath)) in
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

let get_mld_info root inppath =
  let package = Fpath.(basename (parent inppath)) in
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

let find_inputs root =
  let files = Fs_util.dir_contents_rec root in
  (get_cm_files files >>= get_cm_info root)
  @ (get_mld_files files >>= get_mld_info root)

let split_packages inputs =
  let f inp = function Some lst -> Some (inp :: lst) | None -> Some [ inp ] in
  List.fold_left
    (fun acc (({ package; _ }, _) as inp) ->
      StringMap.update package (f inp) acc)
    StringMap.empty inputs

module DigestMap = Map.Make (Digest)

(** Compute direct compile-dependencies for a list of inputs.
    Returns the list of inputs paired with its dependencies. *)
let compile_deps inputs =
  let inputs_by_digest =
    List.fold_left
      (fun acc inp -> DigestMap.add inp.digest inp acc)
      DigestMap.empty inputs
  in
  let find_dep inp dep =
    match DigestMap.find_opt dep.Odoc.c_digest inputs_by_digest with
    | Some _ as x -> x
    | None ->
        Format.eprintf "Warning, couldn't find dep %s of file %a\n"
          dep.Odoc.c_unit_name Fpath.pp inp.inppath;
        None
  in
  let find_deps inp = List.filter_map (find_dep inp) inp.deps in
  List.map (fun inp -> (inp, find_deps inp)) inputs
