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




(* let resolve_deps extra_threads packages infos =
  List.map (fun info ->
    if not (List.exists (fun dep -> dep.dep_digest = None) info.deps)
    then info
    else begin
      let pkgs = List.filter (fun pkg -> pkg.Findlib.dir = info.dir) packages in
      if List.length pkgs > 1 then Format.eprintf "More than one package for %s [%s]\n%!" info.name (String.concat ", " (List.map (fun pkg -> pkg.Findlib.package) pkgs));
      let dirs = List.fold_left (fun acc d -> d.Findlib.dependencies @ acc) [] pkgs in
      let deps = List.map (fun dep ->
        if dep.dep_digest = None
        then begin
          let resolved = List.filter (fun i -> List.mem i.dir (info.dir :: extra_threads :: dirs) && i.name = dep.dep_unit_name) infos in
          if List.length resolved = 0 then begin
            Format.printf "%s (%a): can't resolve %s\n%!" info.name Fpath.pp info.dir dep.dep_unit_name;
            Format.printf "search dirs: (%d) %a\n" (List.length (info.dir :: dirs)) (Findlib.list Fpath.pp) (info.dir :: dirs);
            List.iter (fun i -> Format.printf "%a\n%!" Fpath.pp i.path) (List.filter (fun i -> List.mem i.dir (info.dir::dirs)) infos);
            exit 1
          end;
          { dep with dep_digest = Some (List.hd resolved).digest }
        end
        else dep) info.deps in
      {info with deps}
    end
  ) infos *)


module Default = struct
    let default () =
      Format.printf {|
default: generate
.PHONY: compile link generate clean
compile: odocs
link: compile Makefile.link odocls
Makefile.compile:
	odocmkgen compile > Makefile.compile
Makefile.link: Makefile.compile
	odocmkgen link > Makefile.link
generate: link
odocs:
	mkdir odocs
odocls:
	mkdir odocls
clean:
	rm -rf odocs odocls html Makefile.link Makefile.compile
include Makefile.compile
include Makefile.link
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
  let link () =
    Link.run (Fpath.v "odocs")

  let cmd = Term.(const link $ const ())

  let info = Term.info "link" ~doc:"Produce a makefile for linking odoc files"
  
end

let _ =
  match Term.eval_choice ~err:Format.err_formatter Default.(cmd,info) [Compile.(cmd, info); Link.(cmd, info)] with
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





