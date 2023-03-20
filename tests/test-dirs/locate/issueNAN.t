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
  > module I = Import
  > let y = I.x
  > EOF

  $ dune build

  $ $MERLIN single errors \
  > -filename foo.ml <foo.ml |
  > jq '.value'
  []

  $ $MERLIN single locate -look-for ml -position 1:13 \
  > -filename ./foo.ml < ./foo.ml | jq '.value'
  {
    "file": "$TESTCASE_ROOT/import.ml",
    "pos": {
      "line": 1,
      "col": 0
    }
  }

  $ $MERLIN single locate -look-for mli -position 1:13 \
  > -filename ./foo.ml < ./foo.ml | jq '.value'
  {
    "file": "$TESTCASE_ROOT/import.ml",
    "pos": {
      "line": 1,
      "col": 0
    }
  }

Now we break the build, this means that there is no cmi anymore for Import
  $ echo "let () = 5" >> import.ml
  $ dune build
  File "import.ml", line 2, characters 9-10:
  2 | let () = 5
               ^
  Error: This expression has type int but an expression was expected of type
           unit
  [1]

FIXME: it would be better to show the real module name, not the wrapped one
  $ $MERLIN single errors \
  > -filename foo.ml <foo.ml |
  > jq '.value'
  [
    {
      "start": {
        "line": 2,
        "col": 8
      },
      "end": {
        "line": 2,
        "col": 11
      },
      "type": "typer",
      "sub": [],
      "valid": true,
      "message": "The module I is an alias for module My_lib__Import, which is missing"
    }
  ]

FIXME: we could improve the error messages here:
  $ $MERLIN single locate -look-for ml -position 1:13 \
  > -filename ./foo.ml < ./foo.ml | jq '.value'
  "didn't manage to find My_lib.Import"

  $ $MERLIN single locate -look-for mli -position 1:13 \
  > -filename ./foo.ml < ./foo.ml | jq '.value'
  "'Import' seems to originate from 'My_lib' whose ML file could not be found"
