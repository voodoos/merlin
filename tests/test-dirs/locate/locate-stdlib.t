  $ cat >dune-project <<EOF
  > (lang dune 2.0)
  > EOF

  $ cat >s.ml <<EOF
  > module Foo = Set.Make(struct
  >   type t
  >   let compare _ _ = 0
  > end)
  > type t = Foo.t
  > EOF

  $ cat >dune <<EOF
  > (executable (name s))

  $ dune build ./s.exe

Should jump to set.ml:
  $ $MERLIN single locate -look-for ml -position 5:13 -filename ./s.ml < ./s.ml
  {
    "class": "return",
    "value": {
      "file": "lib/ocaml/set.ml",
      "pos": {
        "line": 75,
        "col": 4
      }
    },
    "notifications": []
  }

Should jump to set.mli:
  $ $MERLIN single locate -look-for mli -position 5:13 -filename ./s.ml < ./s.ml
  {
    "class": "return",
    "value": {
      "file": "lib/ocaml/set.mli",
      "pos": {
        "line": 71,
        "col": 4
      }
    },
    "notifications": []
  }
