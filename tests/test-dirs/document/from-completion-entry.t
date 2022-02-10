  $ cat >test.ml <<EOF
  > let _ = Test2.
  > EOF

  $ cat >test2.ml <<EOF
  > let foo = 42
  > EOF

  $ cat >test2.mli <<EOF
  > (** doc of Test2.foo *)
  > val foo : int
  > EOF

  $ ocamlc -bin-annot -c test2.mli test2.ml
  $ cat >.merlin <<EOF
  > S .
  > B.
  > EOF

FIXME: this should return the doc in the info field
> "info": " doc of Test2.foo ",
  $ $MERLIN single complete-prefix -position 1:14 -prefix Test2. -doc y \
  > -filename test.ml < test.ml
  {
    "class": "return",
    "value": {
      "entries": [
        {
          "name": "foo",
          "kind": "Value",
          "desc": "int",
          "info": "",
          "deprecated": false
        }
      ],
      "context": null
    },
    "notifications": []
  }
