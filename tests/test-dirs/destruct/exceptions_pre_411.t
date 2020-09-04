(enabled_if (and (>= %{ocaml_version} 4.08.0) (< %{ocaml_version} 4.11.0)))
FIXME
  $ $MERLIN single case-analysis -start 3:4 -end 3:8 -filename complete.ml -log-file /tmp/mlog2 <<EOF \
  > let _ = \
  >   match (None : int option) with \
  >   | exception _ -> () \
  >   | Some 3 -> () \
  > EOF
  {
    "class": "return",
    "value": [
      {
        "start": {
          "line": 4,
          "col": 16
        },
        "end": {
          "line": 4,
          "col": 16
        }
      },
      "
  | Some 0|None -> (??)"
    ],
    "notifications": []
  }

FIXME
  $ $MERLIN single case-analysis -start 4:4 -end 4:8 -filename complete.ml -log-file /tmp/mlog2 <<EOF \
  > let _ = \
  >   match (None : int option) with \
  >   | exception _ -> () \
  >   | Some _ -> () \
  > EOF
  {
    "class": "return",
    "value": [
      {
        "start": {
          "line": 4,
          "col": 16
        },
        "end": {
          "line": 4,
          "col": 16
        }
      },
      "
  | None -> (??)"
    ],
    "notifications": []
  }

  $ $MERLIN single case-analysis -start 4:5 -end 4:5 -filename no_comp_pat.ml <<EOF \
  > let _ = \
  >   match (None : unit option) with \
  >   | exception _ -> () \
  >   | None -> () \
  > EOF
  {
    "class": "return",
    "value": [
      {
        "start": {
          "line": 4,
          "col": 14
        },
        "end": {
          "line": 4,
          "col": 14
        }
      },
      "
  | Some _ -> (??)"
    ],
    "notifications": []
  }

FIXME: `Some 0` certainly is a missing case but we can do better:

  $ $MERLIN single case-analysis -start 4:4 -end 4:8 -filename complete.ml -log-file /tmp/mlog2 <<EOF \
  > let _ = \
  >   match (None : int option) with \
  >   | exception _ -> () \
  >   | Some 3 -> () \
  > EOF
  {
    "class": "return",
    "value": [
      {
        "start": {
          "line": 4,
          "col": 16
        },
        "end": {
          "line": 4,
          "col": 16
        }
      },
      "
  | Some 0|None -> (??)"
    ],
    "notifications": []
  }
