(* Odoc makefile generator *)

open Mkgen
open Cmdliner

(** Example: [conv_compose Fpath.of_string Fpath.to_string Arg.dir] *)
let conv_compose ?docv parse to_string c =
  let open Arg in
  let docv = match docv with Some v -> v | None -> conv_docv c in
  let parse v = match conv_parser c v with Ok x -> parse x | Error _ as e -> e
  and print fmt t = conv_printer c fmt (to_string t) in
  conv ~docv (parse, print)

(** Like [Cmdliner.Arg.dir] but return a [Fpath.t] *)
let conv_fpath_dir = conv_compose Fpath.of_string Fpath.to_string Arg.dir

module Gen = struct
  let dir =
    let doc =
      "Input directory tree. This tree can be prepared with the \
       $(b,prepare-package) command."
    in
    Arg.(required & pos 0 (some conv_fpath_dir) None & info [] ~doc ~docv:"DIR")

  let cmd = Term.(const Gen.run $ dir)

  let info = Term.info ~version:"%%VERSION%%" "gen"
end

module Generate = struct
  let paths =
    let doc = "Paths to packages of .odocl files." in
    Arg.(non_empty & pos_all conv_fpath_dir [] & info [] ~docv:"PACKAGES" ~doc)

  let cmd = Term.(const Generate.run $ paths)

  let info =
    Term.info "generate"
      ~doc:"Produce a makefile for generating outputs from odoc files"
end

module PreparePackages = struct
  let packages =
    let doc = "The list of findlib packages to use." in
    Arg.(non_empty & pos_all string [] & info [] ~doc ~docv:"PACKAGES")

  let out =
    let doc = "Output directory." in
    (* Type [string], directory created if needed. *)
    Arg.(required & opt (some string) None & info [ "o" ] ~doc)

  let cmd = Term.(const Prepare_packages.run $ out $ packages)

  let info =
    let doc =
      "Lookup a list of packages and prepare a directory tree that can be \
       passed to $(b,gen)."
    in
    Term.info "prepare-packages" ~doc
end

let _ =
  let cmds =
    [ Gen.(cmd, info); Generate.(cmd, info); PreparePackages.(cmd, info) ]
  and default_cmd = Gen.(cmd, info) in
  Term.exit (Term.eval_choice default_cmd cmds)
