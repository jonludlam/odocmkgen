type rule = {
  targets : string list;
  deps : string list;
  oo_deps : string list;
  recipe : string list;
}

type cmd = string list -> string

type t = Rule of rule | Concat of t list | Include of string

let cmd_to_string cmd = cmd []

let concat ts = Concat ts

let rule' targets ?(fdeps = []) ?(deps = []) ?(oo_deps = []) recipe =
  let deps = List.map Fpath.to_string fdeps @ deps in
  let recipe = List.map cmd_to_string recipe in
  Rule { targets; deps; oo_deps; recipe }

let rule targets ?fdeps ?deps ?oo_deps recipe =
  let targets = List.map Fpath.to_string targets in
  rule' targets ?fdeps ?deps ?oo_deps recipe

let phony_rule target ?fdeps ?deps ?oo_deps recipe =
  Concat
    [
      rule' [ target ] ?fdeps ?deps ?oo_deps recipe;
      rule' [ ".PHONY" ] ~deps:[ target ] [];
    ]

let include_ p = Include (Fpath.to_string p)

let pp_rule fmt t =
  let open Format in
  let pp_deps =
    let pp_sep fmt () = pp_print_string fmt " " in
    pp_print_list ~pp_sep pp_print_string
  in
  let pp_oo_deps fmt = function
    | [] -> ()
    | deps -> fprintf fmt " | %a" pp_deps deps
  in
  let pp_recipe fmt = List.iter (fprintf fmt "\t%s@\n") in
  fprintf fmt "%s : %a%a@\n%a"
    (String.concat " " t.targets)
    pp_deps t.deps pp_oo_deps t.oo_deps pp_recipe t.recipe

let pp_include fmt p = Format.fprintf fmt "-include %s@\n" p

let rec pp fmt = function
  | Rule rule -> pp_rule fmt rule
  | Concat ts ->
      let pp_sep = Format.pp_print_newline in
      Format.pp_print_list ~pp_sep pp fmt ts
  | Include p -> pp_include fmt p

let cmd ?stdin ?stdout ?stderr cmd acc =
  Filename.quote_command cmd ?stdin ?stdout ?stderr acc

let ( $ ) cmd arg acc = cmd (arg :: acc)

let ( $$ ) cmd args acc = cmd (args @ acc)
