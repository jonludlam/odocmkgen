(* opam *)

let switch = ref None

type package = {
  name : string;
  version : string;
}

let rec get_switch () =
  match !switch with
  | None ->
    let cmd = "opam switch show" in
    let cur_switch = Util.lines_of_process cmd |> List.hd in
    switch := Some cur_switch;
    get_switch ()
  | Some s ->
    s

let pp_package fmt package =
    Format.fprintf fmt "%s.%s" package.name package.version

module S = Set.Make(struct type t = package let compare x y = compare x y end)
let deps_of_opam_result =
  fun line -> match Astring.String.fields ~empty:false line with | [name; version] -> [{name; version} ] | _ -> []

let dependencies package =
  let open Listm in
  if package.name = "ocaml" then [] else
  let cmd = Format.asprintf "opam list --switch %s --required-by %a --columns=name,version --color=never --short" (get_switch ()) pp_package package in
  Util.lines_of_process cmd >>= deps_of_opam_result

let all_opam_packages () =
  let open Listm in
  let cmd = Format.asprintf "opam list --switch %s --columns=name,version --color=never --short" (get_switch ()) in
  Util.lines_of_process cmd >>= deps_of_opam_result



