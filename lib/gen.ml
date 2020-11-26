open Util

let split_packages inputs =
  let f inp = function Some lst -> Some (inp :: lst) | None -> Some [ inp ] in
  List.fold_left
    (fun acc inp -> StringMap.update inp.Inputs.package (f inp) acc)
    StringMap.empty inputs

let run whitelist roots =
  let inputs = Inputs.find_inputs ~whitelist roots in
  let packages = split_packages inputs in
  let oc = open_out "Makefile.gen" in
  let fmt = Format.formatter_of_out_channel oc in
  Fun.protect
    ~finally:(fun () ->
      Format.pp_print_flush fmt ();
      close_out oc)
    (fun () ->
      Makefile.(pp fmt (concat [ Compile.gen packages; Link.gen packages ])))
