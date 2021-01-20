(** This module is meant to be opened *)

module StringMap = Map.Make (String)
module StringSet = Set.Make (String)

module Process_util = struct
  let lines_of_process p =
    let ic = Unix.open_process_in p in
    let lines =
      let rec inner acc =
        try
          let l = input_line ic in
          inner (l :: acc)
        with End_of_file -> List.rev acc
      in
      inner []
    in
    match Unix.close_process_in ic with
    | Unix.WEXITED 0 -> lines
    | _ ->
        Format.eprintf "Command failed: %s\n" p;
        exit 1
end

module List_util = struct
  (** Split a list on the first element that satisfy [p] starting from the end
      of the list. Return [None] if no element matched. *)
  let split_at_right p lst =
    let rec loop p right = function
      | [] -> None
      | hd :: left when p hd -> Some (List.rev left, hd, right)
      | hd :: left -> loop p (hd :: right) left
    in
    loop p [] (List.rev lst)
end

module Fs_util = struct
  let dir_contents dir =
    let contents = Sys.readdir (Fpath.to_string dir) in
    (* Sort to ensure reproducibility (eg. order of log messages). *)
    Array.sort String.compare contents;
    contents |> Array.map (Fpath.( / ) dir) |> Array.to_list

  let is_dir x = Sys.is_directory (Fpath.to_string x)

  let dir_contents_rec dir =
    let rec loop acc dir =
      Sys.readdir (Fpath.to_string dir)
      |> Array.fold_left
           (fun acc fname ->
             let p = Fpath.( / ) dir fname in
             if is_dir p then loop acc p else p :: acc)
           acc
    in
    List.sort Fpath.compare (loop [] dir)

  let dir_exists x =
    let p = Fpath.to_string x in
    Sys.file_exists p && Sys.is_directory p

  let rec mkdir_rec dir =
    let dir_s = Fpath.to_string dir in
    if not (Sys.file_exists dir_s) then (
      mkdir_rec (Fpath.parent dir);
      Unix.mkdir dir_s 0o777 )
end

let path_of_segs segs = Fpath.v (String.concat Fpath.dir_sep segs)
