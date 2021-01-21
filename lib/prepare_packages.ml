(** This is a separate tool and doesn't interfere with the rest of odocmkgen.
    It is linked into the same binary for convenience. *)

open Util

let copy_file ~dst ~src =
  Format.eprintf "Copy '%a' -> '%a'\n" Fpath.pp src Fpath.pp dst;
  ignore
    (Process_util.lines_of_process "cp"
       [ Fpath.to_string src; Fpath.to_string dst ])

(** Copy files [srcs] to the directory [dst], keeping their name.
    Create [dst_dir] if needed. *)
let copy_files ~dst_dir = function
  | [] -> ()
  | srcs ->
      Fs_util.mkdir_rec dst_dir;
      srcs
      |> List.iter (fun src ->
             let dst = Fpath.append dst_dir (Fpath.base src) in
             copy_file ~dst ~src)

let create_file ~dst f =
  Format.eprintf "Create '%a'\n" Fpath.pp dst;
  let oc = open_out (Fpath.to_string dst) in
  f oc;
  close_out oc

(** List (non-recursively) files from [src_dir] that satisfy [p]. *)
let find_files src_dir p =
  match Fs_util.dir_contents src_dir with
  | exception Sys_error _ -> []
  | srcs -> List.filter p srcs

(** Find the doc files, [src] is the "prefix/doc/package" directory. *)
let find_doc src =
  (* TODO: Common files in [src]: Readme, changes, license (.md, .org, no ext) *)
  (* TODO: Other files: example files (.ml), manuals and markdown doc *)
  find_files (Fpath.( / ) src "odoc-pages") (Fpath.has_ext ".mld")

(** Find the object files, [src] is the "prefix/lib/package" directory. *)
let find_lib src = find_files src (Fpath.mem_ext [ ".cmti"; ".cmt"; ".cmi" ])

(** Expect paths containing a 'lib' segment, other paths are ignored. *)
let find_package path =
  match List_util.split_at_right (( = ) "lib") (Fpath.segs path) with
  | Some (root, _, relpath) ->
      Some (path, path_of_segs root, path_of_segs relpath)
  | None ->
      Format.eprintf "Warning: Ignored path '%a'\n" Fpath.pp path;
      None

(** The page name of a .mld without the "page-" prefix. *)
let page_name path = Fpath.(basename (rem_ext path))

(** The module name of an object file. *)
let module_name path = String.capitalize_ascii Fpath.(basename (rem_ext path))

let fpf = Printf.fprintf

let split_user_package_page ~package_name doc =
  let target = Fpath.v (package_name ^ ".mld") in
  let is_package_page p = Fpath.equal (Fpath.base p) target in
  match List_util.split_at_right is_package_page doc with
  | Some (left, p, right) -> (left @ right, Some p)
  | None -> (doc, None)

let generate_package_page ~package_name ~modules ~pages oc =
  let list_pages oc pages =
    fpf oc "Documentation:\n";
    List.iter (fpf oc "- {!childpage:%s}\n") pages
  and list_modules oc modules =
    fpf oc "Modules:\n";
    List.iter (fpf oc "- {!childmodule:%s}\n") modules
  in
  fpf oc "{0 %s}\n\n" package_name;
  if pages <> [] then list_pages oc pages;
  if modules <> [] then list_modules oc modules

let prepare_package_page ~package_name ~user_package_page dst lib doc =
  match user_package_page with
  | Some p -> copy_file ~src:p ~dst
  | None ->
      let pages = List.map page_name doc
      and modules = List.sort_uniq String.compare (List.map module_name lib) in
      create_file ~dst (generate_package_page ~package_name ~modules ~pages)

let prepare_package dst_dir (path, root, relpath) =
  let dst_dir = Fpath.append dst_dir relpath in
  let package_name = Fpath.basename relpath in
  let lib = find_lib path and doc = find_doc Fpath.(root / "doc" // relpath) in
  let doc, user_package_page = split_user_package_page ~package_name doc in
  copy_files ~dst_dir lib;
  copy_files ~dst_dir doc;
  prepare_package_page ~package_name ~user_package_page
    Fpath.(parent dst_dir / (package_name ^ ".mld"))
    lib doc

let prepare_packages_list_page dst packages =
  let list_pkg oc (_, _, relpath) =
    let pkg_page = String.concat "-" (Fpath.segs relpath) in
    fpf oc "{!childpage:%s}" pkg_page
  in
  let generate_page oc =
    fpf oc "{0 Packages}\n";
    List.iter (list_pkg oc) packages;
  in
  create_file ~dst generate_page

let prepare_packages dst_dir paths =
  let packages = List.filter_map find_package paths in
  List.iter (prepare_package (Fpath.( / ) dst_dir "packages")) packages;
  prepare_packages_list_page (Fpath.( / ) dst_dir "packages.mld") packages

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
  | Ok paths -> prepare_packages (Fpath.v out) paths
  | Error () ->
      Format.eprintf "Package lookup failed.\n";
      exit 2
