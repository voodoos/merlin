module type S(*1*) = sig type t(*0*) end
module type Sx(*3*) = sig 
  include S(*1*) 
  val x(*2*) : int
end

module M(*6*) : Sx(*3*) = struct
  type t(*4*)
  let x(*5*) = 42
end
(* Paired by the compiler:
    0 -> 4
    2 -> 5
*)

module F(*18*) (X(*7*) : S(*1*)) (Y(*8*) : Sx(*3*)) : sig
  include S(*1*)
  module A(*14*) : S(*1*)
  module B(*15*) = M(*6*)
  module C(*17*): sig
    type t(*16*)
  end
end = struct
  include X(*7*)

  module A(*10*) = struct
    include Y
  end

  module B (*11*) = M (*6*)

  module C (*13*)= struct
    type t (*12*) = X.t (*0*)
  end
end
(* Paired by the compiler:
    0 -> 0 (S.t -> X.t)
    14 -> 10 (module A : S -> module A = ...)
    15 -> 11 (module B = M -> module B = M)
    17 -> 13 (module C : ... -> module C = ...)
  
  And:
    C_A: 0 -> C_Y[0] 
    C_C: 12 -> 16

    C_B = C_M

  C_F = C_X -> C_Y -> {
      0 -> C_X[O]
      14 -> 10
      15 -> 11
      17 -> 13
    }

*)

module FsN(*20*) = F(*18*) (struct type t(*19*) end) (M(*6*))
(* Paired by the compiler:
    For first arg: 0 -> 19
    
    C_FsN = {
      0 -> C_first_arg[O] = 19
      14 -> 10
      15 -> 11
      17 -> 13
      C_A: 0 -> 4
      C_C
    }
*)
    
type a = FsN.t (* 0 *)
(* 
  JTDef: C_FsN[0] = C_X[0] = 19
*)

type b = FsN.A.t (* 0 *)
(*
  C_FsN.C_A[0] = 4
*)

type c = FsN.B.t (*0*)
(*
  FsN.C_B[0]
*)
