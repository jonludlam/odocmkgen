(** Generate linking rules *)

open Listm
open Util

let is_hidden s =
  let len = String.length s in
  let rec aux i =
      if i > len - 2 then false else
      if s.[i] = '_' && s.[i + 1] = '_' then true
      else aux (i + 1)
  in aux 0

let gen_input oc ~packages ~package_deps inp =
  let deps_dirs =
    (* Parent directories of every inputs from every [package_deps]. *)
    let fold_inputs acc inp =
      Fpath.Set.add (Fpath.parent (Inputs.compile_target inp)) acc
    in
    let fold_pkgs acc pkg =
      List.fold_left fold_inputs acc (StringMap.find pkg packages)
    in
    List.fold_left fold_pkgs Fpath.Set.empty package_deps |> Fpath.Set.elements
  in
  (* Include directories of every dependencies *)
  let deps_inc = List.map (fun p -> "-I " ^ Fpath.to_string p) deps_dirs
  (* Phony targets of dependencies (see {!Compile}). *)
  and compile_pkg_deps = List.map (( ^ ) "compile-") package_deps in
  let input_file = Fpath.(to_string (Inputs.compile_target inp))
  and output_file = Fpath.(to_string (Inputs.link_target inp)) in
  Printf.fprintf oc "%s : %s | %s\n\t@odoc link $< -o $@ %s\nlink: %s\n"
    output_file input_file
    (String.concat " " compile_pkg_deps)
    (String.concat " " deps_inc)
    output_file

(** Until we have a better way of resolving packages. Find package dependencies
    by following compile deps. Then transitive dependencies are flattened. *)
let package_deps ~inputs_map ~packages =
  let packages_of_input acc inp =
    let f acc dep =
      match StringMap.find_opt dep.Odoc.c_unit_name inputs_map with
      | Some inp -> StringSet.add inp.Inputs.package acc
      | None -> acc
    in
    List.fold_left f acc inp.Inputs.deps
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
   elements.

   We assume that link dependencies are the same as the corresponding compile
   dependencies. *)
let gen oc (inputs : Inputs.t list) =
  let inputs_map =
    StringMap.of_seq
      (Seq.map (fun inp -> (inp.Inputs.name, inp)) (List.to_seq inputs))
  in
  (* Don't link hidden modules *)
  let link_inputs =
    inputs >>= filter (fun inp -> not (is_hidden inp.Inputs.name))
  in
  let packages = Inputs.split_packages link_inputs in
  let package_deps = package_deps ~inputs_map ~packages in
  packages
  |> StringMap.iter (fun package inputs ->
         let package_deps = package :: StringMap.find package package_deps in
         List.iter (gen_input oc ~packages ~package_deps) inputs;
         let output_files =
           List.map (fun inp -> Fpath.to_string (Inputs.link_target inp)) inputs
         in
         (* Call generate Makefiles *)
         Printf.fprintf oc
           "Makefile.%s.generate: %s\n\todocmkgen generate --package %s\n"
           package
           (String.concat " " output_files)
           package;
         Printf.fprintf oc "-include Makefile.%s.generate\n" package)
