(* util.ml *)

let lines_of_process p =
    let ic = Unix.open_process_in p in
    let lines = Fun.protect
      ~finally:(fun () -> ignore(Unix.close_process_in ic))
      (fun () ->
        let rec inner acc =
          try
            let l = input_line ic in
            inner (l::acc)
          with End_of_file -> List.rev acc
        in inner [])
    in
    lines

let mkdir d =
  try Unix.mkdir (Fpath.to_string d) 0o755 with
  | Unix.Unix_error (Unix.EEXIST, _, _) -> ()
  | exn -> raise exn
  
let write_file filename lines =
  let dir = fst (Fpath.split_base filename) in
  mkdir dir;
  let oc = open_out (Fpath.to_string filename) in
  List.iter (fun line -> Printf.fprintf oc "%s\n" line) lines;
  close_out oc
