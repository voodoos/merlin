module type S1 (* 1 *) = 
  sig type t (* 0 *) end

module Int (* 3 *) = 
  struct type t (* 2 *) end

module Ie (* 5 *) (X (* 4 *) : S1) = X

module IEI (* 6 *) = Ie (Int)
(* Paired 0 -> 2 *)

type a = IEI.t (* 0 *)

module IEIEI (* 8 *) = Ie (Ie (Int))
(* Paired
    0 -> 2
    0 -> 0
*)

type b = IEIEI.t (* 0 *)
