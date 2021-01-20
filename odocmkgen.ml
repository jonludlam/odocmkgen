(* Odoc makefile generator *)

open Mkgen
open Cmdliner

(** Example: [conv_compose Fpath.of_string Fpath.to_string Arg.dir] *)
let conv_compose ?docv parse to_string c =
  let open Arg in
  let docv = match docv with Some v -> v | None -> conv_docv c in
  let parse v =
    match conv_parser c v with
    | Ok x -> parse x
    | Error _ as e -> e
  and print fmt t = conv_printer c fmt (to_string t) in
  conv ~docv (parse, print)

(** Like [Cmdliner.Arg.dir] but return a [Fpath.t] *)
let conv_fpath_dir = conv_compose Fpath.of_string Fpath.to_string Arg.dir

(* Just to find the location of all relevant ocaml cmt/cmti/cmis *)
let read_lib_dir () =
  match Util.Process_util.lines_of_process "ocamlfind printconf path" with
  | [ base_dir ] -> base_dir
  | _ ->
      Format.eprintf "Failed to find ocaml lib path";
      exit 1

let read_doc_dir () =
  let dir = read_lib_dir () in
  Fpath.(to_string (fst (Fpath.split_base (v dir)) / "doc"))

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

module OpamDeps = struct
  let deps () = 
    let pkgs = Opam.all_opam_packages () in
    let deps = List.map Opam.calc_deps pkgs in
    List.iter2 (fun pkg deps ->
      let oc = open_out (Format.asprintf "%a" Opam.pp_package pkg) in
      let pp = Format.formatter_of_out_channel oc in
      Opam.S.iter (fun pkg -> Format.fprintf pp "%a\n%!" Opam.pp_package pkg) deps;
      close_out oc
      ) pkgs deps

  let cmd = Term.(const deps $ const ())

  let info = Term.info "deps" ~doc:"Lists the transitive closure of the deps of the specified package"

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
    [
      Gen.(cmd, info);
      Generate.(cmd, info);
      OpamDeps.(cmd, info);
      PreparePackages.(cmd, info);
    ]
  and default_cmd = Gen.(cmd, info) in
  Term.exit (Term.eval_choice default_cmd cmds)
