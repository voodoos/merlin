module type S(*1*) = sig type t(*0*) end
module Int(*3*) = struct type t(*2*) = int end
module Char(*5*) = struct type t(*4*) = char end

module Const(*8*) (X(*6*) : S) (Y(*7*) : S) : S = X
(**
  Paired by the compiler:
    0 -> 0  (S.t -> X.t)

  Const : S = X:S o Y:S o { 0 -> 0 }
  {[
    C_Const = Abs ("C_X", Abs("C_Y",
      Subst(
        { 0 -> Stuck(["C_X"], 0)},
        {}
      )
    ))
  ]}
*)


module I2 (*9*) = Const (Int) (Char)
(**
  Paired by the compiler
      Int : S
        0 -> 2
      
      Char : S
        0 -> 4

  {[
    C_Int = Subst ({ 0 -> Final 2}, {})
  ]}

  {[
    C_Char = Subst ({ 0 -> Final 4}, {})
  ]}
  
  {[
    C_I2 = apply (apply C_Const C_Int) C_Char
         = apply (Abs("C_Y", Subst ({ 0 -> lookup C_Int 0}))) C_Char
         = apply (Abs("C_Y", Subst ({ 0 -> Final 2}, {}))) C_Char
         = Subst ({ 0 -> Final 2} {})
  ]}

*)

type a = I2.t (* 0 *)
