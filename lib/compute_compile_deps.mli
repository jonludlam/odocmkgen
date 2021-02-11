(** Compute compile-dependencies by querying [odoc compile-deps]. Maps inputs'
    [reloutpath] to the list of dependencies. Parent pages are not considered. *)
val from_odoc : Inputs.t list -> Compile_deps.t

(** Returns the same map as {!compute_compile_deps} but read it from a file.
    Each lines is a list of paths separated by spaces. The first path of each
    line is the target, the other paths are its dependencies. Every paths can
    be to files or to directories, in which case they apply to every files
    directly in that directory.
    TODO: Switch to a better format, for example sexp. *)
val from_deps_file : file:string -> Inputs.t list -> Compile_deps.t
