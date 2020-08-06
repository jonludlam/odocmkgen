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
  List.filter (fun file ->
    match Fpath.(segs (normalize file)) with
    | "odocs" :: pkg :: _ when pkg = package -> true
    | _ -> false) all_files

let get_dir f = fst (Fpath.split_base f)
  
let paths_of_package all_files package =
  let package_files = filter_by_package all_files package in
  let dirs = List.map get_dir package_files in
  setify dirs

let run toppath package =
    (* Find all odoc files, result is list of Fpath.t with no extension *)
    let all_files = Inputs.find_files ["odoc"] toppath in

    let pkg_files = filter_by_package all_files package in 

    (* get rid of hidden files *)
    let files = pkg_files >>= filter (fun f -> not (is_hidden f)) in

    (* Find the set of directories that contain all of the files *)
    let dirs = Fpath.Set.of_list (List.map (fun f -> fst (Fpath.split_base f)) pkg_files) in

    (* For each directory, use odoc to find the union of the set of packages each odoc file requires *)
    let odoc_deps = Fpath.Set.fold (fun dir acc -> Fpath.Map.add dir (Odoc.link_deps dir) acc) dirs Fpath.Map.empty in

    let package_makefile = Printf.sprintf "Makefile.%s.link" package in

    let oc = open_out package_makefile in

    let output_files = List.map (fun file ->
      (* The directory containing the odoc file *)
      let dir = fst (Fpath.split_base file) in

      (* Find the corresponding entry in the map of package dependencies odoc has calculated *)
      let deps = Option.get @@ Fpath.Map.find dir odoc_deps in

      (* Extract the packages and remove duplicates *)
      let dep_packages = setify @@ List.map (fun dep -> dep.Odoc.l_package) deps in

      (* Find the directories that contain these packages - note the mapping of package -> 
         directory is one-to-many *)
      let dirs = setify @@ dep_packages >>= fun package -> paths_of_package all_files package in
      
      let output_file = match Fpath.segs file with
        | "odocs" :: rest -> Fpath.(v (String.concat dir_sep ("odocls" :: rest)))
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
      ) files in
    Printf.fprintf oc "Makefile.%s.generate: %s\n\todocmkgen generate --package %s\n" package (String.concat " " (List.map (fun f -> Fpath.(to_string (add_ext "odocl" f))) output_files)) package;
    Printf.fprintf oc "-include Makefile.%s.generate\n" package;
    close_out oc
    