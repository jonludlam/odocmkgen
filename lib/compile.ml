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
  universe : Universe.t
}

let pp fmt s =
  Format.fprintf fmt "@[<v 2>{@,root: %a@,name: %s@,dir: %a@,fname: %a@,digest: %s@,package: %a@,deps: [%s]@,blessed: %b@,universe: %s@,}@]"
    Fpath.pp s.root s.name Fpath.pp s.dir Fpath.pp s.fname s.digest Opam.pp_package s.package (String.concat "," (List.map (fun o -> o.Odoc.c_unit_name) s.deps))
    s.blessed s.universe.id


  type mldchild =
  | Mld of Fpath.t
  | CU of source_info

type mldtype =
  | Packages
  | Universes
  | Universe of string
  | Package of string
  | Version

and mld = {
  mldname : string;
  dir: Fpath.t;
  mld: Fpath.t;
  odoc: Fpath.t;
  children : mldchild list;
  parent : Fpath.t option;
  ty : mldtype;
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

let universe_and_package_of_relpath relpath =
  match Fpath.segs relpath with
  | "universes" :: universe :: pkg :: _version :: _rest -> (universe, pkg)
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
let get_info universe package root mod_file =
  let fname = best_source_file mod_file in
  let deps = Odoc.compile_deps fname in
  let (_, lname) = Fpath.split_base mod_file in
  let name = String.capitalize_ascii (Fpath.to_string lname) in
  let dir = match Fpath.relativize ~root fname with Some p -> p | None -> failwith "odd" in
  try
    match List.partition (fun d -> d.Odoc.c_unit_name = name) deps with
    | self::_, deps ->
      let digest = self.c_digest in
      let (dir, fname) = Fpath.split_base dir in
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
  info.universe.id = "d41d8cd98f00b204e9800998ecf8427e" && info.package.name = "ocaml" && info.package.version = "4.11.1"

let pp_mlchild fmt = function | CU _ -> Format.fprintf fmt "CU" | Mld p -> Format.fprintf fmt "%a" Fpath.pp p

let overall_basedir = Fpath.v "compile"

let set_child parent child =
  let p = Hashtbl.find pages parent.mld in
  Format.eprintf "Setting parent: %a to have child: %a\n%!" Fpath.pp parent.mld pp_mlchild child;
  if not (List.mem child p.children)
  then Hashtbl.replace pages parent.mld {p with children = child :: p.children}
  else Format.eprintf "(skipping)\n%!"

let subdir_mld_odoc parent name ty =
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
          ty }
      in
      Hashtbl.replace pages mld p;
      p
  in
  match parent with
  | None -> child
  | Some pparent -> set_child pparent (Mld child.mld); child


let universes_page () = subdir_mld_odoc None "universes" Universes
let packages_page () = subdir_mld_odoc None "packages" Packages

let universe_page info =
  subdir_mld_odoc (Some (universes_page ())) info.universe.id (Universe info.universe.id)


let package_page info =
  let name =
    let n_str = Astring.String.cuts ~sep:"-" info.package.name in
    String.concat "_" n_str
  in

  let blessed = Universe.All.is_blessed info.package info.universe.id in
  if blessed
  then subdir_mld_odoc (Some (packages_page ())) name (Package info.package.name)
  else subdir_mld_odoc (Some (universe_page info)) name (Package info.package.name)

let version_page info =
  let v_str = Astring.String.cuts ~sep:"." info.package.version in
  let v_str = String.concat "_" v_str in
  subdir_mld_odoc (Some (package_page info)) v_str Version

