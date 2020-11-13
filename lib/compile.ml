open Listm

(* Rules for compiling cm{t,ti,i} files into odoc files *)
let compile_fragment all_infos info =
  (* Get the filename of the output odoc file *)
  let odoc_path = Inputs.compile_target info in

  let odoc_path_result = Fpath.segs odoc_path |> List.filter (fun x -> x <> "odoc-pages") |> String.concat "/" |> Fpath.of_string in
  let odoc_path = match odoc_path_result with | Ok r -> r | _ -> failwith "error" in

  (* Find by digest the [source_info] for each dependency in our source_info record *)
  let deps =
    info.deps >>= fun dep ->
    try [ List.find (fun x -> x.Inputs.digest = dep.Odoc.c_digest) all_infos ]
    with Not_found ->
      Format.eprintf "Warning, couldn't find dep %s of file %a\n" dep.Odoc.c_unit_name Fpath.pp info.relpath;
      []
  in

  (* Get a list of odoc files for the dependencies *)
  let dep_odocs = List.map Inputs.compile_target deps in

  (* Odoc requires the directories in which to find the odoc files of the dependencies *)
  let include_str =
    List.map Fpath.(fun p -> to_string (parent p)) dep_odocs
    |> List.sort_uniq String.compare
    |> String.concat " "
  and deps_str = String.concat " " (List.map Fpath.to_string dep_odocs) in

  [ Format.asprintf "%a : %a %s" Fpath.pp odoc_path Fpath.pp (Inputs.input_file info) deps_str;
    Format.asprintf "\t@odoc compile --package %s $< %s -o %a" info.package include_str Fpath.pp odoc_path;
    Format.asprintf "compile : %a" Fpath.pp odoc_path;
    Format.asprintf "Makefile.%s.link : %a" info.package Fpath.pp odoc_path ]

let gen oc inputs =
  let print_lines = List.iter (Printf.fprintf oc "%s\n") in
  List.iter (fun inp -> print_lines (compile_fragment inputs inp)) inputs
