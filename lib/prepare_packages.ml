(** This is a separate tool and doesn't interfere with the rest of odocmkgen.
    It is linked into the same binary for convenience. *)

open Util

let copy_file ~dst ~src =
  Format.eprintf "Copy '%a' -> '%a'\n" Fpath.pp src Fpath.pp dst;
  ignore
    (Process_util.lines_of_process "cp"
       [ Fpath.to_string src; Fpath.to_string dst ])

(** Copy files from [src_dir] that satisfy [p] to [dst_dir].
    Create [dst_dir] if needed. *)
let copy_files_from src_dir ~dst_dir p =
  match Fs_util.dir_contents src_dir with
  | exception Sys_error _ -> ()
  | [] -> ()
  | srcs ->
      Fs_util.mkdir_rec dst_dir;
      List.iter
        (fun src ->
          if p src then
            let dst = Fpath.append dst_dir (Fpath.base src) in
            copy_file ~dst ~src)
        srcs

let prepare_doc dst_dir src =
  (* TODO: Common files in [src]: Readme, changes, license (.md, .org, no ext) *)
  (* TODO: Other files: example files (.ml), manuals and markdown doc *)
  copy_files_from Fpath.(src / "odoc-pages") ~dst_dir (Fpath.has_ext ".mld")

let prepare_lib dst_dir src =
  copy_files_from src ~dst_dir (Fpath.mem_ext [ ".cmti"; ".cmt"; ".cmi" ])

(** Expect paths containing a 'lib' segment, other paths are ignored. *)
let find_root path =
  match List_util.split_at_right (( = ) "lib") (Fpath.segs path) with
  | Some (root, _, relpath) -> Some (path_of_segs root, path_of_segs relpath)
  | None -> None

let prepare_package dst_dir path =
  match find_root path with
  | Some (root, relpath) ->
      let dst_dir' = Fpath.append dst_dir relpath in
      prepare_lib dst_dir' path;
      prepare_doc dst_dir' Fpath.(root / "doc" // relpath)
  | None ->
      Format.eprintf "Warning: Ignored path '%a'\n" Fpath.pp path;
      ()

let ocamlfind_query packages =
  match
    Process_util.lines_of_process "ocamlfind" ("query" :: "-r" :: packages)
  with
  | Ok lines ->
      (* Sort to ensure reproducibility and remove duplicates just in case. *)
      Ok (List.map Fpath.v (List.sort_uniq String.compare lines))
  | Error _ -> Error ()

let run out packages =
  match ocamlfind_query packages with
  | Ok paths -> List.iter (prepare_package (Fpath.v out)) paths
  | Error () ->
      Format.eprintf "Package lookup failed.\n";
      exit 2
