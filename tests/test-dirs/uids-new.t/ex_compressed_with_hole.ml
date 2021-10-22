module M (* 4 *) : sig
  module N (* 3 *) : sig
    val x (* 2 *) : int
  end
end = struct
  module N (* 1 *): sig
    val x (* 0 *) : int
  end = struct
    include An_external_module
  end
end

(** Module M:

  - Paired by the compiler:
    { 0 -> An_external_module.0
      3 -> 1
      2 -> 0 }

  - Compressed:
    { 
      2 -> An_external_module(0)
      3 -> 1
    }
*)

let _ = M.N.x (* 2 *)

module _ = M.N (* 3 *)
