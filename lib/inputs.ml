open Listm

let contents dir =
  Sys.readdir (Fpath.to_string dir)
  |> Array.map (Fpath.( / ) dir)
  |> Array.to_list

let filter pred item = if pred item then [item] else []

let is_dir x = Sys.is_directory (Fpath.to_string x)

let has_ext exts f =
  List.exists (fun suffix -> Fpath.has_ext suffix f) exts

let rec find_files extensions base_dir =
  let items = contents base_dir in
  let dirs = items >>= filter is_dir in
  let cmis = items >>= filter (has_ext extensions) |> List.map Fpath.rem_ext |> setify in
  let subitems = dirs >>= find_files extensions in
  cmis @ subitems