let odoc_file_of_info info =
  Fpath.((version_page info).dir // set_ext "odoc" info.fname)

module StringSet = Set.Make(String)


let mld_contents mld =
  let child_format fmt = function
  | CU info -> Format.fprintf fmt "{!child:%s}\n" info.name
  | Mld m ->
    let page = Hashtbl.find pages m in
    Format.fprintf fmt "{!child:%s}\n" page.mldname
  in
  let children = List.filter (function | Mld _ -> true | CU info -> not (is_hidden info.fname) ) mld.children in
  match mld.ty with
  | Universes ->
    [ "{0 Universes}";
      "These universes are for those packages that are compiled against an alternative set of dependencies than those in the 'packages' hierarchy.";
      "" ] @
      List.map (fun child -> Format.asprintf "%a" child_format child) children
  | Universe id ->
    let universe = Universe.All.find_universe id in
    let packs = Universe.S.to_seq universe.Universe.packages in
    let lines = Seq.fold_left (fun lines package ->
      (Format.asprintf "%a" Opam.pp_package package)::lines) [] packs in
    [ Printf.sprintf "{0 Universe %s}" id;
      "{1 Contents}";
      "The following packages form this dependency universe:" ]
      @ lines @ [
      "{1 Packages}";
      "This dependency universe has been used to compile the following packages:"
      ] @ List.map (fun child -> Format.asprintf "%a" child_format child) children
  | Packages ->
    let name = function
      | CU info -> info.name
      | Mld m ->
        let page = Hashtbl.find pages m in
        page.mldname
    in
    let interpose_alphabet packages =
      let alpha_heading name =
        Printf.sprintf "{2 %c}" (Char.uppercase_ascii name.[0])
      in
      
      let rec inner ps =
        match ps with
        | a :: b :: rest ->
          let na = name a in
          let nb = name b in
          if na.[0] <> nb.[0]
          then Format.asprintf "%a" child_format a :: (alpha_heading nb) :: inner (b :: rest)
          else Format.asprintf "%a" child_format a :: (inner (b :: rest))
        | [a] ->
          [Format.asprintf "%a" child_format a]
        | [] ->
          []
      in
      let first = List.hd packages in
      (alpha_heading (name first)) :: inner packages
    in
    
    [ "{0 Packages}" ] @ interpose_alphabet (List.sort (fun c1 c2 -> String.compare (name c1) (name c2)) children)
  | Package p -> [
    Printf.sprintf "{0 Package '%s'}" p;
    "{1 Versions}"
  ] @ List.map (fun child -> Format.asprintf "%a" child_format child) children
  | Version -> [
    "{0 Modules}"
  ] @ List.map (fun child -> Format.asprintf "%a" child_format child) children
    

let parent_mld_fragment all_infos =
  List.iter (fun info ->
    let parent = version_page info in
    set_child parent (CU info)
  ) all_infos;
  let parent_file = Hashtbl.to_seq pages in
  let odocl_file trio =
    Fpath.set_ext "odocl" trio.odoc
  in
  let map_fn cur (_, mld) =
    let children = List.filter (function | Mld _ -> true | CU info -> not (is_hidden info.fname) ) mld.children in
    let (path,_) = Fpath.split_base mld.mld in
    Util.mkdir_p path;
    let oc = open_out (Fpath.to_string mld.mld) in
    let fmt = Format.formatter_of_out_channel oc in
    Format.fprintf fmt "%s\n%!" (String.concat "\n" (mld_contents mld));
    close_out oc;

    [ Format.asprintf "%a : %a %s" Fpath.pp mld.odoc Fpath.pp mld.mld (match mld.parent with | None -> "" | Some p -> let page = Hashtbl.find pages p in Format.asprintf "%a" Fpath.pp page.odoc);
      Format.asprintf "\todoc compile %a %a %s" Fpath.pp mld.mld (fun fmt -> function | None -> () | Some p -> let page = Hashtbl.find pages p in Format.fprintf fmt "--parent %a" Fpath.pp page.odoc) mld.parent
        (String.concat " " (List.map (function | Mld p -> let page = Hashtbl.find pages p in Format.asprintf "--child %s" page.mldname | CU p -> Format.asprintf "--child %s" (String.lowercase_ascii p.name)) children));
      Format.asprintf "%a : %a %a" Fpath.pp (odocl_file mld) Fpath.pp mld.odoc
        (Format.pp_print_list ~pp_sep:(fun fmt () -> Format.fprintf fmt " ") Fpath.pp)
        (List.map (function
          | Mld p -> let page = Hashtbl.find pages p in page.odoc
          | CU p -> odoc_file_of_info p) children);
      Format.asprintf "\todoc link %a -o %a %a" Fpath.pp mld.odoc Fpath.pp (odocl_file mld)
        (Format.pp_print_list (fun fmt p -> Format.fprintf fmt "-I %a" Fpath.pp p)) (List.sort_uniq compare (List.map (fun p -> let p' = match p with Mld p -> let page = Hashtbl.find pages p in page.odoc | CU p -> odoc_file_of_info p in fst (Fpath.split_base p')) children));
      Format.asprintf "link: %a" Fpath.pp (odocl_file mld)
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
    try [ List.find (fun x -> x.digest = dep.Odoc.c_digest && Universe.S.subset x.universe.packages info.universe.packages) all_infos ]
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
    Format.asprintf "\todoc compile --parent %a $< %s -o %a" Fpath.pp parent_trio.odoc include_str Fpath.pp odoc_path;
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
        Format.asprintf "\todocmkgen link --package %s" package.name ]        
    ) packages

let universe_path id =
  Fpath.(v "prep" / "universes" / id)

let packages_path id =
  Fpath.(universe_path id // v "packages.usexp")
  
let read_universe id =
  let universe = Universe.load (packages_path id) in
  Inputs.(contents (universe_path id) >>= filter is_dir) >>= fun package_path ->
  Inputs.(contents package_path >>= filter is_dir) >>= fun version_path ->
  let package = Opam.load (Fpath.(version_path / "package.psexp")) in
  Inputs.find_files ["cmi";"cmt";"cmti"] version_path
  >>= get_info universe package version_path





let run _whitelist _roots =
  Universe.All.init ();
  let infos = Inputs.contents Fpath.(v "prep" / "universes") >>= fun universe_fpath ->
    match Fpath.segs universe_fpath with
    | ["prep"; "universes"; id] ->
      read_universe id
    | _ -> []
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
