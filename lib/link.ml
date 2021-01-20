(** Generate linking rules *)

let is_hidden s =
  let len = String.length s in
  let rec aux i =
    if i > len - 2 then false
    else if s.[i] = '_' && s.[i + 1] = '_' then true
    else aux (i + 1)
  in
  aux 0

let link_inputs inputs deps_p =
  let compile_rules = List.map Compile.compile_rule_of_path deps_p in
  let inc_args =
    List.concat_map
      (fun dir ->
        [ "-I"; Fpath.to_string (Inputs.compile_path_of_relpath dir) ])
      deps_p
  in
  let link_targets = List.map Inputs.link_target inputs in
  let open Makefile in
  let link_input input output_file =
    let input_file = Inputs.compile_target input in
    rule [ output_file ] ~fdeps:[ input_file ] ~oo_deps:compile_rules
      [ cmd "odoc" $ "link" $ "$<" $ "-o" $ "$@" $$ inc_args ]
  in
  concat
    [
      concat (List.map2 link_input inputs link_targets);
      phony_rule "link" ~fdeps:link_targets [];
    ]

(** Compute link-dependencies by following compile-deps. The set of
    dependencies is extended to entire directories, transitive dependencies are
    flattened. Every paths correspond to the [reloutpath] field. *)
let link_deps inputs =
  let module S = Fpath.Set in
  let module M = Fpath.Map in
  let key inp = Fpath.parent inp.Inputs.reloutpath in
  let path_map =
    (* inputs grouped by [key] *)
    let multi_add k v map =
      M.update k (fun vs -> Some (v :: Option.value vs ~default:[])) map
    in
    let group_inputs acc ((inp, _) as inp') = multi_add (key inp) inp' acc in
    List.fold_left group_inputs M.empty inputs
  in
  let direct_map =
    (* direct dependencies *)
    let acc_deps_p acc dep = S.add (key dep) acc in
    let acc_deps acc (_, deps) = List.fold_left acc_deps_p acc deps in
    M.map (List.fold_left acc_deps S.empty) path_map
  in
  let rec transitive acc_map of_path =
    match M.find of_path acc_map with
    | Some deps_p -> (* Already visited *) (acc_map, deps_p)
    | None ->
        (* Insert a dummy value, in case of cycles, this function will return *)
        let acc_map = M.add of_path S.empty acc_map in
        let acc_map, deps_p =
          let direct_deps = M.get of_path direct_map |> S.add of_path in
          S.fold
            (fun path (acc_map, acc_deps) ->
              let acc_map, deps_p = transitive acc_map path in
              (acc_map, S.union deps_p acc_deps))
            direct_deps (acc_map, direct_deps)
        in
        (M.add of_path deps_p acc_map, deps_p)
  in
  M.fold
    (fun path inputs (acc_map, acc_inp) ->
      let acc_map, deps_p = transitive acc_map path in
      (acc_map, (List.map fst inputs, S.elements deps_p) :: acc_inp))
    path_map (M.empty, [])
  |> snd

(* Ideally we would have a list of packages on which the specified package depends.
   Here we're making an assumption - that the references in the doc comments will
   only be referring to packages that are required to compile the modules. Other
   drivers may be able to supply additional packages in which to find referenced
   elements. *)
let gen inputs =
  inputs
  (* Don't link hidden modules *)
  |> List.filter (fun (inp, _) -> not (is_hidden inp.Inputs.name))
  |> link_deps
  |> List.fold_left
       (fun acc (inputs, deps_p) ->
         Makefile.concat [ acc; link_inputs inputs deps_p ])
       (Makefile.concat [])
