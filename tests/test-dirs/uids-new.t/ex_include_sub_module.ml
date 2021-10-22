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

  [
    C_F = Abs (["C_X"], 
      Subst (
        { 5 -> Stuck (["C_X"; "C_M"], 0) }, 
        {}s
      )
    )
  ]

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
  
  [
    C_N = Subst (
      {
        0 -> Final 7;
        2 -> Final 9
      },
      {
        "C_M" -> Subst ({ 0 -> Final 8}, {}) (= C_M)
      }
    )
  ]

  [ 
    C_FN = apply C_F C_N
      (* We arrive at Stuck (["C_X"; "C_M"], 0) *)
      = Subst (
          { 5 -> unstuck ["C_M"] 0 C_N
            (* We lookup_mod "C_M" in C_N and find C_M *)
            = unstuck [] 0 C_M
            = lookup C_M 0 = lookup (Subst ({ 0 -> Final 8}, {})) 0
            = Final 8 })
      = Subst ({ 5 -> Final 8 }, {})
  ]
  
*)

type a = FN.t (*5*)
