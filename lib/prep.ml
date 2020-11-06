(* Prep *)

open Listm

(* This module prepares a directory structure for making documentation.Lift_let_to_initialize_symbol

  We go through all the installed cm{t,ti,i}s and find which package/version they are from. We then
  query opam to find out their dependencies. Then we copy the files into the following structure:
  
  prep/universes/<hash>/<package>/<version>/ocaml/... 
  
  *)

type source_info = {
  root : Fpath.t; (** Root path in which this was found *)
  file : Fpath.t; (** Original file *)
  name : string; (** 'Astring' *)
  dir : Fpath.t; (** relative dir below package path *)
  fname : Fpath.t; (* filename with extension *)
  package : Opam.package; (* Package in which this file lives ("astring") *)
  universe : Universe.t
}
let top_path = Fpath.v "prep"


(* Given a base Fpath.t (a cmt, cmti or cmi, without extension), figure out the 'best' one - in order or preference
   cmti, cmt, cmi *)

  
let is_hidden x =
  let is_hidden s =
    let len = String.length s in
    let rec aux i =
        if i > len - 2 then false else
        if s.[i] = '_' && s.[i + 1] = '_' then true
        else aux (i + 1)
    in aux 0
  in
  is_hidden (Fpath.basename x)

let package_of_relpath relpath =
  match Fpath.segs relpath with
  | pkg :: rest -> pkg, Fpath.split_base (Fpath.v (String.concat Fpath.dir_sep rest))
  | _ ->
    Format.eprintf "Invalid path, unable to determine package: %a\n%!" Fpath.pp relpath;
    failwith "Invalid path"

   let best_source_file base_path =
    let file_preference = List.map (fun ext -> Fpath.add_ext ext base_path) ["cmti"; "cmt"; "cmi"] in
    let exists s = try let (_ : Unix.stats) = Unix.stat (Fpath.to_string s) in true with _ -> false in
    List.find exists file_preference
  
  (* Get info given a base file (cmt, cmti or cmi) *)
  let get_info root mod_file =
    let file = best_source_file mod_file in
    let (_, lname) = Fpath.split_base mod_file in
    let name = String.capitalize_ascii (Fpath.to_string lname) in
    let relpath = match Fpath.relativize ~root file with Some p -> p | None -> failwith "odd" in
    let package_name, (dir, fname) = package_of_relpath relpath in
    try
      let dep_universe = Universe.Current.dep_universe package_name in
      let (package, universe) = dep_universe in
      [{root; file; name; dir; package; fname; universe}]
    with _ ->
      []

let run whitelist roots =
  let infos =
    roots >>= fun root ->
    Inputs.find_files ["cmi";"cmt";"cmti"] root
    >>= get_info root
  in
  let infos =
    if List.length whitelist > 0
    then List.filter (fun info -> List.mem info.package.name whitelist) infos
    else infos
  in
  let infos =
    List.filter (fun info -> try ignore (Universe.Current.dep_universe info.package.name); true with _ -> Format.eprintf "pruning %a\n%!" Fpath.pp info.file; false) infos
  in
  let copy info =
    let v_str = Astring.String.cuts ~sep:"." info.package.version in
    let v_str = String.concat "_" v_str in
    let dest_dir = Fpath.(top_path / "universes" / info.universe.id / info.package.name / v_str // info.dir ) in
    Util.mkdir_p dest_dir;
    Util.cp (Format.asprintf "%a" Fpath.pp info.file) (Format.asprintf "%a/%a" Fpath.pp dest_dir Fpath.pp info.fname)
  in
  List.iter copy infos;
  Universe.Current.save top_path
