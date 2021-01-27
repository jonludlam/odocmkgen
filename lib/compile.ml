(** Rules for compiling cm{t,ti,i} files into odoc files *)
let compile_input ~parent_childs ~parent target (input, deps) =
  let parent_args, parent_inp =
    match parent with
    | Some p -> ([ "--parent"; p.Inputs.name ], [ p ])
    | None -> ([], [])
  in
  let child_args =
    Fpath.Map.find input.Inputs.reloutpath parent_childs
    |> Option.value ~default:[]
    |> List.concat_map (fun (c, _) -> [ "--child"; c.Inputs.name ])
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
let compile_group ~parent_childs acc segs inputs parent =
  let compile_targets =
    List.map (fun (inp, _) -> Inputs.compile_target inp) inputs
  in
  let open Makefile in
  concat
    [
      acc;
      concat
        (List.map2
           (compile_input ~parent_childs ~parent)
           compile_targets inputs);
      phony_rule (Inputs.compile_rule_of_segs segs) ~fdeps:compile_targets [];
    ]

(** The list of childs per parent. The keys are parent's [reloutpath]. *)
let find_parent_childs tree =
  let module M = Fpath.Map in
  let ( ||| ) a b = match a with Some _ -> a | None -> b in
  let add_childs childs acc = function
    | Some parent ->
        let update_childs c' = Some (childs @ Option.value ~default:[] c') in
        M.update parent.Inputs.reloutpath update_childs acc
    | None -> acc
  in
  let rec loop_node parent acc t =
    let acc = add_childs t.Inputs.inputs acc parent in
    List.fold_left (loop_child (t.parent_page ||| parent)) acc t.childs
  and loop_child parent acc (_, t) = loop_node parent acc t in
  loop_node None M.empty tree

(** Flatten the tree (see {!Inputs.make_tree}). *)
let fold_tree f acc tree =
  let rec loop_node segs acc tree =
    let acc = f acc (List.rev segs) tree.Inputs.inputs tree.parent_page in
    loop_childs segs acc tree.childs
  and loop_childs segs acc = function
    | [] -> acc
    | (s, child) :: tl -> loop_childs segs (loop_node (s :: segs) acc child) tl
  in
  loop_node [] acc tree

(** There is one per directory. *)
let find_compile_rules tree =
  fold_tree
    (fun acc segs _ _ -> Inputs.compile_rule_of_segs segs :: acc)
    [] tree
  |> List.sort_uniq String.compare

let gen tree =
  let parent_childs = find_parent_childs tree in
  let open Makefile in
  concat
    [
      fold_tree (compile_group ~parent_childs) (concat []) tree;
      phony_rule "compile" ~deps:(find_compile_rules tree) [];
    ]
