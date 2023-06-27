  $ cat >main.ml <<EOF
  > module type S = sig val x : int val y : int end
  > module A : S = struct let x = 42 let y = 43 end
  > 
  > module A = (val (module A : S))
  > 
  > let () = Format.printf "%i:%i\n" A.x A.y
  > EOF

FIXME: locate fails due to the presence of a first-class module and fallsback tot he uid of the module which 
  $ $MERLIN single occurrences -scope buffer -identifier-at 6:35 \
  > - filename main.ml <main.ml | jq '.value'
  [
    {
      "start": {
        "line": 6,
        "col": 35
      },
      "end": {
        "line": 6,
        "col": 36
      }
    },
    {
      "start": {
        "line": 6,
        "col": 39
      },
      "end": {
        "line": 6,
        "col": 40
      }
    }
  ]

  $ cat >main.ml <<EOF
  > module A = struct let x = 42 end
  > module B = A
  > module C = B
  > EOF

Aliases are not traversed when looking for occurrences
  $ $MERLIN single occurrences -scope buffer -identifier-at 3:11 \
  > - filename main.ml <main.ml | jq '.value'
  [
    {
      "start": {
        "line": 3,
        "col": 11
      },
      "end": {
        "line": 3,
        "col": 12
      }
    }
  ]
