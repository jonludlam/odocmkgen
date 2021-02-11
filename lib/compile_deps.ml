module M = Fpath.Map

type t = Inputs.t list M.t
(** The keys are inputs' [reloutpath], this fact is abstracted to avoid
    confusion. *)

let empty = M.empty

let multi_add k v m =
  M.update k (function Some v' -> Some (v @ v') | None -> Some v) m

let add target ~deps t = multi_add target.Inputs.reloutpath deps t

let get t target =
  match M.find target.Inputs.reloutpath t with Some deps -> deps | None -> []
