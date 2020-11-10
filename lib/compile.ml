open Listm

(** [odoc_info] represents the necessary information about a particular cmi/cmti/cmt file *)
type odoc_info = {
  name : string; (** 'Astring' *)

  root : Fpath.t;   (** Root path in which this was found, e.g. /home/opam/.opam/4.10.0/lib *)
  dir : Fpath.t;    (** Containing dir path relative to root 'astring/' *)
  fname : Fpath.t;  (** Filename with extension. The full path is [root]/[dir]/[fname] *)
  outname : Fpath.t; (** Output filename *)

  digest : Digest.t; (** Digest of the compilation unit itself *)
  package : string;  (** Package in which this file lives ("astring") *)
  deps : Odoc.compile_dep list; (** dependencies of this file *)
}

let pp fmt x =
  Format.fprintf fmt "@[<v 2>{ name: %s@,root: %a@,dir: %a@,fname: %a@,digest: %s@,package:%s }@]"
    x.name Fpath.pp x.root Fpath.pp x.dir Fpath.pp x.fname x.digest x.package


(* This assumes that the directory immediately below the 'root' is the name of the package.
   Note that for some older packages this is not always true (e.g. ocamlfind, oasis).
   Be warned! *)
let package_of_relpath relpath =
  match Fpath.segs relpath with
  | pkg :: _ -> pkg
  | _ ->
    Format.eprintf "Invalid path, unable to determine package: %a\n%!" Fpath.pp relpath;
    failwith "Invalid path"

(* Get info given a base file (cmt, cmti or cmi) *)
let get_info root mod_file =

  (* Given the choice between a cmti, a cmt and a cmi file, we chose them in that order of
     preference *)
  let best_source_file base_path =
    let file_preference = List.map (fun ext -> Fpath.add_ext ext base_path) ["cmti"; "cmt"; "cmi"] in
    let exists s = try let (_ : Unix.stats) = Unix.stat (Fpath.to_string s) in true with _ -> false in
    List.find exists file_preference
  in

  let best_file = best_source_file mod_file in
  let deps = Odoc.compile_deps best_file in
  let (_, lname) = Fpath.split_base mod_file in
  let name = String.capitalize_ascii (Fpath.to_string lname) in
  let relpath = match Fpath.relativize ~root best_file with Some p -> p | None -> failwith "odd" in
  let (dir, fname) = Fpath.split_base relpath in
  let outname = Fpath.set_ext "odoc" fname in
  let package = package_of_relpath relpath in
  match List.partition (fun d -> d.Odoc.c_unit_name = name) deps with
  | [self], deps ->
    let digest = self.c_digest in
    let result = {root; name; dir; digest; deps; package; fname; outname } in
    (* Format.eprintf "%a\n%!" pp result; *)
    [result]
  | _ ->
    Format.eprintf "Failed to find digest for self (%s)\n%!" name;
    []


let get_mld_info root mld_file =
  let file = Fpath.add_ext "mld" mld_file in
  let (_, lname) = Fpath.split_base mld_file in
  let name = Format.asprintf "page-%a" Fpath.pp lname in
  let relpath = match Fpath.relativize ~root file with Some p -> p | None -> failwith "odd" in
  let (dir, fname) = Fpath.split_base relpath in
  let package = package_of_relpath relpath in
  let outname = Fpath.set_ext "odoc" (Fpath.v ("page-" ^ Fpath.to_string fname)) in
  [{root; name; dir; digest=""; deps=[]; package; fname; outname}]

(* Returns the relative path to an odoc file based on an input file. For example, given
   `/home/opam/.opam/4.10.0/lib/ocaml/compiler-libs/lambda.cmi` it will return
   `odocs/ocaml/compiler-libs/lambda.odoc` *)
let odoc_dir_of_info info =
  Fpath.(v "odocs" // info.dir )

let odoc_file_of_info info =
  Fpath.(odoc_dir_of_info info // set_ext "odoc" info.outname)
  
  

module StringSet = Set.Make(String)

(* Rules for compiling cm{t,ti,i} files into odoc files *)
let compile_fragment all_infos info =
  (* Get the filename of the output odoc file *)
  let odoc_path = odoc_file_of_info info in

  let odoc_path_result = Fpath.segs odoc_path |> List.filter (fun x -> x <> "odoc-pages") |> String.concat "/" |> Fpath.of_string in
  let odoc_path = match odoc_path_result with | Ok r -> r | _ -> failwith "error" in

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
    Format.asprintf "\t@odoc compile --package %s $< %s -o %a" info.package include_str Fpath.pp odoc_path;
    Format.asprintf "compile : %a" Fpath.pp odoc_path;
    Format.asprintf "Makefile.%s.link : %a" info.package Fpath.pp odoc_path ]

(* Rule for generating Makefile.<package>.link *)
let link_fragment all_infos =
  let packages = List.map (fun info -> info.package) all_infos |> setify in
  (* For each package, this rule is to generate a Makefile containing the runes to perform the link.
     It requires all of the package's files to have been compiled first. *)
  List.map (fun package ->
      [ Format.asprintf "ifneq ($(MAKECMDGOALS),compile)";
        Format.asprintf "-include Makefile.%s.link" package;
        Format.asprintf "endif";
        Format.asprintf "Makefile.%s.link:" package;
        Format.asprintf "\t@odocmkgen link --package %s" package ]        
    ) packages

let run whitelist roots docroots =
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
  let mlds =
    docroots >>= fun root ->
    Inputs.find_files ["mld"] root
    >>= get_mld_info root
  in
  let oc = open_out "Makefile.gen" in
  let lines = List.concat (List.map (compile_fragment infos) infos) in
  List.iter (fun line -> Printf.fprintf oc "%s\n" line) lines;
  let lines = List.concat (List.map (compile_fragment infos) mlds) in
  List.iter (fun line -> Printf.fprintf oc "%s\n" line) lines;
  let lines = List.concat (link_fragment infos) in
  List.iter (fun line -> Printf.fprintf oc "%s\n" line) lines;
  close_out oc;
  ()
