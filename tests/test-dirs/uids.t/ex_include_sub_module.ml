module type S0(*1*) = sig
  type t (*0*)
end

module type S(*3*) = sig
  include S0
  module M (*2*): sig
    include S0
  end
end

module F(*6*)(X(*4*) : S(*3*)) : sig type t(*5*) end 
  = struct include X.M(*2*) end

(**

  Paired by the compiler:
    5 -> 0

  fun C_X -> { 
    5 -> C_X.C_M[0]
  }

*)

module N(*10*)= struct
  type t(*7*)
  module M(*9*) = struct 
    type t(*8*)
  end
end

module FN (*11*) = F (N) 
(**

  Paired by the compiler:
    N: 0 -> 7
       2 -> 9
    
    N.M: 0 -> 8

  C_N: {
    0 -> 7
    2 -> 9
    C_M : { 0 -> 8 }
  }

  C_FN = {
    5 -> C_N.C_M[0]
  }

*)

type a = FN.t (*5*)

(*
  5 -> C_N.C_M[0] = 8
*)
