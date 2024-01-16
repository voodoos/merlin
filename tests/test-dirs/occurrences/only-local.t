Some occurrences are only available locally an dnot part of the global index

  $ cat >local.ml <<'EOF'
  > type t = int
  > let x : int = 42
  > EOF

Predef:
  $ $MERLIN single occurrences -identifier-at 2:9 \
  > -filename local.ml <local.ml | jq '.value'
  [
    {
      "start": {
        "line": 1,
        "col": 9
      },
      "end": {
        "line": 1,
        "col": 12
      }
    },
    {
      "start": {
        "line": 2,
        "col": 8
      },
      "end": {
        "line": 2,
        "col": 11
      }
    }
  ]


Predef constructors:
  $ cat >local.ml <<'EOF'
  > let _ = None
  > let None = None
  > EOF

  $ $MERLIN single occurrences -identifier-at 1:10 \
  > -filename local.ml <local.ml | jq '.value'
  [
    {
      "start": {
        "line": 1,
        "col": 8
      },
      "end": {
        "line": 1,
        "col": 12
      }
    },
    {
      "start": {
        "line": 2,
        "col": 4
      },
      "end": {
        "line": 2,
        "col": 8
      }
    },
    {
      "start": {
        "line": 2,
        "col": 11
      },
      "end": {
        "line": 2,
        "col": 15
      }
    }
  ]

true / false
  $ cat >local.ml <<'EOF'
  > let _ = true
  > let _ = true
  > EOF

  $ $MERLIN single occurrences -identifier-at 1:10 \
  > -filename local.ml <local.ml | jq '.value'
  [
    {
      "start": {
        "line": 1,
        "col": 8
      },
      "end": {
        "line": 1,
        "col": 12
      }
    },
    {
      "start": {
        "line": 2,
        "col": 8
      },
      "end": {
        "line": 2,
        "col": 12
      }
    }
  ]

unit
  $ cat >local.ml <<'EOF'
  > let _ = ()
  > let f () = ()
  > EOF

  $ $MERLIN single occurrences -identifier-at 1:9 \
  > -filename local.ml <local.ml | jq '.value'
  [
    {
      "start": {
        "line": 1,
        "col": 8
      },
      "end": {
        "line": 1,
        "col": 10
      }
    },
    {
      "start": {
        "line": 2,
        "col": 6
      },
      "end": {
        "line": 2,
        "col": 8
      }
    },
    {
      "start": {
        "line": 2,
        "col": 11
      },
      "end": {
        "line": 2,
        "col": 13
      }
    }
  ]
