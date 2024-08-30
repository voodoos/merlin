Test case from github issue 1809
  $ cat >test2.ml <<EOF
  > (** some doc *)
  > let foo ?(pp=(fun _ _ -> ())) () =
  >   Format.pp_print_list pp Format.std_formatter []
  > EOF

FIXME: we shouldn't show [foo] documentation here
  $ $MERLIN single document -position 3:23 -filename test2.ml < test2.ml
  {
    "class": "return",
    "value": "some doc",
    "notifications": []
  }

  $ $MERLIN single document -position 3:24 -filename test2.ml < test2.ml
  {
    "class": "return",
    "value": "some doc",
    "notifications": []
  }

  $ $MERLIN single document -position 3:25 -filename test2.ml < test2.ml
  {
    "class": "return",
    "value": "some doc",
    "notifications": []
  }
