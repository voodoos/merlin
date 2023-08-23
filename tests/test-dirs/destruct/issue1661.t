  $ cat >main.ml <<EOF
  > type t =
  >   { a : int * int
  >   ; b : string
  >   }
  > 
  > let f ({ a; b } : t) = assert false
  > EOF

FIXME: the correct answer is `a = (_, _)` not just `(_, _)`
  $ $MERLIN single case-analysis -start 6:9 -end 6:10 \
  > -filename main.ml <main.ml 
  {
    "class": "return",
    "value": [
      {
        "start": {
          "line": 6,
          "col": 9
        },
        "end": {
          "line": 6,
          "col": 10
        }
      },
      "(_, _)"
    ],
    "notifications": []
  }
