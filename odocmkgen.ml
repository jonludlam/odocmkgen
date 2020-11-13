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

(* Just to find the location of all relevant ocaml cmt/cmti/cmis *)
let read_lib_dir () =
  match Util.lines_of_process "ocamlfind printconf path" with
  | [ base_dir ] -> base_dir
  | _ ->
      Format.eprintf "Failed to find ocaml lib path";
      exit 1

let read_doc_dir () =
  let dir = read_lib_dir () in
  Fpath.(to_string (fst (Fpath.split_base (v dir)) / "doc"))

module Default = struct
    let default whitelist lib_dir doc_dir =
      let lib_dir =
        match lib_dir with
        | [] -> [read_lib_dir ()]
        | _ -> lib_dir
      in
      let doc_dir =
        match doc_dir with
        | [] -> [read_doc_dir ()]
        | _ -> doc_dir
      in
      let pp_whitelist fmt = function
        | [] -> ()
        | wl -> Format.fprintf fmt " -w %s" (String.concat "," wl)
      in
      let pp_libdir fmt l =
        List.iter (fun lib -> Format.fprintf fmt " -L %s" lib) l
      in
      let pp_docdir fmt l =
        List.iter (fun lib -> Format.fprintf fmt " -D %s" lib) l
      in
      Format.printf {|
default: generate
.PHONY: compile link generate clean html latex man
compile: odocs
link: compile odocls
Makefile.gen : Makefile
	odocmkgen gen%a%a%a
generate: link
odocs:
	mkdir odocs
odocls:
	mkdir odocls
clean:
	rm -rf odocs odocls html latex man Makefile.*link Makefile.gen Makefile.*generate
html: html/odoc.css
html/odoc.css:
	odoc support-files --output-dir html
ifneq ($(MAKECMDGOALS),clean)
-include Makefile.gen
endif
|} pp_whitelist whitelist pp_libdir lib_dir pp_docdir doc_dir

  let whitelist =
    Arg.(value & opt (list string) [] & info ["w"; "whitelist"])

  let lib_dir =
    let doc =
      "Path to libraries. If not set, defaults to the global environment by \
       querying $(b,ocamlfind)."
    in
    (* [some string] and not [some dir] because we don't need it to exist yet. *)
    Arg.(value & opt_all (string) [] & info ["L"] ~doc ~docv:"LIB_DIR")

  let doc_dir =
    let doc =
      "Path to docs"
    in
    (* [some string] and not [some dir] because we don't need it to exist yet. *)
    Arg.(value & opt_all (string) [] & info ["D"] ~doc ~docv:"DOC_DIR")
  
  let cmd =
    Term.(const default $ whitelist $ lib_dir $ doc_dir)

  let info =
    Term.info ~version:"%%VERSION%%" "odocmkgen"
end

module Gen = struct

  let whitelist =
    Arg.(value & opt (list string) [] & info ["w"; "whitelist"])

    let lib_dir =
      let doc =
        "Path to libraries. If not set, defaults to the global environment by \
         querying $(b,ocamlfind)."
      in
      let fpath_dir = conv_compose Fpath.of_string Fpath.to_string Arg.dir in
      (* [some string] and not [some dir] because we don't need it to exist yet. *)
      Arg.(value & opt_all (fpath_dir) [] & info ["L"] ~doc ~docv:"LIB_DIR")

  let doc_dir =
    let doc =
      "Path to docs"
    in
    let fpath_dir = conv_compose Fpath.of_string Fpath.to_string Arg.dir in
    (* [some string] and not [some dir] because we don't need it to exist yet. *)
    Arg.(value & opt_all (fpath_dir) [] & info ["D"] ~doc ~docv:"DOC_DIR")

  let cmd = Term.(const Gen.run $ whitelist $ lib_dir $ doc_dir)

  let info = Term.info "gen" ~doc:"Produce a makefile for building the documentation."

end

module Generate = struct
  let generate package =
    Generate.run (Fpath.v "odocls") package

  let package =
    let doc = "Select the package to examine" in
    Arg.(required & opt (some string) None & info ["p"; "package"]
            ~docv:"PKG" ~doc)
    
  let cmd = Term.(const generate $ package)

  let info = Term.info "generate" ~doc:"Produce a makefile for generating outputs from odoc files"
  
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
  match Term.eval_choice ~err:Format.err_formatter Default.(cmd,info) [Gen.(cmd, info); Generate.(cmd, info); OpamDeps.(cmd, info)] with
  | `Error _ ->
    Format.pp_print_flush Format.err_formatter ();
    exit 2
  | _ -> ()
