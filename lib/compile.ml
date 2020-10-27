open Listm

(** Represents necessary information about a particular cmi/cmti/cmt file *)
type source_info = {
  root : Fpath.t; (** Root path in which this was found *)
  name : string; (** 'Astring' *)
  dir : Fpath.t; (** full path to containing dir , e.g. /home/opam/.opam/4.10.0/lib/astring *)
  fname : Fpath.t; (* filename with extension *)
  digest : Digest.t;
  package : Opam.package; (* Package in which this file lives ("astring") *)
  deps : Odoc.compile_dep list; (** dependencies of this file *)
  blessed : bool;
  universe : Digest.t
}

type mldchild =
  | Mld of Fpath.t
  | CU of source_info

and mld = {
  mldname : string;
  dir: Fpath.t;
  mld: Fpath.t;
  odoc: Fpath.t;
  children : mldchild list;
  parent : Fpath.t option;
  title : string;
}

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
  let package_name = package_of_relpath relpath in
  try
    let package = Opam.find_package package_name in
    let universe = Opam.hashed_deps package in
    match List.partition (fun d -> d.Odoc.c_unit_name = name) deps with
    | [self], deps ->
      let digest = self.c_digest in
      [{root; name; dir; digest; deps; package; fname; universe; blessed=false}]
    | _ ->
      Format.eprintf "Failed to find digest for self (%s)\n%!" name;
      []
  with _ ->
    []

(* Returns the relative path to an odoc file based on an input file. For example, given
   `/home/opam/.opam/4.10.0/lib/ocaml/compiler-libs/lambda.cmi` it will return
   `odocs/ocaml/compiler-libs/lambda.odoc` *)
let pages = Hashtbl.create 100

let is_blessed info =
  info.universe = "d41d8cd98f00b204e9800998ecf8427e" && info.package.name = "ocaml" && info.package.version = "4.11.1"

let pp_mlchild fmt = function | CU _ -> Format.fprintf fmt "CU" | Mld p -> Format.fprintf fmt "%a" Fpath.pp p

let overall_basedir = Fpath.v "odocs"

let set_child parent child =
  let p = Hashtbl.find pages parent.mld in
  Format.eprintf "Setting parent: %a to have child: %a\n%!" Fpath.pp parent.mld pp_mlchild child;
  if not (List.mem child p.children)
  then Hashtbl.replace pages parent.mld {p with children = child :: p.children}
  else Format.eprintf "(skipping)\n%!"

