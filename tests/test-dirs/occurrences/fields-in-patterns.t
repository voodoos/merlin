  $ cat >main.ml <<EOF
  > type t = { lbl_a : int }
  > let f (x : t) = match x with
  >   | { lbl_a } -> ignore lbl_a
  > EOF
 

  $ $MERLIN single occurrences -identifier-at 3:8 -scope project \
  > -filename main.ml <main.ml 
  {
    "class": "return",
    "value": [
      {
        "file": "$TESTCASE_ROOT/main.ml",
        "start": {
          "line": 3,
          "col": 6
        },
        "end": {
          "line": 3,
          "col": 11
        }
      },
      {
        "file": "$TESTCASE_ROOT/main.ml",
        "start": {
          "line": 3,
          "col": 24
        },
        "end": {
          "line": 3,
          "col": 29
        }
      }
    ],
    "notifications": []
  }
