(** Generate linking rules *)

open Listm

module StringMap = Map.Make (String)

let is_hidden s =
  let len = String.length s in
  let rec aux i =
      if i > len - 2 then false else
      if s.[i] = '_' && s.[i + 1] = '_' then true
      else aux (i + 1)
  in aux 0

let split_packages inputs =
  let f inp = function Some lst -> Some (inp :: lst) | None -> Some [ inp ] in
  List.fold_left
    (fun acc inp -> StringMap.update inp.Inputs.package (f inp) acc)
    StringMap.empty inputs
  |> StringMap.bindings

let gen_input oc ~inputs_map inp =
  let deps =
    let find_input d = StringMap.find_opt d.Odoc.c_unit_name inputs_map in
    List.filter_map find_input inp.Inputs.deps
  in
  let deps_odoc = List.map Inputs.compile_target deps in
  let deps_dirs =
    List.map (fun p -> Fpath.(to_string (parent p))) deps_odoc
    |> List.sort_uniq String.compare
  and deps_odoc = List.map Fpath.to_string deps_odoc in
  let input_file = Fpath.(to_string (Inputs.compile_target inp))
  and output_file = Fpath.(to_string (Inputs.link_target inp)) in
  let deps_inc = List.map (( ^ ) "-I ") deps_dirs in
  Printf.fprintf oc "%s : %s %s\n\t@odoc link $< -o $@ %s\nlink: %s\n"
    output_file input_file
    (String.concat " " deps_odoc)
    (String.concat " " deps_inc)
    output_file

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
  List.iter (gen_input oc ~inputs_map) link_inputs;
  (* Call generate Makefiles *)
  split_packages inputs
  |> List.iter (fun (package, inputs) ->
         let output_files =
           List.map (fun inp -> Fpath.to_string (Inputs.link_target inp)) inputs
         in
         Printf.fprintf oc
           "Makefile.%s.generate: %s\n\todocmkgen generate --package %s\n"
           package
           (String.concat " " output_files)
           package;
         Printf.fprintf oc "-include Makefile.%s.generate\n" package)
