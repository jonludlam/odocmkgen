(* opam *)

type package = {
  name : string;
  version : string;
}

let pp_package fmt package =
    Format.fprintf fmt "%s.%s" package.name package.version

module S = Set.Make(struct type t = package let compare x y = compare x y end)
module H = Hashtbl.Make(struct type t = package let equal x y = x = y let hash x = Hashtbl.hash x end)

let dependencies = H.create 111

let deps_of_opam_result =
  fun line -> match Astring.String.fields ~empty:false line with | [name; version] -> [{name; version} ] | _ -> []

let opam_deps package =
  let open Listm in
  if package.name = "ocaml" then [] else
  let cmd = Format.asprintf "opam list --required-by %a --columns=name,version --color=never --short" pp_package package in
  Util.lines_of_process cmd >>= deps_of_opam_result

module H2 = Hashtbl.Make(struct type t = string let equal x y = x = y let hash x = Hashtbl.hash x end)

let packages = H2.create 111

let all_opam_packages () =
  let open Listm in
  let cmd = "opam list --columns=name,version --color=never --short" in
  let result = Util.lines_of_process cmd >>= deps_of_opam_result in
  List.iter (fun result -> H2.add packages result.name result) result;
  result

let find_package name =
  if H2.length packages = 0 then ignore (all_opam_packages ());
  try
    H2.find packages name
  with Not_found ->
    Format.eprintf "Erk: %s not found!\n%!" name;
    raise Not_found


let rec calc_deps package =
  if H.mem dependencies package
  then H.find dependencies package
  else begin
    let deps = opam_deps package in
    let init = S.of_list deps in
    let all_deps = List.fold_left (fun acc dep -> S.union acc (calc_deps dep)) init deps in
    H.add dependencies package all_deps;
    all_deps
  end

let hashed_deps package =
  let deps = calc_deps package in
  let s = S.to_seq deps in
  let str = Seq.fold_left (fun acc p -> Format.asprintf "%s\n%a" acc pp_package p) "" s in
  Digest.to_hex (Digest.string str)


