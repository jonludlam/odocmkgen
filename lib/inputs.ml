open Listm
open Util

(** Lower is better *)
let cm_file_preference = function
  | ".cmti" -> Some 1
  | ".cmt" -> Some 2
  | ".cmi" -> Some 3
  | _ -> None

(** Get cm* files out of a list of files.
    Given the choice between a cmti, a cmt and a cmi file, we chose them according to [cm_file_preference] above *)
let get_cm_files files =
  let rec skip f = function hd :: tl when f hd -> skip f tl | x -> x in
  (* Take the first of each group. *)
  let rec dedup acc = function
    | (base, _, p) :: tl ->
        let tl = skip (fun (base', _, _) -> base = base') tl in
        dedup (p :: acc) tl
    | [] -> acc
  in
  (* Sort files by their basename and preference, remove other files *)
  files
  >>= (fun p ->
        let without_ext, ext = Fpath.split_ext p in
        match cm_file_preference ext with
        | Some pref -> [ (Fpath.basename without_ext, pref, p) ]
        | None -> [])
  |> List.sort compare |> dedup []

(** Get mld files out of a list of files. *)
let get_mld_files = List.filter (Fpath.has_ext ".mld")

type t = {
  name : string;  (** 'Astring' *)
  inppath : Fpath.t;  (** Path to the input file, contains [root]. *)
  root : Fpath.t;
      (** Root path in which this was found, e.g. /home/opam/.opam/4.10.0/lib/package_name *)
  reloutpath : Fpath.t;
      (** Relative path to use for output, extension is the same as [inppath].
          May not correspond to a input file in [root]. *)
  package : string;  (** Package in which this file lives ("astring") *)
}
(** Represents the necessary information about a particular compilation unit *)

let pp fmt x =
  Format.fprintf fmt "@[<v 2>{ name: %s@,root: %a@,path: %a@,package:%s }@]"
    x.name Fpath.pp x.root Fpath.pp x.inppath x.package

let input_file t = t.inppath

(** Returns the relative path to an odoc file based on an input file. For example, given
   `/home/opam/.opam/4.10.0/lib/ocaml/compiler-libs/lambda.cmi` it will return
   `odocs/ocaml/compiler-libs/lambda.odoc` *)
let compile_target t = Fpath.(v "odocs" // set_ext "odoc" t.reloutpath)

(** Like [compile_target] but goes into the "odocls" directory. *)
let link_target t = Fpath.(v "odocls" // set_ext "odocl" t.reloutpath)

(* Get info given a base file (cmt, cmti or cmi) *)
let get_cm_info root inppath =
  let package = Fpath.(basename (parent inppath)) in
  let reloutpath =
    match Fpath.relativize ~root inppath with
    | Some p -> p
    | None -> failwith "odd"
  in
  let fname = Fpath.base reloutpath in
  let name = String.capitalize_ascii Fpath.(to_string (rem_ext fname)) in
  { name; inppath; root; reloutpath; package }

let get_mld_info root inppath =
  let package = Fpath.(basename (parent inppath)) in
  let relpath =
    match Fpath.relativize ~root inppath with
    | Some p -> p
    | None -> failwith "odd"
  in
  let fparent, fname = Fpath.split_base relpath in
  (* Prefix name and output file name with "page-" *)
  let outfname = Fpath.v ("page-" ^ Fpath.to_string fname) in
  let name = Fpath.to_string (Fpath.rem_ext outfname) in
  let reloutpath = Fpath.append fparent outfname in
  { name; inppath; root; reloutpath; package }

let split_packages inputs =
  let f inp = function Some lst -> Some (inp :: lst) | None -> Some [ inp ] in
  List.fold_left
    (fun acc (({ package; _ }, _) as inp) ->
      StringMap.update package (f inp) acc)
    StringMap.empty inputs

(** Segs without ["."] and [".."]. *)
let segs_of_path p =
  List.filter (fun s -> (not (Fpath.is_rel_seg s)) && s <> "") (Fpath.segs p)

module DigestMap = Map.Make (Digest)

(** Compute direct compile-dependencies for a list of inputs.
    Returns the list of inputs paired with its dependencies. *)
let compile_deps inputs =
  let deps_and_digests =
    List.map
      (fun inp ->
        let deps = Odoc.compile_deps inp.inppath in
        match List.partition (fun d -> d.Odoc.c_unit_name = inp.name) deps with
        | [ self ], deps -> Some (self.c_digest, deps)
        | _ ->
            Format.eprintf "Failed to find digest for self (%s)\n%!" inp.name;
            None)
      inputs
  in
  let inputs_by_digest =
    List.fold_left2
      (fun acc inp -> function
        | Some (digest, _) -> DigestMap.add digest inp acc | None -> acc)
      DigestMap.empty inputs deps_and_digests
  in
  let find_dep inp dep =
    match DigestMap.find_opt dep.Odoc.c_digest inputs_by_digest with
    | Some _ as x -> x
    | None ->
        Format.eprintf "Warning, couldn't find dep %s of file %a\n"
          dep.Odoc.c_unit_name Fpath.pp inp.inppath;
        None
  in
  List.map2
    (fun inp -> function
      | Some (_, deps) -> (inp, List.filter_map (find_dep inp) deps)
      | None -> (inp, []))
    inputs deps_and_digests

let find_inputs root =
  let files = Fs_util.dir_contents_rec root in
  compile_deps (get_cm_files files |> List.map (get_cm_info root))
  @ (get_mld_files files >>= fun mld -> [ (get_mld_info root mld, []) ])

(** An input and its compile-dependencies *)
type with_deps = t * t list

type tree = {
  inputs : with_deps list;
  parent_page : t option;
  childs : (string * tree) list;
}

(** Turn a list of path into a tree. The second component is passed as-is. *)
let make_tree_from_dirs (paths : (Fpath.t * 'a list) list) :
    [ `N of 'a list * (string * 'b) list ] as 'b =
  let rec loop_child_nodes acc = function
    | [] -> acc
    | ([], _) :: tl -> loop_child_nodes acc tl
    | (seg :: seg_tl, p) :: tl ->
        let childs, tl = loop_same_seg [ (seg_tl, p) ] seg tl in
        loop_child_nodes ((seg, loop_node childs) :: acc) tl
  and loop_node = function
    | ([], direct) :: childs -> `N (direct, loop_child_nodes [] childs)
    | childs -> `N ([], loop_child_nodes [] childs)
  and loop_same_seg acc seg = function
    | (seg' :: seg_tl, p) :: tl when seg = seg' ->
        loop_same_seg ((seg_tl, p) :: acc) seg tl
    | tl -> (acc, tl)
  in
  List.sort_uniq (fun (a, _) (b, _) -> Fpath.compare a b) paths
  |> List.map (fun (p, inp) -> (segs_of_path p, inp))
  |> loop_node

(** Turn a list of inputs ([with_deps]) into a tree following the directory
    structure ([reloutpath]). Detects parent pages. See {!tree}. *)
let make_tree inputs =
  let module M = Fpath.Map in
  let multi_add v vs = Some (v :: Option.value vs ~default:[]) in
  let group_by_dir acc (({ reloutpath; _ }, _) as inp) =
    M.update (Fpath.parent reloutpath) (multi_add inp) acc
  in
  let find_parent_page gp_page parent_inputs dir_name =
    let parent_name = "page-" ^ dir_name in
    let is_parent_page (inp, _) = inp.name = parent_name in
    match List.find_opt is_parent_page parent_inputs with
    | Some (p, _) -> Some p
    | None -> gp_page
  in
  (* Finally construct the tree. *)
  let rec make_tree parent_page (`N (inputs, childs)) =
    let childs = List.map (make_child_tree parent_page inputs) childs in
    { inputs; parent_page; childs }
  and make_child_tree gp_page parent_inputs (dir_name, subtree) =
    let parent_page = find_parent_page gp_page parent_inputs dir_name in
    (dir_name, make_tree parent_page subtree)
  in
  M.bindings (List.fold_left group_by_dir M.empty inputs)
  |> make_tree_from_dirs |> make_tree None
