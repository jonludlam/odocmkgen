open Listm

(** Represents necessary information about a particular cmi/cmti/cmt file *)
type source_info = {
  root : Fpath.t; (** Root path in which this was found *)
  name : string; (** 'Astring' *)
  dir : Fpath.t; (** full path to containing dir , e.g. /home/opam/.opam/4.10.0/lib/astring *)
  fname : Fpath.t; (* filename with extension *)
  digest : Digest.t;
  package : string; (* Package in which this file lives ("astring") *)
  deps : Odoc.compile_dep list; (** dependencies of this file *)
}

let package_of_relpath relpath =
  match Fpath.segs relpath with
  | pkg :: _ -> pkg
  | _ ->
    Format.eprintf "Invalid path, unable to determine package: %a\n%!" Fpath.pp relpath;
    failwith "Invalid path"

(* Given a base Fpath.t (a cmt, cmti or cmi, without extension), figure out the 'best' one - in order or preference
   cmti, cmt, cmi *)
let best_source_file base_path =
  let file_preference = List.map (fun ext -> Fpath.add_ext ext base_path) ["cmti"; "cmt"; "cmi"] in
  let exists s = try let (_ : Unix.stats) = Unix.stat (Fpath.to_string s) in true with _ -> false in
  List.find exists file_preference

(* Get info given a base file (cmt, cmti or cmi) *)
let get_info root mod_file =
  let best_file = best_source_file mod_file in
  let deps = Odoc.compile_deps best_file in
  let (_, lname) = Fpath.split_base mod_file in
  let name = String.capitalize_ascii (Fpath.to_string lname) in
  let relpath = match Fpath.relativize ~root best_file with Some p -> p | None -> failwith "odd" in
  let (dir, fname) = Fpath.split_base relpath in
  let package = package_of_relpath relpath in
  match List.partition (fun d -> d.Odoc.c_unit_name = name) deps with
  | [self], deps ->
    let digest = self.c_digest in
    [{root; name; dir; digest; deps; package; fname}]
  | _ ->
    Format.eprintf "Failed to find digest for self (%s)\n%!" name;
    []

(* Returns the relative path to an odoc file based on an input file. For example, given
   `/home/opam/.opam/4.10.0/lib/ocaml/compiler-libs/lambda.cmi` it will return
   `odocs/ocaml/compiler-libs/lambda.odoc` *)
let odoc_dir_of_info info =
  Fpath.(v "odocs" // info.dir )

let odoc_file_of_info info =
  Fpath.(odoc_dir_of_info info // set_ext "odoc" info.fname)
  
  

module StringSet = Set.Make(String)

(* Rules for compiling cm{t,ti,i} files into odoc files *)
let compile_fragment all_infos info =
  (* Get the filename of the output odoc file *)
  let odoc_path = odoc_file_of_info info in

  (* Find by digest the [source_info] for each dependency in our source_info record *)
  let deps =
    info.deps >>= fun dep ->
    try [ List.find (fun x -> x.digest = dep.Odoc.c_digest) all_infos ]
    with Not_found ->
      Format.eprintf "Warning, couldn't find dep %s of file %a\n" dep.Odoc.c_unit_name Fpath.pp (Fpath.(info.dir // info.fname));
      []
  in

  (* Get a list of odoc files for the dependencies *)
  let dep_odocs = List.map (fun info ->
    let odoc_file = odoc_file_of_info info in
    Fpath.to_string odoc_file) deps
  in

  (* Odoc requires the directories in which to find the odoc files of the dependencies *)
  let dep_dirs = Fpath.Set.of_list @@ List.map odoc_dir_of_info deps in
  let include_str = String.concat " " (Fpath.Set.fold (fun dep_dir acc -> ("-I " ^ Fpath.to_string dep_dir) :: acc ) dep_dirs []) in

  [ Format.asprintf "%a : %a %s" Fpath.pp odoc_path Fpath.pp Fpath.(info.root // info.dir // info.fname) (String.concat " " dep_odocs);
    Format.asprintf "\ttime odoc compile --package %s $< %s -o %a" info.package include_str Fpath.pp odoc_path;
    Format.asprintf "compile : %a" Fpath.pp odoc_path;
    Format.asprintf "Makefile.link : %a" Fpath.pp odoc_path ]

(* Rule for generating Makefile.<package>.link *)
let link_fragment all_infos =
  let packages = List.map (fun info -> info.package) all_infos |> setify in
  (* For each package, this rule is to generate a Makefile containing the runes to perform the link.
     It requires all of the package's files to have been compiled first. *)
  List.map (fun package ->
      let infos = List.filter (fun info -> info.package = package) all_infos in
      let odocs = String.concat " " (List.map (fun info -> odoc_file_of_info info |> Fpath.to_string) infos) in
      [ Format.asprintf "-include Makefile.%s.link" package;
        Format.asprintf "Makefile.%s.link: %s" package odocs;
        Format.asprintf "\t@odocmkgen link --package %s" package ]        
    ) packages

let run whitelist roots =
  let infos =
    roots >>= fun root ->
    Inputs.find_files ["cmi";"cmt";"cmti"] root
    >>= get_info root
  in
  let infos =
    if List.length whitelist > 0
    then List.filter (fun info -> List.mem info.package whitelist) infos
    else infos
  in
  let lines = List.concat (List.map (compile_fragment infos) infos) in
  let oc = open_out "Makefile.gen" in
  List.iter (fun line -> Printf.fprintf oc "%s\n" line) lines;
  let lines = List.concat (link_fragment infos) in
  List.iter (fun line -> Printf.fprintf oc "%s\n" line) lines;
  close_out oc;
  ()
