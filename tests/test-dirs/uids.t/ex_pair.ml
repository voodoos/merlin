module type Stringable (*2*) = sig
  type t (*0*)

  val to_string (*1*) : t -> string
end

module Pair (*9*)
  (X (*3*): Stringable (*2*)) 
  (Y (*4*): Stringable (*2*)) =  struct
  type t (*5*) = X.t (*0*) * Y.t (*0*)

  let to_string (*6*) (x (*7*), y (*8*)) = 
    X.to_string (*1*) x (*7*) ^ " " ^ 
    Y.to_string (*1*) y (*8*)
end
(** Functor Pair:

  - Paired by the compiler: {}

  - Compressed: C_Pair = {} (identity) 
*)

module Int (*13*) : Stringable  = struct
  type t (*10*) = int

  let to_string (*11*) i (*12*) = string_of_int i
end
(** Module Int:

  - Paired by the compiler: 
    { 0 -> 10
      1 -> 11 }

  - Compressed: C_Int = 
    { 0 -> 10
      1 -> 11 }
*)

module String (*17*) = struct
  type t (*14*) = string

  let to_string (*15*) s (*16*) = s
end
(** Module String:

  - Paired by the compiler: { }

  - Compressed: C_String = { }
*)

module P (*18*) = 
  Pair (*9*) 
    (Int (*13*)) 
    (Pair (*9*) (String (*17*)) (Int(*13*)))
(*

String : Stringable
  - Paired by the compiler: 
    { 0 -> 14
      1 -> 15 } = C_String

Pair : Stringable
  - Paired by the compiler: 
    { 0 -> 5
      1 -> 6 } = C_Pair

P :  C_P = C_Pair o (C_Int U (C_Pair o (C_String U C_Int))
    = C_Int U C_String U C_Int car C_Pair = identity
    = { 0 -> 10
        1 -> 11 
        0 -> 14
        1 -> 15
        0 -> 5
        1 -> 6
    }

    (??)
*)

let _ = P.to_string (* 6 *)

(**

- Jump to definition P.to_string: UID = 6
  - UID 6 is already a definition

- Jump to declaration P.to_string: UID = 6
  - Reverse search in C_P = 1 Note that current locate implementation will not
    find this result.

*)
