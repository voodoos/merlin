  $ cat >main.ml <<'EOF'
  > let x' = 1
  > let x = 41
  > let f x = x
  > let y = f x
  > EOF

  $ $MERLIN server occurrences -scope local -identifier-at 3:10 \
  > -log-file log_1 -log-section index \
  > -filename main.ml <main.ml >/dev/null 

  $ cat >main.ml <<'EOF'
  > let x' = 1
  > let x = 42
  > let f x = x 
  > let y = f x
  > EOF

  $ $MERLIN server occurrences -scope local -identifier-at 3:10 \
  > -log-file log_2 -log-section index \
  > -filename main.ml <main.ml >/dev/null

FIXME: The uids should be the same on both queries !
  $ cat log_1 | grep Found | cat >log_1g
  $ cat log_2 | grep Found | cat >log_2g
  $ diff log_1g log_2g
  1,3c1,3
  < Found x (File "main.ml", line 3, characters 10-11) wiht uid Main.3
  < Found f (File "main.ml", line 4, characters 8-9) wiht uid Main.2
  < Found x (File "main.ml", line 4, characters 10-11) wiht uid Main.1
  ---
  > Found x (File "main.ml", line 3, characters 10-11) wiht uid Main.7
  > Found f (File "main.ml", line 4, characters 8-9) wiht uid Main.6
  > Found x (File "main.ml", line 4, characters 10-11) wiht uid Main.5
  [1]

  $ $MERLIN server stop-server
