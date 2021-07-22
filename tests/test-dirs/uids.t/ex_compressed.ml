(** Paired by the compiler:
  1 -> 0
  4 -> 2
  3 -> 1
*)

module M (* 5 *) : sig
  module N (* 4 *) : sig
    val x (* 3 *) : int
  end
end = struct
  module N (* 2 *): sig
    val x (* 1 *) : int
  end = struct
    let x = 3 (* 0 *)
  end
end

(** Module M compressed:
  { 
    3 -> 0
  }
*)

let _ = M.N.x (* 3 *)
