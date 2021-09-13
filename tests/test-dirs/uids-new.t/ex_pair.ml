module type Stringable (*2*) = sig
  type t (*0*)

  val to_string (*1*) : t -> string
end
(**
S_S = λt. Struct ([
  "t", "type" -> Proj(Var t, "t");
  "to_string", "value" -> Proj(Var t, "to_string")
  ])
*)

module Pair (*9*)
  (X (*3*): Stringable (*2*))
  (Y (*4*): Stringable (*2*)) =  struct
  type t (*5*) = X.t (*0*) * Y.t (*0*)

  let to_string (*6*) (x (*7*), y (*8*)) =
    X.to_string (*1*) x (*7*) ^ " " ^
    Y.to_string (*1*) y (*8*)
end
(** Functor Pair:

  S_F = λ t_X. λ t_Y. App(S_Sig, S_Body)
  with  S_Sig = λt. Strutcture ([])
        S_Body = Structure([
          "t", Leaf 5;
          "to_string", Leaf 6 ])
    ~> λ t_X. λ t_Y.Structure([
          "t", Leaf 5;
          "to_string", Leaf 6 ])
*)

module Int (*13*) : Stringable  = struct
  type t (*10*) = int

  let to_string (*11*) i (*12*) = string_of_int i
end
(**
  S_Int = App(S_S, Structure [
    "t", "type" -> Leaf 10;
    "to_string", "value" -> Leaf 11])
  = Structure [
    "t", "type" -> Leaf 10;
    "to_string", "value" -> Leaf 11]
*)

module String (*17*) = struct
  type t (*14*) = string

  let to_string (*15*) s (*16*) = s
end
(** Module String:

  S_String = App (λt. Structure [all_proj], Structure [
      "t", "type" -> Leaf 14;
      "to_string", "value" -> Leaf 15])
    = Structure [
      "t", "type" -> Leaf 14;
      "to_string", "value" -> Leaf 15]
*)

module P (*18*) =
  Pair (*9*)
    (Int (*13*))
    (Pair (*9*) (String (*17*)) (Int(*13*)) : Stringable)
(*

S_P = App(App(S_PAIR, S_Int), App(App(S_Pair, S_String), S_Int))
    = App( λ t_Y.Structure [
          "t", Leaf 5;
          "to_string", Leaf 6 ],
      App( λ t_Y.Structure[
          "t", Leaf 5;
          "to_string", Leaf 6 ], S_Int))
    = App( λ t_Y.Structure [
          "t", Leaf 5;
          "to_string", Leaf 6 ],
       Structure[
          "t", Leaf 5;
          "to_string", Leaf 6 ])
    = Structure [
          "t", Leaf 5;
          "to_string", Leaf 6 ]
*)

let _ = P.to_string (* 6 *)

(**

- Jump to definition P.to_string: UID = Proj(S_P, "to_string") = Leaf 6

- Rename: P.to_string
  Définition -> Leaf 6
  Déclaration -> Leaf 6
*)
