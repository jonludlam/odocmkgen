(** This module is meant to be opened locally. *)

type t
(** A fragment of a Makefile *)

type cmd

val concat : t list -> t

val rule :
  Fpath.t ->
  ?fdeps:Fpath.t list ->
  ?deps:string list ->
  ?oo_deps:string list ->
  cmd list ->
  t
(** [oo_deps] is order-only dependencies. *)

val phony_rule :
  string ->
  ?fdeps:Fpath.t list ->
  ?deps:string list ->
  ?oo_deps:string list ->
  cmd list ->
  t

val include_ : Fpath.t -> t

val pp : Format.formatter -> t -> unit

(** Create a [cmd]. Use {!($)} and {!($$)} to concatenate arguments.
    [~stdin], [~stdout] and [~stderr] are also escaped but Makefile variables
    survive it and are still working as expected (this depends on an implementation detail of . *)
val cmd : ?stdin:string -> ?stdout:string -> ?stderr:string -> string -> cmd

val ( $ ) : cmd -> string -> cmd

val ( $$ ) : cmd -> string list -> cmd
