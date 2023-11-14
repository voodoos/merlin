  $ cat >main.ml <<'EOF'
  > module M : sig
  >   type t = A of { label_a : int }
  > end = struct
  >   type t = A of { label_a : int }
  >   let _ = A { label_a = 1 }
  > end
  > 
  > let _ = M.A { label_a = 1 }
  > 
  > open M
  > 
  > let _ = A { label_a = 1 }
  > EOF

Constructor declaration:
  $ $MERLIN single locate -look-for mli -position 12:8 \
  > -filename main.ml <main.ml | jq '.value.pos'
  {
    "line": 2,
    "col": 11
  }

Constructor definition:
  $ $MERLIN single locate -look-for ml -position 12:8 \
  > -filename main.ml <main.ml | jq '.value.pos'
  {
    "line": 4,
    "col": 11
  }

Label declaration:
  $ $MERLIN single locate -look-for mli -position 12:13 \
  > -filename main.ml <main.ml | jq '.value.pos'
  {
    "line": 2,
    "col": 18
  }

Label definition:
  $ $MERLIN single locate -look-for ml -position 12:13 \
  > -filename main.ml <main.ml | jq '.value.pos'
  {
    "line": 4,
    "col": 18
  }

Constructor occurrences:
  $ $MERLIN single occurrences -identifier-at 12:8 \
  > -filename main.ml <main.ml | grep line | uniq
          "line": 4,
          "line": 5,
          "line": 8,
          "line": 12,

Label occurrences:
  $ $MERLIN single occurrences -identifier-at 12:13 \
  > -filename main.ml <main.ml | jq '.value'
  [
    {
      "start": {
        "line": 4,
        "col": 18
      },
      "end": {
        "line": 4,
        "col": 25
      }
    },
    {
      "start": {
        "line": 5,
        "col": 14
      },
      "end": {
        "line": 5,
        "col": 21
      }
    },
    {
      "start": {
        "line": 8,
        "col": 14
      },
      "end": {
        "line": 8,
        "col": 21
      }
    },
    {
      "start": {
        "line": 12,
        "col": 12
      },
      "end": {
        "line": 12,
        "col": 19
      }
    }
  ]

  $ cat >main.ml <<'EOF'
  > type t = { a : int; b : float }
  > let _ = { a = 4; b = 2.0 }
  > let a = 4
  > let r = { a; b = 2.0 }
  > let _ = { r with b = 2.0 }
  > let { a; b } = r
  > EOF

  $ $MERLIN single occurrences -identifier-at 6:15 \
  > -filename main.ml <main.ml | jq '.value'
  [
    {
      "start": {
        "line": 4,
        "col": 4
      },
      "end": {
        "line": 4,
        "col": 5
      }
    },
    {
      "start": {
        "line": 5,
        "col": 10
      },
      "end": {
        "line": 5,
        "col": 11
      }
    },
    {
      "start": {
        "line": 6,
        "col": 15
      },
      "end": {
        "line": 6,
        "col": 16
      }
    }
  ]

  $ $MERLIN single occurrences -identifier-at 2:10 \
  > -filename main.ml <main.ml | jq '.value'
  [
    {
      "start": {
        "line": 1,
        "col": 11
      },
      "end": {
        "line": 1,
        "col": 12
      }
    },
    {
      "start": {
        "line": 2,
        "col": 10
      },
      "end": {
        "line": 2,
        "col": 11
      }
    },
    {
      "start": {
        "line": 4,
        "col": 10
      },
      "end": {
        "line": 4,
        "col": 11
      }
    },
    {
      "start": {
        "line": 6,
        "col": 6
      },
      "end": {
        "line": 6,
        "col": 7
      }
    }
  ]
