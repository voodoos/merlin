  $ cat >main.ml <<EOF
  > module Bar = struct type t end
  > module Bartender = Bar
  > EOF

  $ $MERLIN single occurrences -identifier-at 2:20 \
  > -filename main.ml <main.ml 
  {
    "class": "return",
    "value": [
      {
        "start": {
          "line": 1,
          "col": 7
        },
        "end": {
          "line": 1,
          "col": 10
        }
      },
      {
        "start": {
          "line": 2,
          "col": 19
        },
        "end": {
          "line": 2,
          "col": 22
        }
      }
    ],
    "notifications": []
  }

  $ cat >main.ml <<EOF
  > module A = struct type t end
  > module F (X : sig type t end) = X
  > module C = F(A)
  > module D = C
  > EOF

  $ $MERLIN single occurrences -identifier-at 4:11 \
  > -filename main.ml <main.ml 
  {
    "class": "return",
    "value": [
      {
        "start": {
          "line": 3,
          "col": 7
        },
        "end": {
          "line": 3,
          "col": 8
        }
      },
      {
        "start": {
          "line": 4,
          "col": 11
        },
        "end": {
          "line": 4,
          "col": 12
        }
      }
    ],
    "notifications": []
  }
