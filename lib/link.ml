(* Generate the Makefile.<package>.link files *)

open Listm

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

let filter_by_package all_files package =
  let name =
    let n_str = Astring.String.cuts ~sep:"-" package in
    String.concat "_" n_str
  in
  List.filter (fun file ->
    match Fpath.(segs (normalize file)) with
    | "compile" :: "universes" :: _universe :: pkg :: _version :: _ :: _ when pkg = name -> true
    | "compile" :: "packages" :: pkg :: _version :: _ :: _ when pkg = name -> true
    | _ -> false) all_files

let filter_by_version all_files version =
  List.filter (fun file ->
    match Fpath.(segs (normalize file)) with
    | "compile" :: "universes" :: _universe :: _pkg :: version' :: _ :: _ when version = version' -> true
    | "compile" :: "packages" :: _pkg :: version' :: _ :: _ when version = version' -> true
    | _ -> false) all_files

let filter_by_universe all_files universe =
  List.filter (fun file ->
    match Fpath.(segs (normalize file)) with
    | "compile" :: "universes" :: universe' :: _pkg :: _version :: _ :: _ when Some universe' = universe -> true
    | "compile" :: "packages" :: _pkg :: _version' :: _ :: _ when universe = None -> true
    | _ -> false) all_files
    
    let get_dir f = fst (Fpath.split_base f)
  
let paths_of_package all_files (package,version,universe) =
  let package_files = filter_by_universe all_files universe in
  let package_files = filter_by_package package_files package in
  let package_files = filter_by_version package_files version in
  let dirs = List.map get_dir package_files in
  setify dirs

let run _toppath package =
    (* Find all odoc files, result is list of Fpath.t with no extension *) 
    let all_files = Inputs.find_files ["odoc"] Fpath.(v "compile") in

    let pkg_ver_files = filter_by_package all_files package in

    let versions = List.sort_uniq (fun v1 v2 -> String.compare v1 v2)
      (List.map
        (fun f ->
          match Fpath.segs f with
          | "compile" :: "universes" :: _ :: _pkg :: version :: _ -> version
          | "compile" :: "packages" :: _pkg :: version :: _ -> version
          | _ -> failwith "bad path")
        pkg_ver_files)
    in

    let package_makefile = Printf.sprintf "Makefile.%s.link" package in

    let oc = open_out package_makefile in

    let output_files_lists = List.map (fun version ->

      let pkg_files = filter_by_version pkg_ver_files version in
    (* get rid of hidden files *)
      let files = pkg_files >>= filter (fun f -> not (is_hidden f)) in

      Format.eprintf "Files under consideration: %d %a\n%!" (List.length files) (Format.pp_print_list Fpath.pp ) files;

      (* Find the set of directories that contain all of the files *)
      let dirs = Fpath.Set.of_list (List.map (fun f -> fst (Fpath.split_base f)) pkg_files) in

      Format.eprintf "Dirs under consideration: %d\n%!" (Fpath.Set.cardinal dirs);

      (* For each directory, use odoc to find the union of the set of packages each odoc file requires *)
      let odoc_deps = Fpath.Set.fold (fun dir acc -> Fpath.Map.add dir (Odoc.link_deps dir) acc) dirs Fpath.Map.empty in

      Format.eprintf "odoc_deps: %a\n%!"
        (Fpath.Map.pp (fun fmt (path,packages) -> Format.fprintf fmt "@[<v>dir: %a@,[@[<v>%a@]]@]" Fpath.pp path (Format.pp_print_list ~pp_sep:Format.pp_print_cut Odoc.pp_link_dep) packages)) odoc_deps;



      List.map (fun file ->
        (* The directory containing the odoc file *)
        let dir = fst (Fpath.split_base file) in

        (* Find the corresponding entry in the map of package dependencies odoc has calculated *)
        let deps = match Fpath.Map.find dir odoc_deps with Some x -> x | None -> failwith "odoc_deps" in

        (* Extract the packages and remove duplicates *)
        let dep_packages = setify @@ List.map (fun dep -> (dep.Odoc.l_package, dep.l_version, dep.l_universe)) deps in

        Format.eprintf "dep packages: [%s]\n%!" (String.concat "," (List.map (fun (p,v,u) -> Printf.sprintf "%s %s %s" p v (match u with Some u -> Printf.sprintf "(%s)" u | None -> "")) dep_packages));
        (* Find the directories that contain these packages - note the mapping of package -> 
          directory is one-to-many *)
        let dirs = setify @@ dep_packages >>= fun package -> paths_of_package all_files package in
        
        let output_file = match Fpath.segs file with
          | "compile" :: rest -> Fpath.(v (String.concat dir_sep ("link" :: rest)))
          | path :: _ -> Format.eprintf "odoc file unexpectedly found in path %s\n%!" path;
            exit 1
          | _ -> Format.eprintf "Something odd happening with the odoc paths\n%!";
            exit 1
        in
        let str =
          Format.asprintf "%a.odocl : %a.odoc\n\t@odoc link %a.odoc -o %a.odocl %s\nlink: %a.odocl\n%!"
            Fpath.pp output_file Fpath.pp file Fpath.pp file Fpath.pp output_file
            (String.concat " " (List.map (fun dir -> Format.asprintf "-I %a" Fpath.pp dir) dirs))
            Fpath.pp output_file
        in

      Printf.fprintf oc "%s" str;
      output_file
      ) files) versions in
    let all_output_files = List.concat output_files_lists in
    Printf.fprintf oc "Makefile.%s.generate: %s\n\todocmkgen generate --package %s\n" package (String.concat " " (List.map (fun f -> Fpath.(to_string (add_ext "odocl" f))) all_output_files)) package;
    Printf.fprintf oc "-include Makefile.%s.generate\n" package;
    close_out oc
    
