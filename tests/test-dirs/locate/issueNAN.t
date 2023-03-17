  $ cat >dune-project <<EOF
  > (lang dune 2.0)
  > EOF

  $ cat >dune <<EOF
  > (library 
  >  (name my_lib))
  > EOF

  $ cat >import.ml <<EOF
  > let x = 42
  > EOF

  $ cat >foo.ml <<EOF
  > open Import
  > let y = x
  > EOF

  $ dune build

  $ $MERLIN single errors \
  > -filename foo.ml <foo.ml |
  > jq '.value'
  []

  $ echo "let" >> import.ml
  $ dune build
  File "import.ml", line 3, characters 0-0:
  Error: Syntax error
  [1]

  $ $MERLIN single errors \
  > -filename foo.ml <foo.ml |
  > jq '.value'
  []