let subdir_mld_odoc parent name =
  let f = Fpath.v (Printf.sprintf "%s.mld" name) in
  let basedir = match parent with
    | None -> overall_basedir
    | Some p -> p.dir
  in
  let mld = Fpath.(basedir // f) in
  let child =
    match Hashtbl.find_opt pages mld with
    | Some p -> p
    | None ->
      let p = 
        { mldname = name;
          dir = Fpath.(basedir // v name);
          mld;
          odoc = Fpath.(basedir // v (Printf.sprintf "page-%s.odoc" name));
          children = [];
          parent = (match parent with Some pparent -> Some pparent.mld | None -> None);
          title = "title" }
      in
      Hashtbl.replace pages mld p;
      p
  in
  match parent with
  | None -> child
  | Some pparent -> set_child pparent (Mld child.mld); child


let universes_page () = subdir_mld_odoc None "universes"
let packages_page () = subdir_mld_odoc None "packages"

let universe_page info =
  subdir_mld_odoc (Some (universes_page ())) info.universe


let package_page info =
  let blessed = is_blessed info in
  if blessed
  then subdir_mld_odoc (Some (packages_page ())) info.package.name
  else subdir_mld_odoc (Some (universe_page info)) info.package.name

let version_page info =
  let v_str = Astring.String.cuts ~sep:"." info.package.version in
  let v_str = String.concat "_" v_str in
  subdir_mld_odoc (Some (package_page info)) v_str

let odoc_file_of_info info =
  Fpath.((version_page info).dir // set_ext "odoc" info.fname)

module StringSet = Set.Make(String)


let parent_mld_fragment all_infos =
  List.iter (fun info ->
    let parent = version_page info in
    set_child parent (CU info)
  ) all_infos;
  let parent_file = Hashtbl.to_seq pages in
  let odocl_file trio =
    let file = Fpath.set_ext "odocl" trio.odoc in
    let segs = Fpath.segs file in
    let segs' = "odocls" :: List.tl segs in
    String.concat "/" segs'
  in
  let child_format mld fmt = function
  | CU info -> Format.fprintf fmt "echo \"{!child:%s}\" >> %a" info.name Fpath.pp mld.mld
  | Mld m ->
    let page = Hashtbl.find pages m in
    Format.fprintf fmt "echo \"{!child:%s}\" >> %a" page.mldname Fpath.pp mld.mld
  in
  let map_fn cur (_, mld) =
    let children = List.filter (function | Mld _ -> true | CU info -> not (is_hidden info.fname) ) mld.children in
    [ Format.asprintf "%a : %a %s" Fpath.pp mld.odoc Fpath.pp mld.mld (match mld.parent with | None -> "" | Some p -> let page = Hashtbl.find pages p in Format.asprintf "%a" Fpath.pp page.odoc);
      Format.asprintf "\todoc compile %a %a %s" Fpath.pp mld.mld (fun fmt -> function | None -> () | Some p -> let page = Hashtbl.find pages p in Format.fprintf fmt "--parent %a" Fpath.pp page.odoc) mld.parent
        (String.concat " " (List.map (function | Mld p -> let page = Hashtbl.find pages p in Format.asprintf "--child %s" page.mldname | CU p -> Format.asprintf "--child %s" (String.lowercase_ascii p.name)) children));
      Format.asprintf "%a :" Fpath.pp mld.mld;
      Format.asprintf "\tmkdir -p %a" Fpath.pp (fst (Fpath.split_base mld.mld));
      Format.asprintf "\techo \"{0 %s }\" > %a" mld.title Fpath.pp mld.mld;
      Format.asprintf "\t%a" (Format.pp_print_list ~pp_sep:(fun fmt () -> Format.fprintf fmt "; ") (child_format mld)) children;
      Format.asprintf "%s : %a %a" (odocl_file mld) Fpath.pp mld.odoc
        (Format.pp_print_list ~pp_sep:(fun fmt () -> Format.fprintf fmt " ") Fpath.pp) (List.map (function | Mld p -> let page = Hashtbl.find pages p in page.odoc | CU p -> odoc_file_of_info p) children);
      Format.asprintf "\todoc link %a -o %s %a" Fpath.pp mld.odoc (odocl_file mld)
        (Format.pp_print_list (fun fmt p -> Format.fprintf fmt "-I %a" Fpath.pp p)) (List.sort_uniq compare (List.map (fun p -> let p' = match p with Mld p -> let page = Hashtbl.find pages p in page.odoc | CU p -> odoc_file_of_info p in fst (Fpath.split_base p')) children));
      Format.asprintf "link: %s" (odocl_file mld)
        ] :: cur
    in
  Seq.fold_left map_fn [] parent_file |> List.concat



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

  let parent_trio = version_page info in
  let dep_odocs = Fpath.to_string parent_trio.odoc :: dep_odocs in

  (* Odoc requires the directories in which to find the odoc files of the dependencies *)
  let dep_dirs = Fpath.Set.of_list @@ List.map (fun i -> (version_page i).dir) deps in
  let include_str = String.concat " " (Fpath.Set.fold (fun dep_dir acc -> ("-I " ^ Fpath.to_string dep_dir) :: acc ) dep_dirs []) in

  [ Format.asprintf "%a : %a %s" Fpath.pp odoc_path Fpath.pp Fpath.(info.root // info.dir // info.fname) (String.concat " " dep_odocs);
    Format.asprintf "\t@odoc compile --parent %a $< %s -o %a" Fpath.pp parent_trio.odoc include_str Fpath.pp odoc_path;
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
      [ Format.asprintf "-include Makefile.%s.link" package.Opam.name;
        Format.asprintf "Makefile.%s.link: %s" package.name odocs;
        Format.asprintf "\t@odocmkgen link --package %s" package.name ]        
    ) packages

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
    List.filter (fun info -> try ignore (Opam.find_package info.package.name); true with _ -> false) infos
  in
  let lines = List.concat (List.map (compile_fragment infos) infos) in
  let oc = open_out "Makefile.gen" in
  List.iter (fun line -> Printf.fprintf oc "%s\n" line) lines;
  let lines = List.concat (link_fragment infos) in
  List.iter (fun line -> Printf.fprintf oc "%s\n" line) lines;
  let lines = parent_mld_fragment infos in
  List.iter (fun line -> Printf.fprintf oc "%s\n" line) lines;
  close_out oc;

  ()
