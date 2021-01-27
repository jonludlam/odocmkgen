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

let link_input ~deps target (input, _) =
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
    List.filter (fun (inp, _) -> not (is_hidden inp)) tree.Inputs.inputs
  in
  let link_targets = List.map (fun (inp, _) -> Inputs.link_target inp) inputs
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
    the actual link-dependencies. Keys and values are the "compile-" rules, see
    {!Inputs.compile_rule_of_segs}. *)
let compute_link_deps tree =
  let open Inputs in
  let module M = StringMap in
  let module TreeSet = Set.Make (struct
    type t = tree

    let compare a b = String.compare a.id b.id
  end) in
  let direct_map =
    let tree_of_input =
      (* Map inputs to the tree node they belong to. *)
      let acc_inp acc (inp, _) = Fpath.Map.add inp.reloutpath tree acc in
      let acc_inputs acc tree = List.fold_left acc_inp acc tree.inputs in
      let map = fold_tree acc_inputs Fpath.Map.empty tree in
      fun inp -> Fpath.Map.get inp.reloutpath map
    in
    (* Direct dependencies for each tree nodes, keys and values are nodes' [id]. *)
    let acc_deps_p acc dep = TreeSet.add (tree_of_input dep) acc in
    let acc_deps acc (_, deps) = List.fold_left acc_deps_p acc deps in
    fold_tree (fun acc tree -> M.add tree.id tree acc) M.empty tree
    |> M.map (fun tree -> List.fold_left acc_deps TreeSet.empty tree.inputs)
  in
  let rec transitive acc id =
    match M.find_opt id acc with
    | Some deps -> (acc, deps)
    | None ->
        (* Insert a dummy value, in case of cycles, this function will return *)
        let acc = M.add id TreeSet.empty acc in
        let acc, deps =
          let direct_deps =
            let direct_deps = M.find id direct_map in
            fold_tree (fun acc tree -> TreeSet.add tree acc) direct_deps tree
            (* Add the current node and direct childs to the dependencies *)
          in
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

let gen tree =
  let link_deps = compute_link_deps tree in
  Inputs.fold_tree (link_group ~link_deps) (Makefile.concat []) tree
