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
    the actual link-dependencies. Keys and values are the tree IDs. *)
let compute_link_deps ~parent_childs ~compile_deps tree =
  let open Inputs in
  let module M = StringMap in
  let module TreeSet = Set.Make (struct
    type t = tree

    let compare a b = String.compare a.id b.id
  end) in
  (* Every tree nodes indexed by their [reldir]. *)
  let tree_nodes =
    fold_tree (fun acc tree -> M.add tree.id tree acc) M.empty tree
  in
  let add_corresponding_node acc inp =
    (* Add the tree node corresponding to [inp] into [acc]. *)
    match M.find_opt (Inputs.tree_id_of_input inp) tree_nodes with
    | Some tree -> TreeSet.add tree acc
    | None -> acc
  in
  (* Direct dependencies for each tree nodes, keys and values are nodes' [id]. *)
  let direct_map =
    let tree_deps tree =
      let acc_input acc inp =
        match Fpath.Map.find inp.Inputs.reloutpath compile_deps with
        | Some deps -> List.fold_left add_corresponding_node acc deps
        | None -> acc
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
  let add_childs acc inp =
    match Fpath.Map.find inp.Inputs.reloutpath parent_childs with
    | Some childs -> List.fold_left add_corresponding_node acc childs
    | None -> acc
  in
  (* Compute transitive compile-deps first *)
  M.fold (fun id _ acc -> fst (transitive acc id)) direct_map M.empty
  |> M.mapi (fun id deps ->
         (* Add child trees if any. This is not transitive. *)
         let tree = M.find id tree_nodes in
         List.fold_left add_childs deps tree.inputs |> TreeSet.elements)

let gen ~parent_childs ~compile_deps tree =
  let link_deps = compute_link_deps ~parent_childs ~compile_deps tree in
  Inputs.fold_tree (link_group ~link_deps) (Makefile.concat []) tree
