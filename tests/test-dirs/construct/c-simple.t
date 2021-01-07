###############
## SUM TYPES ##
###############

Test 1.1 :

  $ cat >c1.ml <<EOF
  > let nice_candidate = Some 3
  > let nice_candidate_with_arg x = Some x
  > let y = 4
  > let x : int option = _
  > EOF

  $ $MERLIN single construct -position 4:22 -filename c1.ml <c1.ml
  {
    "class": "return",
    "value": [
      {
        "start": {
          "line": 4,
          "col": 21
        },
        "end": {
          "line": 4,
          "col": 22
        }
      },
      [
        "nice_candidate_with_arg _",
        "Some _",
        "nice_candidate ",
        "None",
        "Some (y )"
      ]
    ],
    "notifications": []
  }

Test 1.2

$ cat >c2.ml <<EOF
> let x : int option =
> EOF

$ $MERLIN single construct -position 1:22 -filename c2.ml <c2.ml

#############
## RECORDS ##
#############

  $ cat >c2.ml <<EOF
  > type r = { a : string; b : int option }
  > let nice_candidate = Some 3
  > let x : r = _
  > EOF

  $ $MERLIN single construct -position 3:13 -filename c2.ml <c2.ml
  {
    "class": "return",
    "value": [
      {
        "start": {
          "line": 3,
          "col": 12
        },
        "end": {
          "line": 3,
          "col": 13
        }
      },
      [
        "{ a = _; b = _ }"
      ]
    ],
    "notifications": []
  }
