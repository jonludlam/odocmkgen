(* Universe.ml *)

(* A universe is a set of packages at specific versions *)
module T = struct
  type t = Opam.package 
  let compare x y =
    match String.compare x.Opam.name y.Opam.name with
    | 0 -> String.compare x.version y.version
    | n -> n
  
  let equal x y =
    String.equal x.Opam.name y.Opam.name && String.equal x.version y.version

  let hash x =
    Hashtbl.hash (x.Opam.name, x.version)
end

module S = Set.Make(T)

type t = {
  id : Digest.t;
  packages : S.t
}
let of_packages packages =
  let s = S.to_seq packages in
  let str = Seq.fold_left (fun acc p -> Format.asprintf "%s\n%a" acc Opam.pp_package p) "" s in
  let id = Digest.to_hex (Digest.string str) in
  { id; packages }

(* Hashtbl of all package dependencies - maps from a package to a set of dependencies calculated
   via the transitive closure of all direct dependencies *)
module H = Hashtbl.Make(T)
let dependencies = H.create 111

let rec calc_deps package =
  if H.mem dependencies package
  then H.find dependencies package
  else begin
    let deps = Opam.dependencies package in
    let init = S.of_list deps in
    let all_deps = List.fold_left (fun acc dep -> S.union acc (calc_deps dep)) init deps in
    H.add dependencies package all_deps;
    all_deps
  end

module Current = struct
(* Current dependency universes - universes that exist embedded in our current one,
   indexed by the name of the package that depends upon that universe *)
  module H = Hashtbl.Make(struct type t = string let equal x y = String.equal x y let hash x = Hashtbl.hash x end)
  let h = H.create 111

  let init () =
    let packages = Opam.all_opam_packages () in
    List.iter (fun package ->
      let deps = calc_deps package in
      let u = (package, of_packages deps) in
      H.add h package.name u) packages
  
  let dep_universe package =
    if H.length h = 0 then ignore (init ());
    try H.find h package
    with Not_found ->
      Format.eprintf "Package '%s' not found\n%!" package;
      raise Not_found
end

  (* *)
