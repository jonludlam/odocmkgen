type t

val concat : t list -> t

(** [oo_deps] is order-only dependencies. *)
val rule : Fpath.t -> ?fdeps:Fpath.t list -> ?deps:string list -> ?oo_deps:string list -> string list -> t

val phony_rule : string -> ?fdeps:Fpath.t list -> ?deps:string list -> ?oo_deps:string list -> string list -> t

val include_ : Fpath.t -> t

val pp : Format.formatter -> t -> unit
