module type Arg = sig
  module type S

  module M : S
end
(**
   \x. Struct [
     "S", mty -> Proj (Var x, "S", mty)
     "M", mod -> Proj (Var x, "M", mod)
   ]
*)

module F (X : Arg) = struct
  module N = X.M
end
(**
   \S_x. Struct [
     "N", mod -> Proj (Var S_x, "M", mod)
   ]
*)

module A1 = struct
  module type S = sig type t end
  module M = Int
end
(**
   Struct [
     "S", mty -> \t. Struct [ "t", typ -> Proj (Var t, "t", typ)]
     "M", mod -> Comp_unit Int
   ]
*)

module Raisin = F(A1)
(**
   \Struct [
     "N", mod -> Comp_unit Int
   ]
*)

module Test = Raisin.N

let f (x : Test.t) = ()

module M : sig
  module type Abstr
  module Sub : Abstr
end = struct
  module type Abstr = sig end
  module Sub = struct end
end
(**
   App (M_sig, M_body)
   where
     M_sig = \body. Struct [
       "Abstr" -> Proj (Var body, "Abstr")
       "Sub" -> Proj (Var body, "Sub")
     ]

     M_body = Struct [
       "Abstr" -> Struct []
       "Sub" -> Struct []
     ]

   ==>

     Struct [
       "Abstr" -> Struct []
       "Sub" -> Struct []
     ]

*)

module type Abstr
(**
   Option la plus simple:
     \body. Struct []

   Option équivalente, plus "légère" mais moins régulière donc
   sans doute plus relou:
     Leaf
*)
