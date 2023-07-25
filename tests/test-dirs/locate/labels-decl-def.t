In the same file
  $ cat >labels.ml <<EOF
  > module A : sig
  >   type t = { lbl : string }
  > end = struct 
  >   type t = { lbl : string }
  > end
  > open A
  > let _ : t = { lbl = "label" }
  > EOF

Merlin finds the declaration
  $ $MERLIN single locate -look-for mli -position 7:15 \
  > -filename ./labels.ml < ./labels.ml | jq '.value.pos'
  {
    "line": 2,
    "col": 13
  }

And the definition
  $ $MERLIN single locate -look-for ml -position 7:15 \
  > -filename ./labels.ml < ./labels.ml | jq '.value.pos'
  {
    "line": 4,
    "col": 13
  }

In a separate CU
  $ cat >a.mli <<EOF
  > type t = { lbl : string }
  > EOF

  $ cat >a.ml <<EOF
  > type t = { lbl : string }
  > EOF

  $ cat >labels.ml <<EOF
  > open A
  > let _ : t = { lbl = "label" }
  > EOF

  $ $OCAMLC -c -bin-annot a.mli a.ml

Merlin finds the declaration
FIXME: expecting mli and col 13 (this requires compiler changes)
  $ $MERLIN single locate -look-for mli -position 2:15 \
  > -filename ./labels.ml < ./labels.ml | jq '.value'
  {
    "file": "$TESTCASE_ROOT/a.ml",
    "pos": {
      "line": 1,
      "col": 11
    }
  }

And the definition
FIXME: expecting col 13 (this requires compiler changes)
  $ $MERLIN single locate -look-for ml -position 2:15 \
  > -filename ./labels.ml < ./labels.ml | jq '.value'
  {
    "file": "$TESTCASE_ROOT/a.ml",
    "pos": {
      "line": 1,
      "col": 11
    }
  }
