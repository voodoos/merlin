module type S(*1*) = sig
  type t(*0*)
end
(*
  S_S = λ t. Structure ["t" -> Proj(Var t, "t")]
*)

module type Sx(*3*) = sig
  include S(*1*)
  val x(*2*) : int
end
(*
  S_SX = λ t. Structure [
    ...(App(S_S, Var t) = Structure ["t" -> Proj(Var t, "t")]);
    "x" -> Proj(Var t, "x")]
  = λ t. Structure [
    "t" -> Proj(Var t, "t");
    "x" -> Proj(Var t, "x")]
*)

module M(*6*) : Sx(*3*) = struct
  type t(*4*)
  let x(*5*) = 42
end
(*
  S_M = App(S_Sx, Structure [
    "t" -> Leaf 4;
    "x" -> Leaf 5])
  ~> Structure [
    "t" -> Leaf 4;
    "x" -> Leaf 5]
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
(**

  S_F = λ tX tY. App(S_Sig, S_Body)
  where:
    S_sig = λ t. Structure [
      ...(App(S_S, Var t) = Structure ["t" -> Proj(Var t, "t")]);
      "A" -> App(S_S, Proj(Var t, "A"));
      "B" -> S_M
      "C" ->
        App ((\s. Structure ["t" -> Proj (Var s. "t")]), Proj (Var t, "C"))
        = Structure ["t" -> Proj (Proj (Var t, "C"), "t")]
      ]
    ]
    = λ t. Structure [
      "t" -> Proj(Var t, "t");
      "A" -> Structure ["t" -> Proj(Proj(Var t, "A"), "t")]
      "B" -> S_M
      "C" -> Proj(Var t, "C")
    ]

    S_Body = Structure [
      "t" -> Proj(Var tX, "t") //include X
      "A" -> Structure [
        "t" -> Proj(Var tY, "t"); //include Y
        "x" -> Proj(Var tY, "x")  //include Y
      ];
      "B" -> S_M;
      "C" -> Structure [
        "t" -> Proj(var tX, "t")
      ]
    ]

  S_F = λ tX tY. Structure [
      "t" -> Proj(Var tX, "t");
      "A" -> Structure ["t" -> Proj(Proj(S_Body, "A"), "t")]
             = Proj(Var tY, "t")
      "B" -> S_M
      "C" ->
        Structure ["t" -> Proj (Proj(S_Body, "C"), "T"))]
        = Structure [
        "t" -> Proj(var tX, "t")
      ]
    ]

*)

module FsN(*20*) = F(*18*) (struct type t(*19*) end) (M(*6*))
(*
  S_FsN = App(App(S_F, Structure ["t" -> Leaf 19]), S_M)
    = App(
      λ tY. Structure [
        "t" -> Leaf 19;
        "A" -> Structure ["t" -> Proj(Proj(S_Body, "A"), "t")]
              = Structure ["t" -> Proj(Var tY, "t")]
        "B" -> S_M
        "C" -> Structure [
                "t" -> Proj(Structure ["t" -> Leaf 19], "t")
              ]
      ],
      Structure [
        "t" -> Leaf 4;
        "x" -> Leaf 5]
    )
    = Structure [
        "t" -> Leaf 19;
        "A" -> Structure ["t" -> Leaf 4]
        "B" -> Structure [
                "t" -> Leaf 4;
                "x" -> Leaf 5 ]
        "C" -> Structure [
                "t" -> Leaf 19
              ]
      ]
*)

type a = FsN.t (* 0 *)
(*
  Proj(S_FsN, "t") = Leaf 19
*)

type b = FsN.A.t (* 0 *)
(*
  Proj(Proj(S_FsN, "A"), "t") = Leaf 4
*)

type c = FsN.B.t (*0*)
(*
  Proj(Proj(S_FsN, "B"), "t") = Leaf 4
*)
