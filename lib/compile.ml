open Listm

(* Returns the relative path to an odoc file based on an input file. For example, given
   `/home/opam/.opam/4.10.0/lib/ocaml/compiler-libs/lambda.cmi` it will return
   `odocs/ocaml/compiler-libs/lambda.odoc` *)
let odoc_dir_of_info info =
  Fpath.(v "odocs" // info.Inputs.dir )

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
    try [ List.find (fun x -> x.Inputs.digest = dep.Odoc.c_digest) all_infos ]
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
  let packages = List.map (fun info -> info.Inputs.package) all_infos |> setify in
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
  let inputs = Inputs.find_inputs ~whitelist (roots @ docroots) in
  let oc = open_out "Makefile.gen" in
  let lines = List.concat (List.map (compile_fragment inputs) inputs) in
  List.iter (fun line -> Printf.fprintf oc "%s\n" line) lines;
  let lines = List.concat (link_fragment inputs) in
  List.iter (fun line -> Printf.fprintf oc "%s\n" line) lines;
  close_out oc;
  ()
