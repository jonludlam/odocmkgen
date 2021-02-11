(** This module contains the data-structure for managing compile-deps. See
    {!Compute_compile_deps}. *)

type t
(** Store compile deps. *)

val empty : t

val add : Inputs.t -> deps:Inputs.t list -> t -> t
(** If the target is already present, deps are added. *)

val get : t -> Inputs.t -> Inputs.t list
(** If the target is not present, returns [[]]. *)
