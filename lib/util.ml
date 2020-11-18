(* util.ml *)

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
