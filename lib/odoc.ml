(* Odoc *)
open Listm

type deps = {
  package : string;
  name : string;
  digest : Digest.t;
}
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

let link_deps dir =
  let process_line line =
    match Astring.String.cuts ~sep:" " line with
    | [package; name; digest] ->
      [{package; name; digest}]
    | _ -> []
  in
  lines_of_process (Format.asprintf "odoc html-deps %a" Fpath.pp dir)
  >>= process_line
