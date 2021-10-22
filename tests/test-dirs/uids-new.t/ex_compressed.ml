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

(** Module M 
  - Paired by the compiler:
    0 -> 1
    2 -> 4
    1 -> 3

  - Compressed:
    { 
      0 -> 3
      2 -> 4
    }
*)

let _ = M.N.x (* 3 *)
