let run whitelist roots docroots =
  let inputs = Inputs.find_inputs ~whitelist (roots @ docroots) in
  let oc = open_out "Makefile.gen" in
  Fun.protect
    ~finally:(fun () -> close_out oc)
    (fun () ->
      Compile.gen oc inputs;
      Link.gen oc inputs)
