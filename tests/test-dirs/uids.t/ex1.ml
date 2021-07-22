module type S (* 1 *) = sig
  val x (* 0 *) : int (* <predef:int> *)
end

module type T (* 4 *) = sig
  type t (* 2 *)
  val y (* 3 *): float
end

module M (* 6 *): S (* 1 *) = struct
  let x (* 5 *) = 4
end
(** Module M:

  - Paired by the compiler:
    { 0 -> 5 }

  - Compressed:
    { 0 -> 5 } = C_M

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
(** Functor F
  - Paired by the compiler:
    { 2 -> 8
      3 -> 9
      0 -> 0 }

  - Compressed:
    { 2 -> 8
      3 -> 9 } = C_F
*)

module A (* 11 *) =  F (* 10 *) ( M (* 6 *))
(** Module A
  - Paired by the compiler:
    { 0 -> 0 }
  
  - Compressed = C_F o C_M  =
    { 2 -> 8; 3 -> 9 } o { 0 -> 5 }
    = { 2 -> 8
        3 -> 9
        0 -> 5 }
*)

module B : T (* 4 *) = struct
  type t (* 12 *)
  let y (* 13 *) = 3.14
end
(** Module B
  - Paired by the compiler:
    { 2 -> 12;
      3 -> 13 }
  
  - Compressed = C_B
    { 2 -> 12;
      3 -> 13 }
*)

let y (* 15 *) = A.x (* 0 *) 
let z (* 16 *) = A.y (* 3 *) 


(** 

- Locate def of [A.y]
  - [A.y] has uid 3
  - [A] has coercion C_A
  - C_A(3) = 9
  - 9 is a definition, we return 9

- Usages of definition [M.x]
  - [M.x] has uid 5
  - For all expression uid we inspect the chain:
    1. For [A.y] with uid 3: 
      - C_A(3) = 9
      - 9 is a definition <> 5 z; fail
    2. For [A.x] with uid 0:
      - C_A(0) = 5; succes, this is an usage of [M.x]
    3. etc
*)
