open Listm

(** The name and optional digest of a dependency. Modules compiled with --no-alias-deps don't have
    digests for purely aliased modules *)
type t = {
  dep_unit_name : string;
  dep_digest : Digest.t option;
}


(** Represents necessary information about a particular cmi/cmti/cmt file *)
type source_info = {
  path : Fpath.t; (** Full path with the extension, e.g. /home/opam/.opam/4.10.0/lib/astring/astring.cmti *)
  name : string; (** 'Astring' *)
  dir : Fpath.t; (** /home/opam/.opam/4.10.0/lib/astring *)
  digest : Digest.t;
  deps : t list; (** dependencies of this file *)
}


let add_dep acc = function
| dep_unit_name, None -> { dep_unit_name; dep_digest = None } :: acc
| dep_unit_name, Some dep_digest ->  { dep_unit_name; dep_digest = Some dep_digest } :: acc


let get_cmt_info path =
  let dir = Fpath.split_base path |> fst in
  let cmt_infos = Cmt_format.read_cmt (Fpath.to_string path) in
  let deps = List.fold_left add_dep [] cmt_infos.Cmt_format.cmt_imports in
  let name = cmt_infos.Cmt_format.cmt_modname in
  let deps = List.filter (fun dep -> dep.dep_unit_name <> name) deps in
  match cmt_infos.Cmt_format.cmt_interface_digest with
  | Some digest ->
    [{path; name; dir; digest; deps}]
  | None ->
    []

let get_cmi_or_cmti_info path =
  let dir = Fpath.split_base path |> fst in
  let cmi_infos = Cmi_format.read_cmi (Fpath.to_string path) in
  let deps = List.fold_left add_dep [] cmi_infos.Cmi_format.cmi_crcs in
  match cmi_infos.cmi_crcs with
  | (name, Some digest) :: _imports when name = cmi_infos.cmi_name ->
    let deps = List.filter (fun dep -> dep.dep_unit_name <> name) deps in
    [{path; name; dir; digest; deps}]
  | _ -> []

(* Given a base file (a cmt, cmti or cmi), figure out the 'best' one - in order or preference
   cmti, cmt, cmi *)
let best_source_file base_path =
  let file_preference = List.map (fun ext -> Fpath.add_ext ext base_path) ["cmti"; "cmt"; "cmi"] in
  let exists s = try let (_ : Unix.stats) = Unix.stat (Fpath.to_string s) in true with _ -> false in
  List.find exists file_preference

(* Get info given a base file (cmt, cmti or cmi) *)
let get_info mod_file =
  let best_file = best_source_file mod_file in
  let is_cmt = Fpath.has_ext "cmt" best_file in
  if is_cmt
  then get_cmt_info best_file
  else get_cmi_or_cmti_info best_file

(* Returns the relative path to an odoc file based on an input file. For example, given
   `/home/opam/.opam/4.10.0/lib/ocaml/compiler-libs/lambda.cmi` it will return
   `ocaml/compiler-libs/lambda.odoc` *)
let odoc_file_of_source_file root source_file =
  match Fpath.set_ext "odoc" source_file |> Fpath.relativize ~root with | Some x -> x | None -> failwith "odd"

module StringSet = Set.Make(String)


let makefile_fragment root all_infos info =
  (* Get the odoc base path *)
  let odoc_base_path = odoc_file_of_source_file root info.path in

  (* We want all the output odoc files to be written under the path `odocs`, so prepend that *)
  let odoc_path = Fpath.(v "odocs" // odoc_base_path) in

  (* Find by digest the [source_info] for each dependency in our source_info record, ignoring dependencies for which there is no digest available *)
  let deps = info.deps >>= fun dep -> match dep.dep_digest with | None -> [] | Some digest -> [List.find (fun x -> x.digest = digest) all_infos] in

  let dep_odocs = List.map (fun info ->
    let base_path = odoc_file_of_source_file root info.path in
    let odoc_file = Fpath.(v "odocs" // base_path) in
    Fpath.to_string odoc_file) deps in
  let dep_dirs = List.map (fun dep -> dep.dir, Fpath.relativize ~root dep.dir) deps >>= function | _, Some x -> [x] | d, None -> Format.eprintf "Failed to relativize %a\n%!" Fpath.pp d; [] in
  let dep_dirs = Fpath.Set.of_list dep_dirs in
  let package = Fpath.segs odoc_base_path |> List.hd in
  let include_str = String.concat " " (Fpath.Set.fold (fun dep_dir acc -> ("-I odocs/" ^ Fpath.to_string dep_dir) :: acc ) dep_dirs []) in
  Format.printf "%a : %a %s\n" Fpath.pp odoc_path Fpath.pp info.path (String.concat " " dep_odocs);
  Format.printf "\todoc compile --package %s $< %s -o %a\n" package include_str Fpath.pp odoc_path;
  Format.printf "compile : %a\n" Fpath.pp odoc_path

let run root =
  let files = Inputs.find_files ["cmi";"cmt";"cmti"] root in 
  let infos = files >>= get_info in
  List.iter (makefile_fragment root infos) infos;
  ()
