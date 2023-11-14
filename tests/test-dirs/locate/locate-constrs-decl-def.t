/**
* VARIANTS
**/

  $ cat >constr.mli <<EOF
  > type t = A of int |  B
  > type u = { label_a : int }
  > EOF

  $ cat >constr.ml <<EOF
  > type u = { label_a : int }
  > type t = A of int |  B
  > let foo : t = A 42
  > EOF

  $ cat >main.ml <<EOF
  > let foo : Constr.t = Constr.A 42
  > let bar : Constr.u = { Constr.label_a = 42 }
  > EOF

  $ $OCAMLC -c -bin-annot -store-usage-index constr.mli constr.ml

  $ $MERLIN single locate -look-for mli -position 1:28 \
  > -filename ./main.ml < ./main.ml | jq '.value'
  {
    "file": "$TESTCASE_ROOT/constr.mli",
    "pos": {
      "line": 1,
      "col": 9
    }
  }

  $ $MERLIN single locate -look-for ml -position 1:28 \
  > -filename ./main.ml < ./main.ml | jq '.value'
  {
    "file": "$TESTCASE_ROOT/constr.ml",
    "pos": {
      "line": 2,
      "col": 9
    }
  }

  $ $MERLIN single locate -look-for mli -position 2:30 \
  > -filename ./main.ml < ./main.ml | jq '.value'
  {
    "file": "$TESTCASE_ROOT/constr.mli",
    "pos": {
      "line": 2,
      "col": 11
    }
  }

  $ $MERLIN single locate -look-for ml -position 2:30 \
  > -filename ./main.ml < ./main.ml | jq '.value'
  {
    "file": "$TESTCASE_ROOT/constr.ml",
    "pos": {
      "line": 1,
      "col": 11
    }
  }

  $ cat >main.ml <<EOF
  > module Constr : sig
  >   type t = A of int |  B
  >   type u = { label_a : int }
  > end = struct
  >   type u = { label_a : int }
  >   type t = A of int |  B
  > end
  > let foo : Constr.t = Constr.A 42
  > let bar : Constr.u = { Constr.label_a = 42 }
  > EOF

  $ $MERLIN single locate -look-for mli -position 8:28 \
  > -filename ./main.ml < ./main.ml | jq '.value.pos'
  {
    "line": 2,
    "col": 11
  }

  $ $MERLIN single locate -look-for ml -position 8:28 \
  > -filename ./main.ml < ./main.ml | jq '.value.pos'
  {
    "line": 6,
    "col": 11
  }


  $ $MERLIN single locate -look-for mli -position 9:30 \
  > -filename ./main.ml < ./main.ml | jq '.value.pos'
  {
    "line": 3,
    "col": 13
  }

  $ $MERLIN single locate -look-for ml -position 9:30 \
  > -filename ./main.ml < ./main.ml | jq '.value.pos'
  {
    "line": 5,
    "col": 13
  }
