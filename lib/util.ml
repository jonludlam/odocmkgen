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
  (** Like {!List.find_opt} but also return the list without the found element *)
  let find_remove f lst =
    let rec loop f acc = function
      | [] -> None
      | hd :: tl when f hd -> Some (List.rev_append acc tl, hd)
      | hd :: tl -> loop f (hd :: acc) tl
    in
    loop f [] lst
end
