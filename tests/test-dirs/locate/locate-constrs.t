/**
* VARIANTS
**/

  $ cat >constr.ml <<EOF
  > type t = A of int |  B
  > let foo : t = A 42
  > EOF

  $ $MERLIN single locate -look-for mli -position 2:14 \
  > -filename ./constr.ml < ./constr.ml | jq '.value'
  {
    "file": "$TESTCASE_ROOT/constr.ml",
    "pos": {
      "line": 1,
      "col": 9
    }
  }

We expect 1:9
  $ $MERLIN single locate  -look-for ml -position 2:14 \
  > -filename ./constr.ml < ./constr.ml | jq '.value'
  {
    "file": "$TESTCASE_ROOT/constr.ml",
    "pos": {
      "line": 1,
      "col": 9
    }
  }

With the declaration in another compilation unit:
  $ cat >other_module.ml <<EOF
  > let foo = Constr.B
  > EOF

  $ $OCAMLC -c -bin-annot constr.ml

FIXME: we expect 1:21, we requires a patch in the compiler to add constructors
to the uid_to_decl table.
  $ $MERLIN single locate -look-for mli -position 1:17 \
  > -filename ./other_module.ml < ./other_module.ml | jq '.value'
  {
    "file": "$TESTCASE_ROOT/constr.ml",
    "pos": {
      "line": 1,
      "col": 18
    }
  }

  $ cat >constr.ml <<EOF
  > module C = struct type t = A of int |  B end
  > let foo : t = C.A 42
  > EOF

  $ $MERLIN single locate  -look-for ml -position 2:16 \
  > -filename ./constr.ml < ./constr.ml | jq '.value'
  {
    "file": "$TESTCASE_ROOT/constr.ml",
    "pos": {
      "line": 1,
      "col": 27
    }
  }
