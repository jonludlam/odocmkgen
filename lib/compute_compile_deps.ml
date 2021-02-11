open Util

module DigestMap = Map.Make (Digest)

let from_odoc inputs =
  let deps_and_digests =
    (* Query [odoc compile-deps] for every inputs. *)
    List.map
      (fun inp ->
        if not (Fpath.mem_ext [ ".cmti"; ".cmt"; ".cmi" ] inp.Inputs.inppath) then None
        else
          let deps = Odoc.compile_deps inp.inppath in
          match
            List.partition (fun d -> d.Odoc.c_unit_name = inp.name) deps
          with
          | [ self ], deps -> Some (self.c_digest, deps)
          | _ ->
              Format.eprintf "Failed to find digest for self (%s)\n%!" inp.name;
              None)
      inputs
  in
  let inputs_by_digest =
    List.fold_left2
      (fun acc inp -> function
        | Some (digest, _) -> DigestMap.add digest inp acc | None -> acc)
      DigestMap.empty inputs deps_and_digests
  in
  let find_dep inp dep =
    match DigestMap.find_opt dep.Odoc.c_digest inputs_by_digest with
    | Some _ as x -> x
    | None ->
        Format.eprintf "Warning, couldn't find dep %s of file %a\n"
          dep.Odoc.c_unit_name Fpath.pp inp.Inputs.inppath;
        None
  in
  List.fold_left2
    (fun acc inp d ->
      let deps =
        match d with
        | Some (_, deps) -> List.filter_map (find_dep inp) deps
        | None -> []
      in
      Compile_deps.add inp ~deps acc)
    Compile_deps.empty inputs deps_and_digests

let from_deps_file ~file inputs =
  let module M = Fpath.Map in
  let parse_path s = Fpath.(normalize (v s)) in
  let parse_line line =
    String.split_on_char ' ' line |> List.map parse_path |> function
    | hd :: tl -> Some (hd, tl)
    | [] -> None
  in
  let multi_add k v m =
    M.update k (function Some v' -> Some (v @ v') | None -> Some v) m
  in
  (* Normalize every paths *)
  let norm p = Fpath.(rem_empty_seg (normalize p)) in
  (* Every inputs indexed by their relinppath. *)
  let inputs_map =
    List.fold_left
      (fun acc inp ->
        M.add (norm inp.Inputs.relinppath) [ inp ] acc
        (* Also bind directories to inputs directly in them. *)
        |> multi_add (norm (Fpath.parent inp.relinppath)) [ inp ])
      M.empty inputs
  in
  let find_input path =
    M.find (norm path) inputs_map |> Option.value ~default:[]
  in
  Fs_util.read_file
    (fun acc line ->
      match parse_line line with
      | Some (hd, tl) ->
          let deps = List.concat_map find_input tl in
          find_input hd
          |> List.fold_left (fun acc inp -> Compile_deps.add inp ~deps acc) acc
      | None -> acc)
    Compile_deps.empty file
