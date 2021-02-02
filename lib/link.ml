(** Generate linking rules *)

open Util

let is_hidden { Inputs.name = s; _ } =
  let len = String.length s in
  let rec aux i =
    if i > len - 2 then false
    else if s.[i] = '_' && s.[i + 1] = '_' then true
    else aux (i + 1)
  in
  aux 0

let link_input ~deps target input =
  let inc_args =
    List.concat_map
      (fun { Inputs.reldir; _ } ->
        [ "-I"; Fpath.to_string (Inputs.compile_path_of_relpath reldir) ])
      deps
  in
  let compile_deps = List.map Inputs.compile_rule deps in
  let input_file = Inputs.compile_target input in
  let open Makefile in
  rule [ target ] ~fdeps:[ input_file ] ~oo_deps:compile_deps
    [ cmd "odoc" $ "link" $ "$<" $ "-o" $ "$@" $$ inc_args ]

let link_group ~link_deps acc tree =
  (* Don't link hidden modules *)
  let inputs =
    List.filter (fun inp -> not (is_hidden inp)) tree.Inputs.inputs
  in
  let link_targets = List.map Inputs.link_target inputs
  and deps = StringMap.find tree.id link_deps in
  let open Makefile in
  if inputs = [] then acc
  else
    concat
      [
        acc;
        concat (List.map2 (link_input ~deps) link_targets inputs);
        phony_rule "link" ~fdeps:link_targets [];
      ]

(** Compute link-dependencies by following compile-deps transitively. The set of
    dependencies is extended to entire directories. This is an approximation of
    the actual link-dependencies. Keys and values are the "compile-" rules. *)
let compute_link_deps ~compile_deps tree =
  let open Inputs in
  let module M = StringMap in
  let module TreeSet = Set.Make (struct
    type t = tree

    let compare a b = String.compare a.id b.id
  end) in
  let parent_childs = Inputs.find_parent_childs tree in
  (* Direct dependencies for each tree nodes, keys and values are nodes' [id]. *)
  let direct_map =
    let tree_nodes =
      (* Every tree nodes indexed by their [reldir]. *)
      fold_tree (fun acc tree -> M.add tree.id tree acc) M.empty tree
    in
    let tree_deps tree =
      let acc_deps' acc dep =
        (* Extend dependencies to entire tree nodes. *)
        match M.find_opt (Inputs.tree_id_of_input dep) tree_nodes with
        | Some tree -> TreeSet.add tree acc
        | None -> acc
      in
      let acc_deps acc deps = List.fold_left acc_deps' acc deps in
      let add_childs acc inp =
        (* Add childs to the set of dependency. *)
        match Fpath.Map.find inp.reloutpath parent_childs with
        | Some childs -> acc_deps acc childs
        | None -> acc
      in
      let acc_input acc inp =
        let deps = Fpath.Map.get inp.Inputs.reloutpath compile_deps in
        add_childs (acc_deps acc deps) inp
      in
      List.fold_left acc_input TreeSet.empty tree.inputs
    in
    fold_tree (fun acc tree -> M.add tree.id (tree_deps tree) acc) M.empty tree
  in
  let rec transitive acc id =
    match M.find_opt id acc with
    | Some deps -> (acc, deps)
    | None ->
        (* Insert a dummy value, in case of cycles, this function will return *)
        let acc = M.add id TreeSet.empty acc in
        (* Find transitive deps *)
        let acc, deps =
          let direct_deps = M.find id direct_map in
          TreeSet.fold
            (fun tree (acc, deps) ->
              let acc, deps' = transitive acc tree.id in
              (acc, TreeSet.union deps' deps))
            direct_deps (acc, direct_deps)
        in
        (M.add id deps acc, deps)
  in
  M.fold (fun id _ acc -> fst (transitive acc id)) direct_map M.empty
  |> M.map TreeSet.elements

let gen ~compile_deps tree =
  let link_deps = compute_link_deps ~compile_deps tree in
  Inputs.fold_tree (link_group ~link_deps) (Makefile.concat []) tree
