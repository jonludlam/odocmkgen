let run whitelist roots =
  let inputs = Inputs.find_inputs ~whitelist roots in
  let oc = open_out "Makefile.gen" in
  let fmt = Format.formatter_of_out_channel oc in
  Fun.protect
    ~finally:(fun () ->
      Format.pp_print_flush fmt ();
      close_out oc)
    (fun () ->
      Makefile.(pp fmt (concat [ Compile.gen inputs; Link.gen inputs ])))