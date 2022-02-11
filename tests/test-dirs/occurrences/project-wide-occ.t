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

  $ $MERLIN single occurrences -identifier-at 1:16 \
  > -filename main.ml <main.ml
  {
    "class": "return",
    "value": [
      {
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
