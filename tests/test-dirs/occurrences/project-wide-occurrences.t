  $ cat >dune-project <<EOF
  > (lang dune 3.5)
  > (enable_project_indexation)
  > EOF

  $ cat >main.ml <<EOF
  > let x = 3 + Foo.f 3
  > let _y = x
  > let r = { Foo.label_rouge = 4 }
  > let () = print_int r.label_rouge
  > module M = Map.Make(Foo.Bar)
  > type _r2 = Foo.r
  > EOF

  $ cat>dune <<EOF
  > (executable (name main) (libraries foo))
  > EOF

  $ mkdir lib

  $ cat >lib/foo.ml <<EOF
  > let f x = x
  > let _y = f 3
  > type r = { label_rouge : int }
  > module Bar = String
  > module Bartender = Bar
  > EOF

  $ cat>lib/dune <<EOF
  > (library (name foo))
  > EOF

  $ dune build @uideps 
$ ocamlc -c -bin-annot foo.mli foo.ml main.ml
$ ocaml-uideps process-cmt main.cmt foo.cmt foo.cmti -o project.uideps
  $ ocaml-uideps dump _build/default/project.uideps 

> main.ml
> let x = 3 + Foo.|f 3
  $ $MERLIN single occurrences -scope project -identifier-at 1:16 \
  > -filename main.ml <main.ml | jq '.value'
  [
    {
      "file": "$TESTCASE_ROOT/lib/foo.ml",
      "start": {
        "line": 1,
        "col": 4
      },
      "end": {
        "line": 1,
        "col": 5
      }
    },
    {
      "file": "$TESTCASE_ROOT/main.ml",
      "start": {
        "line": 1,
        "col": 12
      },
      "end": {
        "line": 1,
        "col": 17
      }
    },
    {
      "file": "$TESTCASE_ROOT/lib/foo.ml",
      "start": {
        "line": 2,
        "col": 8
      },
      "end": {
        "line": 2,
        "col": 9
      }
    },
    {
      "file": "$TESTCASE_ROOT/main.ml",
      "start": {
        "line": 1,
        "col": 12
      },
      "end": {
        "line": 1,
        "col": 17
      }
    }
  ]

> let |f x = x
  $ $MERLIN single occurrences -scope project -identifier-at 1:4 \
  > -log-file - -log-section locate \
  > -filename lib/foo.ml <lib/foo.ml  | jq '.value'
  [
    {
      "file": "$TESTCASE_ROOT/lib/foo.ml",
      "start": {
        "line": 1,
        "col": 4
      },
      "end": {
        "line": 1,
        "col": 5
      }
    },
    {
      "file": "$TESTCASE_ROOT/lib/foo.ml",
      "start": {
        "line": 2,
        "col": 8
      },
      "end": {
        "line": 2,
        "col": 9
      }
    },
    {
      "file": "$TESTCASE_ROOT/main.ml",
      "start": {
        "line": 1,
        "col": 12
      },
      "end": {
        "line": 1,
        "col": 17
      }
    }
  ]

$ ocaml-uideps dump _build/default/project.uideps
$ ocamlmerlin single dump-configuration  -filename lib/foo.ml <lib/foo.ml | jq
