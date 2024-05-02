  $ cat >prefix.ml <<EOF
  > open List;;
  > print_int 0
  > EOF

  $ $MERLIN server stop-server

Unused open warning shows:
  $ $MERLIN server errors -w +33 \
  >  -filename prefix.ml <prefix.ml |
  > jq '.value'
  [
    {
      "start": {
        "line": 1,
        "col": 0
      },
      "end": {
        "line": 1,
        "col": 9
      },
      "type": "warning",
      "sub": [],
      "valid": true,
      "message": "Warning 33: unused open Stdlib.List."
    }
  ]

  $ cat >prefix.ml <<EOF
  > open List;;
  > print_int (length [])
  > EOF

Unused open warning disappears:
  $ $MERLIN server errors -w +33 \
  >  -filename prefix.ml <prefix.ml |
  > jq '.value'
  []

  $ cat >prefix.ml <<EOF
  > open List;;
  > print_int 0
  > EOF

FIXME: Unused open warning does not show again:
  $ $MERLIN server errors -w +33 \
  >  -filename prefix.ml <prefix.ml |
  > jq '.value'
  []

  $ $MERLIN server stop-server
