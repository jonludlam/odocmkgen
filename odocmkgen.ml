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
  let prelude =
    let open Makefile in
    concat
      [
        phony_rule "default" ~deps:[ "link" ] [];
        phony_rule "compile" ~oo_deps:[ "odocs" ] [];
        phony_rule "link" ~deps:[ "compile" ] ~oo_deps:[ "odocls" ] [];
        phony_rule "clean" [ cmd "rm" $ "-r" $ "odocs" $ "odocls" ];
        rule [ Fpath.v "odocs" ] [ cmd "mkdir" $ "odocs" ];
        rule [ Fpath.v "odocls" ] [ cmd "mkdir" $ "odocls" ];
      ]

  let run whitelist roots =
    let inputs = Inputs.find_inputs ~whitelist roots in
    let makefile =
      let open Makefile in
      concat [ prelude; Compile.gen inputs; Link.gen inputs ]
    in
    Format.printf "%a\n" Makefile.pp makefile

  let whitelist =
    Arg.(value & opt (list string) [] & info [ "w"; "whitelist" ])

  let dirs =
    let doc =
      "Path to libraries. They can be found by querying $(b,ocamlfind query -r \
       my_package)."
    in
    Arg.(value & pos_all conv_fpath_dir [] & info [] ~doc ~docv:"DIR")

  let cmd = Term.(const run $ whitelist $ dirs)

  let info = Term.info ~version:"%%VERSION%%" "odocmkgen"
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

let _ =
  match Term.eval_choice ~err:Format.err_formatter Gen.(cmd,info) [Gen.(cmd, info); Generate.(cmd, info); OpamDeps.(cmd, info)] with
  | `Error _ ->
    Format.pp_print_flush Format.err_formatter ();
    exit 2
  | _ -> ()
