Recent changes to shape could break this behavior

  $ cat >test.ml <<EOF
  > module A = struct type t end
  > module B = A 
  > type u = B.t
  > EOF

  $ $MERLIN single locate -look-for ml -position 3:11 \
  > -filename test.ml <test.ml | jq '.value'
  {
    "file": "$TESTCASE_ROOT/test.ml",
    "pos": {
      "line": 1,
      "col": 18
    }
  }

Aliases and functors:
  $ cat >main.ml <<EOF
  > module A = struct type t end
  > module B = A
  > module F (X : sig type t end) = struct module M = X end
  > module C = F(A)
  > module D = F(B)
  > module _ = C.M
  > module _ = D.M
  > type u = C.M.t
  > type v = D.M.t
  > EOF

  $ $MERLIN single locate -look-for ml -position 6:13 \
  > -filename main.ml <main.ml | jq '.value.pos'
  {
    "line": 1,
    "col": 0
  }

  $ $MERLIN single locate -look-for ml -position 7:13 \
  > -filename main.ml <main.ml | jq '.value.pos'
  {
    "line": 1,
    "col": 0
  }

  $ $MERLIN single locate -look-for ml -position 8:13 \
  > -filename main.ml <main.ml | jq '.value.pos'
  {
    "line": 1,
    "col": 18
  }

  $ $MERLIN single locate -look-for ml -position 9:13 \
  > -filename main.ml <main.ml | jq '.value.pos'
  {
    "line": 1,
    "col": 18
  }
