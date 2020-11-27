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

module Default = struct
    let default whitelist dirs =
      let pp_whitelist fmt = function
        | [] -> ()
        | wl -> Format.fprintf fmt " -w %s" (String.concat "," wl)
      in
      let pp_dirs fmt l =
        List.iter (fun lib -> Format.fprintf fmt " %s" lib) l
      in
      Format.printf {|
default: generate
.PHONY: compile link generate clean html latex man
compile: odocs
link: compile odocls
Makefile.gen : Makefile
	odocmkgen gen%a%a
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
|} pp_whitelist whitelist pp_dirs dirs

  let whitelist =
    Arg.(value & opt (list string) [] & info ["w"; "whitelist"])

  let dirs =
    let doc =
      "Path to libraries. They can be found by querying $(b,ocamlfind query -r my_package)."
    in
    (* [some string] and not [some dir] because we don't need it to exist yet. *)
    Arg.(value & pos_all string [] & info [] ~doc ~docv:"DIR")

  let cmd =
    Term.(const default $ whitelist $ dirs)

  let info =
    Term.info ~version:"%%VERSION%%" "odocmkgen"
end

module Gen = struct

  let whitelist =
    Arg.(value & opt (list string) [] & info ["w"; "whitelist"])

  let dirs =
    let doc = "Path to libraries." in
    let fpath_dir = conv_compose Fpath.of_string Fpath.to_string Arg.dir in
    (* [some string] and not [some dir] because we don't need it to exist yet. *)
    Arg.(value & pos_all fpath_dir [] & info [] ~doc ~docv:"DIR")

  let cmd = Term.(const Gen.run $ whitelist $ dirs)

  let info =
    Term.info "gen" ~doc:"Produce a makefile for building the documentation."
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

module PackageIndex = struct
  let string_starts str prefix =
    let slen = String.length str and plen = String.length prefix in
    plen <= slen && prefix = String.sub str 0 plen

  let gen pkg childs =
    ignore childs;
    Format.printf "{0 %s}@\n@\n" pkg;
    List.iter
      (fun c ->
        let c = if string_starts c "page-" then c else "module-" ^ c in
        Format.printf "- {!%s}@\n" c)
      childs

  let pkg =
    let doc = "The name of the package." in
    Arg.(required & pos 0 (some string) None & info [] ~doc ~docv:"PKG")

  let childs =
    let doc = "Child modules/pages." in
    Arg.(value & pos_all string [] & info [] ~doc ~docv:"CHILD")

  let cmd = Term.(const gen $ pkg $ childs)

  let info =
    Term.info "package-index"
      ~doc:"Generate the index page for a package. (internal)"
end

let _ =
  let cmds =
    [
      Gen.(cmd, info);
      Generate.(cmd, info);
      OpamDeps.(cmd, info);
      PackageIndex.(cmd, info);
    ]
  and default_cmd = Default.(cmd, info) in
  Term.exit (Term.eval_choice default_cmd cmds)
