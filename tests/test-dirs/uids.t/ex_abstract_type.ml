module type S(*1*) = sig type t(*0*) end
module Int(*3*) = struct type t(*2*) = int end
module Char(*5*) = struct type t(*4*) = char end

module Const(*8*) 
(X : S) (Y : S) : S = X
(*
  Paired by the compiler:
    0 -> 0  (S.t -> X.t)

  Const : S = X:S o Y:S o { 0 -> 0 }
*)


module I2 (*9*) = Const (Int) (Char)
(*

  Int : S
    0 -> 2
  
  Char : S
    0 -> 4
  
  Const = Int:S o Char:S o Const:S
    =  {0 -> 2; 0 -> 4} 
        Information insuffisante !

*)

type a = I2.t (* 0 *)
