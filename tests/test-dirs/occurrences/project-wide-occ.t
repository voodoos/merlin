  $ cat >main.ml <<EOF
  > let x = 3 + Foo.x
  > let y = x
  > EOF

  $ cat >foo.mli <<EOF
  > val x : int
  > EOF

  $ cat >foo.ml <<EOF
  > let x = 3
  > let y = x
  > EOF

  $ ocamlc -c -bin-annot foo.mli foo.ml main.ml
  $ ocaml-uideps process-cmt main.cmt foo.cmt
  $ ocaml-uideps aggregate main.uideps foo.uideps
  $ ocaml-uideps dump workspace.uideps
  {uid: Main.0; locs: File "main.ml", line 1, characters 4-5;
                      File "main.ml", line 2, characters 8-9
   uid: Foo.0; locs: File "foo.ml", line 1, characters 4-5;
                     File "foo.ml", line 2, characters 8-9;
                     File "main.ml", line 1, characters 12-17
   uid: Main.1; locs: File "main.ml", line 2, characters 4-5
   uid: Foo.1; locs: File "foo.ml", line 2, characters 4-5
   uid: Stdlib.55; locs: File "main.ml", line 1, characters 10-11}

  $ $MERLIN single occurrences -identifier-at 1:16 \
  > -filename main.ml <main.ml
  Found uid: Foo.0 (Foo!.x)
  Found locs:
  File "foo.ml", line 1, characters 4-5
  File "foo.ml", line 2, characters 8-9
  File "main.ml", line 1, characters 12-17
  {
    "class": "return",
    "value": [
      {
        "file": "foo.ml",
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
        "file": "foo.ml",
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
        "file": "main.ml",
        "start": {
          "line": 1,
          "col": 12
        },
        "end": {
          "line": 1,
          "col": 17
        }
      }
    ],
    "notifications": []
  }

  $ $MERLIN single occurrences -identifier-at 2:8 \
  > -filename foo.ml <foo.ml
  Found uid: Foo.0 (x/273)
  Found locs:
  File "foo.ml", line 1, characters 4-5
  File "foo.ml", line 2, characters 8-9
  File "main.ml", line 1, characters 12-17
  {
    "class": "return",
    "value": [
      {
        "file": "foo.ml",
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
        "file": "foo.ml",
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
        "file": "main.ml",
        "start": {
          "line": 1,
          "col": 12
        },
        "end": {
          "line": 1,
          "col": 17
        }
      }
    ],
    "notifications": []
  }
