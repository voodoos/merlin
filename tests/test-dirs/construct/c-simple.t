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
  C: None (int option) []
  C: Some (int option) [int]
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
        "!_",
        "Some (y )",
        "_ @@ _",
        "Some (_ * _)",
        "exit _",
        "Some (_ + _)",
        "failwith _",
        "Some (_ - _)",
        "fst _",
        "Some (_ / _)",
        "input_value _",
        "Some (__LINE__ )",
        "int_of_string_opt _",
        "Some (abs _)",
        "invalid_arg _",
        "Some (_ asr _)",
        "max _ _",
        "Some (compare _ _)",
        "min _ _",
        "Some (in_channel_length _)",
        "raise _",
        "Some (input _ _ _ _)",
        "raise_notrace _",
        "Some (input_binary_int _)",
        "read_int_opt _",
        "Some (input_byte _)",
        "snd _",
        "Some (int_of_char _)",
        "_ |> _",
        "Some (int_of_float _)",
        "Some (int_of_string _)",
        "Some (_ land _)",
        "Some (lnot _)",
        "Some (_ lor _)",
        "Some (_ lsl _)",
        "Some (_ lsr _)",
        "Some (_ lxor _)",
        "Some (max_int )",
        "Some (min_int )",
        "Some (_ mod _)",
        "Some (out_channel_length _)",
        "Some (pos_in _)",
        "Some (pos_out _)",
        "Some (pred _)",
        "Some (read_int _)",
        "Some (succ _)",
        "Some (truncate _)",
        "Some (+ _)",
        "Some (- _)"
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
        "!_",
        "{ a = _; b = _ }",
        "_ @@ _",
        "exit _",
        "failwith _",
        "fst _",
        "input_value _",
        "invalid_arg _",
        "max _ _",
        "min _ _",
        "raise _",
        "raise_notrace _",
        "snd _",
        "_ |> _"
      ]
    ],
    "notifications": []
  }
