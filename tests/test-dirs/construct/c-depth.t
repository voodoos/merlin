  $ cat >d1.ml <<EOF
  > let x : int option option = _
  > EOF

  $ $MERLIN single construct -max-depth 1 -position 1:28 -filename d1.ml <d1.ml |
  >  jq ".value[1]"
  [
    "Some _",
    "None"
  ]

  $ $MERLIN single construct -max-depth 2 -position 1:28 -filename d1.ml <d1.ml |
  >  jq ".value[1]"
  [
    "Some _",
    "None",
    "Some (Some _)",
    "Some None"
  ]

  $ $MERLIN single construct -max-depth 3 -position 1:28 -filename d1.ml <d1.ml |
  >  jq ".value[1]"
  [
    "Some _",
    "None",
    "Some (Some _)",
    "Some None",
    "Some (Some 0)"
  ]

  $ $MERLIN single construct -max-depth 4 -position 1:28 -filename d1.ml <d1.ml |
  >  jq ".value[1]"
  [
    "Some _",
    "None",
    "Some (Some _)",
    "Some None",
    "Some (Some 0)"
  ]

  $ cat >d2.ml <<EOF
  > type t = { a : int option option }
  > let x : t = _
  > EOF

FIXME
  $ $MERLIN single construct -max-depth 2 -position 2:12 -filename d2.ml <d2.ml |
  >  jq ".value[1]"
  [
    "{ a = _ }"
  ]
