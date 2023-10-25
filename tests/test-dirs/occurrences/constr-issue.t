  $ cat >main.ml <main.ml <<'EOF'
  > let f = function
  >   | Unix.WEXITED n -> n
  >   | _ -> 0
  > EOF

  $ $MERLIN single occurrences -identifier-at 2:17 -filename main.ml <main.ml | jq '.value'
  [
    {
      "start": {
        "line": 2,
        "col": 17
      },
      "end": {
        "line": 2,
        "col": 18
      }
    },
    {
      "start": {
        "line": 2,
        "col": 22
      },
      "end": {
        "line": 2,
        "col": 23
      }
    }
  ]

  $ cat >main.ml <main.ml <<'EOF'
  > let f = function
  >   | { Unix.st_ino = n; _ } when true -> n
  >   | { Unix.st_ino = n; _ } -> n
  >   | _ -> 0
  > EOF

  $ $MERLIN single occurrences -identifier-at 2:14 -filename main.ml <main.ml | jq '.value'
  [
    {
      "start": {
        "line": 2,
        "col": 11
      },
      "end": {
        "line": 2,
        "col": 17
      }
    },
    {
      "start": {
        "line": 3,
        "col": 11
      },
      "end": {
        "line": 3,
        "col": 17
      }
    }
  ]
