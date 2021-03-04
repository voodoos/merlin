###############
## PREFIXING ##
###############

Test 1.1 :

  $ cat >c1.ml <<EOF
  > module Prefix = struct
  >   type t = A of int | B
  > end
  > let x : Prefix.t = _
  > EOF

  $ $MERLIN single construct -position 4:20 -filename c1.ml <c1.ml |
  >  jq ".value"
  [
    {
      "start": {
        "line": 4,
        "col": 19
      },
      "end": {
        "line": 4,
        "col": 20
      }
    },
    [
      "Prefix.B",
      "Prefix.A _"
    ]
  ]

FIXME We should not print complete prefix of opened modules
Test 1.2 :

  $ cat >c12.ml <<EOF
  > module Prefix = struct
  >   type t = A of int | B
  > end
  > open Prefix
  > let x : t = _
  > EOF

  $ $MERLIN single construct -position 5:13 -filename c12.ml <c12.ml |
  >  jq ".value"
  [
    {
      "start": {
        "line": 5,
        "col": 12
      },
      "end": {
        "line": 5,
        "col": 13
      }
    },
    [
      "B",
      "A _"
    ]
  ]
