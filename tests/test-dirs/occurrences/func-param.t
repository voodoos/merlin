
  $ cat >main.ml <<'EOF'
  > module Client (P : sig
  >     val url : string
  >   end) =
  >   struct
  >     let url = P.url
  >     let url2 = P.url
  >   end
  > EOF

FIXME: there are two occurrences of P.url
  $ $MERLIN single occurrences -identifier-at 6:17 \
  > -filename main.ml <main.ml | jq '.value'
  [
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
