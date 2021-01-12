open Listm
open Util

(* Rules for compiling cm{t,ti,i} files into odoc files *)
let compile_fragment ~inputs_by_digest info =
  (* Get the filename of the output odoc file *)
  let odoc_path = Inputs.compile_target info in

  (* Find by digest the [source_info] for each dependency in our source_info record *)
  let deps =
    info.deps >>= fun dep ->
    try [ StringMap.find dep.Odoc.c_digest inputs_by_digest ]
    with Not_found ->
      Format.eprintf "Warning, couldn't find dep %s of file %a\n"
        dep.Odoc.c_unit_name Fpath.pp info.inppath;
      []
  in

  (* [--parent]. Must be added to the dependencies and search path (-I). *)
  let parent_page, parent_page_path =
    Inputs.index_page_name info.package,
    Inputs.index_page_odoc info.package
  in

  (* Get a list of odoc files for the dependencies *)
  let dep_odocs = parent_page_path :: List.map Inputs.compile_target deps in

  (* Odoc requires the directories in which to find the odoc files of the dependencies *)
  let include_args =
    List.map Fpath.parent dep_odocs
    |> List.sort_uniq Fpath.compare
    |> List.concat_map (fun dir -> [ "-I"; Fpath.to_string dir ])
  in

  let open Makefile in
  concat
    [
      rule odoc_path
        ~fdeps:(Inputs.input_file info :: dep_odocs)
        [
          cmd "odoc" $ "compile" $ "--parent" $ parent_page $ "$<"
          $$ include_args $ "-o" $ "$@";
        ];
      phony_rule ("compile-" ^ info.package) ~fdeps:[ odoc_path ] [];
    ]

let compile_package_page pkg inputs package_page =
  let open Makefile in
  let index_compiled = Inputs.index_page_odoc pkg in
  let childs = List.map Inputs.child_name inputs in
  let childs_args = List.flatten @@ List.map (fun c -> [ "-c"; c ]) childs in
  let index_mld, index_mld_rule =
    match package_page with
    | Some inp -> (inp.Inputs.inppath, concat [])
    | None ->
        (* Or generate one *)
        let target = Inputs.index_page_mld pkg in
        ( target,
          rule target
            [
              cmd "mkdir" $ "-p" $ "$(@D)";
              cmd ~stdout:"$@" "odocmkgen" $ "package-index" $ pkg $$ childs;
            ] )
  in
  concat
    [
      rule index_compiled ~fdeps:[ index_mld ]
        [
          cmd "odoc" $ "compile" $$ childs_args $ "$<"
          $ "-o" $ "$@";
        ];
      index_mld_rule;
      phony_rule ("compile-" ^ pkg) ~fdeps:[ index_compiled ] [];
    ]

(** Returns the optional package page and the remaining inputs *)
let split_package_page pkg inputs =
  let index_name = "page-" ^ pkg in
  let is_pkg_page inp = inp.Inputs.name = index_name in
  match List_util.find_remove is_pkg_page inputs with
  | Some (inputs', p) -> (Some p, inputs')
  | None -> (None, inputs)

let split_digest inputs =
  List.fold_left
    (fun acc inp -> StringMap.add inp.Inputs.digest inp acc)
    StringMap.empty inputs

let gen_package ~inputs_by_digest (package, inputs) =
  let open Makefile in
  let package_page, inputs = split_package_page package inputs in
  concat
    ( compile_package_page package inputs package_page
    :: List.map (compile_fragment ~inputs_by_digest) inputs )

let gen packages =
  let packages = StringMap.bindings packages in
  let inputs =
    List.fold_left (fun acc (_, inputs) -> inputs @ acc) [] packages
  in
  let inputs_by_digest = split_digest inputs in
  let package_rules_s = List.map (fun (pkg, _) -> "compile-" ^ pkg) packages in
  let open Makefile in
  concat
    [
      concat (List.map (gen_package ~inputs_by_digest) packages);
      phony_rule "compile" ~deps:package_rules_s [];
    ]
