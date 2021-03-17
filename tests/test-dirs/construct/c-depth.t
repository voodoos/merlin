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
  > type t = { a : int option option; b : float option }
  > let x : t = _
  > EOF

  $ $MERLIN single construct -max-depth 1 -position 2:12 -filename d2.ml <d2.ml |
  >  jq ".value[1]"
  [
    "{ a = _; b = _ }"
  ]

  $ $MERLIN single construct -max-depth 2 -position 2:12 -filename d2.ml <d2.ml |
  >  jq ".value[1]"
  [
    "{ a = _; b = _ }",
    "{ a = (Some _); b = _ }",
    "{ a = None; b = _ }",
    "{ a = _; b = (Some _) }",
    "{ a = (Some _); b = (Some _) }",
    "{ a = None; b = (Some _) }",
    "{ a = _; b = None }",
    "{ a = (Some _); b = None }",
    "{ a = None; b = None }"
  ]

  $ $MERLIN single construct -max-depth 3 -position 2:12 -filename d2.ml <d2.ml |
  >  jq ".value[1]"
  [
    "{ a = _; b = _ }",
    "{ a = (Some _); b = _ }",
    "{ a = None; b = _ }",
    "{ a = (Some (Some _)); b = _ }",
    "{ a = (Some None); b = _ }",
    "{ a = _; b = (Some _) }",
    "{ a = (Some _); b = (Some _) }",
    "{ a = None; b = (Some _) }",
    "{ a = (Some (Some _)); b = (Some _) }",
    "{ a = (Some None); b = (Some _) }",
    "{ a = _; b = None }",
    "{ a = (Some _); b = None }",
    "{ a = None; b = None }",
    "{ a = (Some (Some _)); b = None }",
    "{ a = (Some None); b = None }",
    "{ a = _; b = (Some 0.0) }",
    "{ a = (Some _); b = (Some 0.0) }",
    "{ a = None; b = (Some 0.0) }",
    "{ a = (Some (Some _)); b = (Some 0.0) }",
    "{ a = (Some None); b = (Some 0.0) }"
  ]

  $ $MERLIN single construct -max-depth 4 -position 2:12 -filename d2.ml <d2.ml |
  >  jq ".value[1]"
  [
    "{ a = _; b = _ }",
    "{ a = (Some _); b = _ }",
    "{ a = None; b = _ }",
    "{ a = (Some (Some _)); b = _ }",
    "{ a = (Some None); b = _ }",
    "{ a = (Some (Some 0)); b = _ }",
    "{ a = _; b = (Some _) }",
    "{ a = (Some _); b = (Some _) }",
    "{ a = None; b = (Some _) }",
    "{ a = (Some (Some _)); b = (Some _) }",
    "{ a = (Some None); b = (Some _) }",
    "{ a = (Some (Some 0)); b = (Some _) }",
    "{ a = _; b = None }",
    "{ a = (Some _); b = None }",
    "{ a = None; b = None }",
    "{ a = (Some (Some _)); b = None }",
    "{ a = (Some None); b = None }",
    "{ a = (Some (Some 0)); b = None }",
    "{ a = _; b = (Some 0.0) }",
    "{ a = (Some _); b = (Some 0.0) }",
    "{ a = None; b = (Some 0.0) }",
    "{ a = (Some (Some _)); b = (Some 0.0) }",
    "{ a = (Some None); b = (Some 0.0) }",
    "{ a = (Some (Some 0)); b = (Some 0.0) }"
  ]
