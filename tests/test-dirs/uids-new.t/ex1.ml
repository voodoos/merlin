module type S (* 1 *) = sig
  val x (* 0 *) : int (* <predef:int> *)
end
(**
S_S = λ t. Struct ([ "x", _ns -> Proj(Var t, "x") ])
*)

module type T (* 4 *) = sig
  type t (* 2 *)
  val y (* 3 *): float
end
(**
S_T = λt. Struct ([ "t", _ns -> Proj(Var t, "t");
                    "y", _ns -> Proj(Var t, "y") ])
*)

module M (* 6 *): S (* 1 *) = struct
  let x (* 5 *) = 4
end
(** Module M:
  S_M = Struct ([ "x", _ns -> Leaf(5) ])

  App (S_S, S_M) = App(
    λ t. Struct ([ "x", _ns -> Proj(Var t, "x") ]),
    Struct ([ "x", _ns -> Leaf(5) ])
  )

  ~> Struct ([ "x", _ns -> Proj(Struct ([ "x", _ns -> Leaf(5)]), "x") ])
     = Struct ([ "x", _ns -> Leaf(5) ])
*)

module F (* 10 *) (X (* 7 *) : S (* 1 *)) :
  sig
    include T (* 4 *)
    include S (* 1 *)
  end = struct
    type t (* 8 *)
    include X (* 7 *)
    let y (* 9 *) = 1.0
end
(**

  S_F = λ t_X. App(S_Sig, S_Body)
  where
    S_Body = Struct ( [
      "t" -> Leaf 8,
      "x", _ns -> Proj(Var t_X, "x") // "App (S_S, t_x)",
      "y" -> Leaf 9
    ])

    S_Sig = λt. Structure ([
      ...App(S_T, Var t);
      ...App(S_S, Var t);
    ]) = λt. Structure ([
      "t", _ns -> Proj(Var t, "t");
      "y", _ns -> Proj(Var t, "y");
      "x", _ns -> Proj(Var t, "x")
    ])

S_F = λ t_X. Structure [
      "t", _ns -> Leaf 8;
      "y", _ns -> Leaf 9;
      "x", _ns -> Proj(Var t_X, "x")
    ]
*)

module A (* 11 *) =  F (* 10 *) ( M (* 6 *))
(**

S_A = App(S_F, S_M) = App(S_F, Struct ([ "x", _ns -> Leaf(5) ]))
    ~>  Structure [
      "t", _ns -> Leaf 8;
      "y", _ns -> Leaf 9;
      "x", _ns -> Proj(Struct ([ "x", _ns -> Leaf(5) ]), "x")
    ]
    =  Structure [
      "t", _ns -> Leaf 8;
      "y", _ns -> Leaf 9;
      "x", _ns -> Leaf 5
    ]

*)

let y (* 15 *) = A.x (* 0 *)
(* Proj(S_A, "x") = Leaf 5 *)

let z (* 16 *) = A.y (* 3 *)
(* Proj(S_A, "y") = Leaf 9 *)


(**

- Usages of definition [M.x]
  - Proj(S_M, "x") = Leaf 5

  - [M.x] has uid 5
  - For all expression uid we inspect the chain:
    1. For [A.y] with uid 3:
      - C_A(3) = 9
      - 9 is a definition <> 5 z; fail
    2. For [A.x] with uid 0:
      - C_A(0) = 5; succes, this is an usage of [M.x]
    3. etc
*)
