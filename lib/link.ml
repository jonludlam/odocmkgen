(** Generate linking rules *)

open Listm
open Util

let is_hidden s =
  let len = String.length s in
  let rec aux i =
    if i > len - 2 then false
    else if s.[i] = '_' && s.[i + 1] = '_' then true
    else aux (i + 1)
  in
  aux 0

let gen_input ~packages ~package_deps (inp, _) =
  let deps_dirs =
    (* Parent directories of every inputs from every [package_deps]. *)
    let fold_inputs acc (inp, _) =
      Fpath.Set.add (Fpath.parent (Inputs.compile_target inp)) acc
    in
    let fold_pkgs acc pkg =
      List.fold_left fold_inputs acc (StringMap.find pkg packages)
    in
    List.fold_left fold_pkgs Fpath.Set.empty package_deps |> Fpath.Set.elements
  in
  (* Phony targets of dependencies (see {!Compile}). *)
  let compile_pkg_deps = List.map (( ^ ) "compile-") package_deps in
  let input_file = Inputs.compile_target inp
  and output_file = Inputs.link_target inp in
  let open Makefile in
  let inc_args =
    List.concat_map (fun dir -> [ "-I"; Fpath.to_string dir ]) deps_dirs
  in
  concat
    [
      rule [ output_file ] ~fdeps:[ input_file ] ~oo_deps:compile_pkg_deps
        [ cmd "odoc" $ "link" $ "$<" $ "-o" $ "$@" $$ inc_args ];
      phony_rule "link" ~fdeps:[ output_file ] [];
    ]

(** Until we have a better way of resolving packages. Find package dependencies
    by following compile deps. Then transitive dependencies are flattened. *)
let package_deps ~packages =
  let packages_of_input acc (_, deps) =
    List.fold_left
      (fun acc dep -> StringSet.add dep.Inputs.package acc)
      acc deps
  in
  let packages_of_inputs inputs =
    List.fold_left packages_of_input StringSet.empty inputs
  in
  let packages_deps = StringMap.map packages_of_inputs packages in
  StringMap.map
    (fun deps ->
      let f dep acc = StringSet.union acc (StringMap.find dep packages_deps) in
      StringSet.fold f StringSet.empty deps |> StringSet.elements)
    packages_deps

(* Ideally we would have a list of packages on which the specified package depends.
   Here we're making an assumption - that the references in the doc comments will
   only be referring to packages that are required to compile the modules. Other
   drivers may be able to supply additional packages in which to find referenced
   elements. *)
let gen inputs =
  (* Don't link hidden modules *)
  let link_inputs =
    inputs >>= filter (fun (inp, _) -> not (is_hidden inp.Inputs.name))
  in
  let packages = Inputs.split_packages link_inputs in
  let package_deps = package_deps ~packages in
  StringMap.fold
    (fun package inputs acc ->
      let package_deps = package :: StringMap.find package package_deps in
      let open Makefile in
      concat
        [ acc; concat (List.map (gen_input ~packages ~package_deps) inputs) ])
    packages (Makefile.concat [])
