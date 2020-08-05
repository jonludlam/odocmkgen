(* Odoc makefile generator *)

open Mkgen
open Cmdliner


(* Just to find the location of all relevant ocaml cmt/cmti/cmis *)
let read_lib_dir () =
  let ic = Unix.open_process_in "ocamlfind printconf path" in
  let base_dir = input_line ic |> Fpath.of_string in
  match Unix.close_process_in ic, base_dir with
  | Unix.WEXITED 0, Ok p -> p
  | _ -> Format.eprintf "Failed to find ocaml lib path"; exit 1



module Default = struct
    let default () =
      Format.printf {|
default: generate
.PHONY: compile link generate clean html latex man
compile: odocs
link: compile Makefile.link odocls
Makefile.gen : Makefile
	odocmkgen compile
generate: link
odocs:
	mkdir odocs
odocls:
	mkdir odocls
clean:
	rm -rf odocs odocls html latex man Makefile.*link Makefile.gen Makefile.*generate
ifneq ($(MAKECMDGOALS),clean)
-include Makefile.gen
endif
|}
      
  let cmd =
    Term.(const default $ const ())
  
  let info =
    Term.info ~version:"%%VERSION%%" "odocmkgen"
  
end

module Compile = struct

  let compile () =
    let root = read_lib_dir () in
    Compile.run [root]

  let cmd = Term.(const compile $ const ())

  let info = Term.info "compile" ~doc:"Produce a makefile for compiling odoc files"
end

module Link = struct
  let link package =
    Link.run (Fpath.v "odocs") package

  let package =
    let doc = "Select the package to examine" in
    Arg.(required & opt (some string) None & info ["p"; "package"]
            ~docv:"PKG" ~doc)
    
  let cmd = Term.(const link $ package)

  let info = Term.info "link" ~doc:"Produce a makefile for linking odoc files"
  
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

let _ =
  match Term.eval_choice ~err:Format.err_formatter Default.(cmd,info) [Compile.(cmd, info); Link.(cmd, info); Generate.(cmd, info)] with
  | `Error _ ->
    Format.pp_print_flush Format.err_formatter ();
    exit 2
  | _ -> ()


  (* let packages = Findlib.read_all () in *)
  (* let extra_threads =
    let ocaml_package = List.find (fun p -> p.Findlib.package = "threads") packages in
    let threads_dir = Fpath.(ocaml_package.Findlib.dir / "threads") in
    threads_dir
  in *)
  (* let resolved_infos = resolve_deps extra_threads packages infos in
  let deptree = List.map (fun info -> info.digest, info.deps >>= fun d -> match d.dep_digest with | Some x -> [x] | None -> []) in *)
  (* let hashes = List.map (get_hash deptree) (List.map fst deptree) in
  List.iter2 (fun info hash -> Format.printf "%s %s\n" (Digest.to_hex info.digest) (Digest.to_hex hash)) resolved_infos hashes; *)





