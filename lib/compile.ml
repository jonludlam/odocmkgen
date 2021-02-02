(** Rules for compiling cm{t,ti,i} files into odoc files *)
let compile_input ~compile_deps ~parent_childs ~parent target input =
  let deps = Fpath.Map.get input.Inputs.reloutpath compile_deps in
  let parent_args, parent_inp =
    match parent with
    | Some p -> ([ "--parent"; p.Inputs.name ], [ p ])
    | None -> ([], [])
  in
  let child_args =
    (* --child args. Computed by {!Inputs.find_parent_childs}. *)
    Fpath.Map.find input.Inputs.reloutpath parent_childs
    |> Option.value ~default:[]
    |> List.concat_map (fun c -> [ "--child"; c.Inputs.name ])
  in
  (* Add the parent page to dependencies *)
  let deps_odoc = List.map Inputs.compile_target (parent_inp @ deps) in
  let include_args =
    (* Include directories, sorted for reproducibility *)
    List.map Fpath.parent deps_odoc
    |> List.sort_uniq Fpath.compare
    |> List.concat_map (fun dir -> [ "-I"; Fpath.to_string dir ])
  in
  let open Makefile in
  concat
    [
      rule [ target ]
        ~fdeps:(Inputs.input_file input :: deps_odoc)
        [
          cmd "odoc" $ "compile" $$ parent_args $$ child_args $ "$<"
          $$ include_args $ "-o" $ "$@";
        ];
    ]

(** Compile a group of inputs that are in the same directory. *)
let compile_group ~compile_deps ~parent_childs acc (tree : Inputs.tree) =
  let compile_targets = List.map Inputs.compile_target tree.inputs in
  let open Makefile in
  concat
    [
      acc;
      concat
        (List.map2
           (compile_input ~compile_deps ~parent_childs ~parent:tree.parent_page)
           compile_targets tree.inputs);
      phony_rule (Inputs.compile_rule tree) ~fdeps:compile_targets [];
    ]

(** There is one per directory. *)
let find_compile_rules tree =
  Inputs.fold_tree (fun acc tree -> Inputs.compile_rule tree :: acc) [] tree
  |> List.sort_uniq String.compare

let gen ~compile_deps tree =
  let parent_childs = Inputs.find_parent_childs tree in
  let open Makefile in
  concat
    [
      Inputs.fold_tree
        (compile_group ~compile_deps ~parent_childs)
        (concat []) tree;
      phony_rule "compile" ~deps:(find_compile_rules tree) [];
    ]
