  $ cat >dune-project <<EOF
  > (lang dune 2.0)
  > EOF

  $ cat >main.ml <<EOF
  > print_endline 
  >   (Yojson.Basic.to_string @@ \`Assoc [])
  > EOF

  $ cat >dune <<EOF
  > (executable 
  >  (name main)
  >  (libraries yojson))
  > EOF

  $ dune build @check

  $ $MERLIN single type-enclosing -position 2:19 -filename main.ml <main.ml |
  > jq '.value[0].type'

  $ dune clean
  
  $ mkdir "test@at"
  $ mv dune-project dune main.ml "test@at"
  $ cd "test@at"

  $ dune build @check --root=.

  $ $MERLIN single type-enclosing -position 2:19 -filename main.ml <main.ml |
  > jq '.value[0].type'
  
  $ cd ..
  $ mv "test@at" "test at"
  $ cd "test at"

  $ dune build @check --root=.

  $ $MERLIN single type-enclosing -position 2:19 -filename main.ml <main.ml |
  > jq '.value[0].type'
