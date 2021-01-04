###############
## SUM TYPES ##
###############

Test 1.1 :

  $ cat >c1.ml <<EOF
  > let nice_candidate = Some 3
  > let nice_candidate_with_arg x = Some x
  > let x : int option = _
  > EOF

  $ $MERLIN single construct -position 3:22 -filename c1.ml <c1.ml
  {
    "class": "return",
    "value": [
      {
        "start": {
          "line": 3,
          "col": 21
        },
        "end": {
          "line": 3,
          "col": 22
        }
      },
      [
        "Some _",
        "None",
        "nice_candidate ",
        "nice_candidate_with_arg _",
        "!_",
        "_ @@ _",
        "exit _",
        "failwith _",
        "fst _",
        "input_value _",
        "int_of_string_opt _",
        "invalid_arg _",
        "max _ _",
        "min _ _",
        "raise _",
        "raise_notrace _",
        "read_int_opt _",
        "snd _",
        "_ |> _"
      ]
    ],
    "notifications": []
  }

Test 1.2

$ cat >c2.ml <<EOF
> let x : int option =
> EOF

$ $MERLIN single construct -position 1:22 -filename c2.ml <c2.ml
