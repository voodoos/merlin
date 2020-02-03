Various parts of the cons.ml:

- The expression:
  $ $MERLIN single type-enclosing -position 4:14 -verbosity 0 \
  > -filename ./cons.ml < ./cons.ml | jq ".value[0:2]"
  [
    {
      "start": {
        "line": 4,
        "col": 13
      },
      "end": {
        "line": 4,
        "col": 14
      },
      "type": "t",
      "tail": "no"
    },
    {
      "start": {
        "line": 4,
        "col": 13
      },
      "end": {
        "line": 4,
        "col": 14
      },
      "type": "t",
      "tail": "no"
    }
  ]

- The pattern:

  $ $MERLIN single type-enclosing -position 8:6 -verbosity 0 \
  > -filename ./cons.ml < ./cons.ml | jq ".value[0:2]"
  [
    {
      "start": {
        "line": 8,
        "col": 4
      },
      "end": {
        "line": 8,
        "col": 5
      },
      "type": "t",
      "tail": "no"
    },
    {
      "start": {
        "line": 7,
        "col": 2
      },
      "end": {
        "line": 8,
        "col": 11
      },
      "type": "unit",
      "tail": "no"
    }
  ]
