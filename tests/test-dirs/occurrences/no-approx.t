  $ cat >main.ml <<'EOF'
  > module type S = sig type t type u end
  > module A = struct type t type u end
  > module B = struct type t type u end
  > module M = (val (
  >   if Random.bool () 
  >   then (module A)
  >   else (module B)) : S) 
  > type v = M.t
  > type w = A.u
  > EOF

Shape reduction might return approximate results:
For locate it is okay to stop at the first class module definition:
  $ $MERLIN single locate -look-for ml -position 8:11 \
  > -filename main.ml <main.ml | jq '.value.pos'
  {
    "line": 4,
    "col": 7
  }

FIXME: but occurrences should not rely on that information:
  $ OCAMLRUNPARAM=b $MERLIN single occurrences -identifier-at 8:11 \
  > -filename main.ml <main.ml
  {
    "class": "return",
    "value": [
      {
        "start": {
          "line": 8,
          "col": 9
        },
        "end": {
          "line": 8,
          "col": 12
        }
      }
    ],
    "notifications": []
  }

  $ cat >main.ml <<'EOF'
  > let _ = Filename.current_dir_name;;
  > let _ = Filename.dir_sep
  > EOF

FIXME: these are not occurrences of the same value
This is due to a first-class module and shape fallbacking
  $ $MERLIN single occurrences -identifier-at 2:20 \
  > -filename main.ml <main.ml
  {
    "class": "return",
    "value": [
      {
        "start": {
          "line": 2,
          "col": 8
        },
        "end": {
          "line": 2,
          "col": 24
        }
      }
    ],
    "notifications": []
  }
