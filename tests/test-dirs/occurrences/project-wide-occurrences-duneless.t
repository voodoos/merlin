  $ cat >main.ml <<EOF
  > let x = 3 + Foo.f 3
  > let _y = x
  > let r = { Foo.label_rouge = 4 }
  > let () = print_int r.label_rouge
  > module M = Map.Make(Foo.Bar)
  > type _r2 = Foo.r
  > EOF

  $ mkdir lib

  $ cat >lib/foo.ml <<EOF
  > let f x = x
  > let _y = f 3
  > type r = { label_rouge : int }
  > module Bar = String
  > module Bartender = Bar
  > EOF

  $ cat >.merlin <<EOF
  > S .
  > S lib
  > B .
  > B lib
  > EOF

  $ ocamlc -c -bin-annot lib/foo.ml
  $ ocamlc -c -bin-annot -I lib main.ml

  $ ocaml-uideps process-cmt lib/foo.cmt -o lib/foo.index
  $ ocaml-uideps process-cmt main.cmt -o main.index

  $ ocaml-uideps aggregate main.index lib/foo.index -o project.index

  $ ls 
  lib
  main.cmi
  main.cmo
  main.cmt
  main.index
  main.ml
  project.index

  $ ls lib
  foo.cmi
  foo.cmo
  foo.cmt
  foo.index
  foo.ml

  $ ocaml-uideps dump project.index 
  16 uids:
  {uid: Foo.4; locs:
     "Foo.label_rouge": File "main.ml", line 3, characters 10-25;
     "label_rouge": File "main.ml", line 4, characters 21-32
   uid: Stdlib__String; locs:
     "String": File "lib/foo.ml", line 4, characters 13-19;
     "Bar": File "lib/foo.ml", line 5, characters 19-22;
     "Foo.Bar": File "main.ml", line 5, characters 20-27
   uid: Foo.2; locs: "_y": File "lib/foo.ml", line 2, characters 4-6
   uid: Main.3; locs: "M": File "main.ml", line 5, characters 7-8
   uid: Main.4; locs: "_r2": File "main.ml", line 6, characters 5-8
   uid: Foo.3; locs:
     "r": File "lib/foo.ml", line 3, characters 5-6;
     "Foo.r": File "main.ml", line 6, characters 11-16
   uid: <predef:int>; locs: "int": File "lib/foo.ml", line 3, characters 25-28
   uid: Foo.6; locs: "Bartender": File "lib/foo.ml", line 5, characters 7-16
   uid: Main.0; locs:
     "x": File "main.ml", line 1, characters 4-5;
     "x": File "main.ml", line 2, characters 9-10
   uid: Stdlib.53; locs: "+": File "main.ml", line 1, characters 10-11
   uid: Foo.0; locs:
     "f": File "lib/foo.ml", line 1, characters 4-5;
     "f": File "lib/foo.ml", line 2, characters 9-10;
     "Foo.f": File "main.ml", line 1, characters 12-17
   uid: Foo.5; locs: "Bar": File "lib/foo.ml", line 4, characters 7-10
   uid: Main.1; locs: "_y": File "main.ml", line 2, characters 4-6
   uid: Foo.1; locs: "x": File "lib/foo.ml", line 1, characters 10-11
   uid: Main.2; locs:
     "r": File "main.ml", line 3, characters 4-5;
     "r": File "main.ml", line 4, characters 19-20
   uid: Stdlib.316; locs: "print_int": File "main.ml", line 4, characters 9-18 },
  1 partial shapes:
  {shape: CU Stdlib . "Map"[module] . "Make"[module] ; locs:
     "Map.Make": File "main.ml", line 5, characters 11-19
   }, 0 unreduced shapes: {} and shapes for CUS .

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
      "file": "$TESTCASE_ROOT/lib/foo.ml",
      "start": {
        "line": 2,
        "col": 9
      },
      "end": {
        "line": 2,
        "col": 10
      }
    },
    {
      "file": "$TESTCASE_ROOT/main.ml",
      "start": {
        "line": 1,
        "col": 16
      },
      "end": {
        "line": 1,
        "col": 17
      }
    }
  ]

> let |f x = x
  $ $MERLIN single occurrences -scope project -identifier-at 1:4 \
  > -filename lib/foo.ml <lib/foo.ml  | jq '.value'
  [
    {
      "file": "$TESTCASE_ROOT/lib/foo.ml",
      "start": {
        "line": 2,
        "col": 9
      },
      "end": {
        "line": 2,
        "col": 10
      }
    },
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
        "col": 9
      },
      "end": {
        "line": 2,
        "col": 10
      }
    },
    {
      "file": "$TESTCASE_ROOT/main.ml",
      "start": {
        "line": 1,
        "col": 16
      },
      "end": {
        "line": 1,
        "col": 17
      }
    }
  ]
 

> let _y = |f 3
  $ $MERLIN single occurrences -scope project -identifier-at 2:9 \
  > -filename lib/foo.ml <lib/foo.ml  | jq '.value'
  [
    {
      "file": "$TESTCASE_ROOT/lib/foo.ml",
      "start": {
        "line": 2,
        "col": 9
      },
      "end": {
        "line": 2,
        "col": 10
      }
    },
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
        "col": 9
      },
      "end": {
        "line": 2,
        "col": 10
      }
    },
    {
      "file": "$TESTCASE_ROOT/main.ml",
      "start": {
        "line": 1,
        "col": 16
      },
      "end": {
        "line": 1,
        "col": 17
      }
    }
  ]