  $ $MERLIN single dump -what typedtree -filename ex1.ml < ex1.ml |
  > grep '==>'
  
  Paired: val x : int ==>{ Ex1.5 }<==
     with val x : int ==>{ Ex1.0 }<==
  
  Paired: type t ==>{ Ex1.8 }<==
     with type t ==>{ Ex1.2 }<==
  Paired: val y : float ==>{ Ex1.9 }<==
     with val y : float ==>{ Ex1.3 }<==
  Paired: val x : int ==>{ Ex1.0 }<==
     with val x : int ==>{ Ex1.0 }<==
  
  Paired: val x : int ==>{ Ex1.0 }<==
     with val x : int ==>{ Ex1.0 }<==
  
  Paired: type t ==>{ Ex1.12 }<==
     with type t ==>{ Ex1.2 }<==
  Paired: val y : float ==>{ Ex1.13 }<==
     with val y : float ==>{ Ex1.3 }<==
              value_description x/81 (ex1.ml[2,28+2]..ex1.ml[2,28+21]) ==>{ Ex1.0 }<==
                  Ttyp_constr \"int/1!\" ==>{ <predef:int> }<==
                type_declaration t/83 ==>{ Ex1.2 }<== (ex1.ml[6,102+2]..ex1.ml[6,102+8])
              value_description y/84 (ex1.ml[7,119+2]..ex1.ml[7,119+22]) ==>{ Ex1.3 }<==
                  Ttyp_constr \"float/4!\" ==>{ <predef:float> }<==
      M/87 ==>{ Ex1.6 }<==
                      Tpat_var \"x/86\" ==>{ Ex1.5 }<==
      F/95 ==>{ Ex1.10 }<==
                    type_declaration t/89 ==>{ Ex1.8 }<== (ex1.ml[28,420+4]..ex1.ml[28,420+10])
                    Tmod_ident \"X/88\" ==>{ Ex1.7 }<==
                        Tpat_var \"y/91\" ==>{ Ex1.9 }<==
      A/99 ==>{ Ex1.11 }<==
            Tmod_ident \"F/95\" ==>{ Ex1.10 }<==
            Tmod_ident \"M/87\" ==>{ Ex1.6 }<==
      B/102 ==>{ Ex1.14 }<==
                  type_declaration t/100 ==>{ Ex1.12 }<== (ex1.ml[56,879+2]..ex1.ml[56,879+8])
                      Tpat_var \"y/101\" ==>{ Ex1.13 }<==
            Tpat_var \"y/103\" ==>{ Ex1.15 }<==
            Texp_ident \"A/99.x\" ==>{ Ex1.0 }<==
            Tpat_var \"z/104\" ==>{ Ex1.16 }<==
            Texp_ident \"A/99.y\" ==>{ Ex1.3 }<==

  $ $MERLIN single dump -what typedtree -filename ex_pair.ml < ex_pair.ml |
  > grep '==>'
  
  Paired: type t = int ==>{ Ex_pair.10 }<==
     with type t ==>{ Ex_pair.0 }<==
  Paired: val to_string : int -> string ==>{ Ex_pair.11 }<==
     with val to_string : t -> string ==>{ Ex_pair.1 }<==
  
  Paired: type t = string ==>{ Ex_pair.14 }<==
     with type t ==>{ Ex_pair.0 }<==
  Paired: val to_string : 'a -> 'a ==>{ Ex_pair.15 }<==
     with val to_string : t -> string ==>{ Ex_pair.1 }<==
  
  Paired: type t = Int.t ==>{ Ex_pair.0 }<==
     with type t ==>{ Ex_pair.0 }<==
  Paired: val to_string : t -> string ==>{ Ex_pair.1 }<==
     with val to_string : t -> string ==>{ Ex_pair.1 }<==
  
  Paired: type t = Int.t ==>{ Ex_pair.0 }<==
     with type t ==>{ Ex_pair.0 }<==
  Paired: val to_string : t -> string ==>{ Ex_pair.1 }<==
     with val to_string : t -> string ==>{ Ex_pair.1 }<==
  
  Paired: type t = String.t * Int.t ==>{ Ex_pair.5 }<==
     with type t ==>{ Ex_pair.0 }<==
  Paired: val to_string : String.t * Int.t -> string ==>{ Ex_pair.6 }<==
     with val to_string : t -> string ==>{ Ex_pair.1 }<==
                type_declaration t/81 ==>{ Ex_pair.0 }<== (ex_pair.ml[2,35+2]..ex_pair.ml[2,35+8])
              value_description to_string/82 (ex_pair.ml[4,51+2]..ex_pair.ml[4,51+35]) ==>{ Ex_pair.1 }<==
                    Ttyp_constr \"t/81\" ==>{ Ex_pair.0 }<==
                    Ttyp_constr \"string/15!\" ==>{ <predef:string> }<==
      Pair/92 ==>{ Ex_pair.9 }<==
                    type_declaration t/86 ==>{ Ex_pair.5 }<== (ex_pair.ml[10,181+2]..ex_pair.ml[10,181+32])
                                Ttyp_constr \"X/84.t\" ==>{ Ex_pair.0 }<==
                                Ttyp_constr \"Y/85.t\" ==>{ Ex_pair.0 }<==
                        Tpat_var \"to_string/87\" ==>{ Ex_pair.6 }<==
                                Texp_ident \"Stdlib!.^\" ==>{ Stdlib.112 }<==
                                      Texp_ident \"X/84.to_string\" ==>{ Ex_pair.1 }<==
                                          Texp_ident \"x/89\" ==>{ Ex_pair.7 }<==
                                      Texp_ident \"Stdlib!.^\" ==>{ Stdlib.112 }<==
                                            Texp_ident \"Y/85.to_string\" ==>{ Ex_pair.1 }<==
                                                Texp_ident \"y/90\" ==>{ Ex_pair.8 }<==
      Int/97 ==>{ Ex_pair.13 }<==
                  type_declaration t/93 ==>{ Ex_pair.10 }<== (ex_pair.ml[24,474+2]..ex_pair.ml[24,474+21])
                          Ttyp_constr \"int/1!\" ==>{ <predef:int> }<==
                      Tpat_var \"to_string/94\" ==>{ Ex_pair.11 }<==
                              Texp_ident \"Stdlib!.string_of_int\" ==>{ Stdlib.119 }<==
                                  Texp_ident \"i/96\" ==>{ Ex_pair.12 }<==
      String/102 ==>{ Ex_pair.17 }<==
                type_declaration t/98 ==>{ Ex_pair.14 }<== (ex_pair.ml[40,717+2]..ex_pair.ml[40,717+24])
                        Ttyp_constr \"string/15!\" ==>{ <predef:string> }<==
                    Tpat_var \"to_string/99\" ==>{ Ex_pair.15 }<==
                          Texp_ident \"s/101\" ==>{ Ex_pair.16 }<==
      P/113 ==>{ Ex_pair.18 }<==
              Tmod_ident \"Pair/92\" ==>{ Ex_pair.9 }<==
              Tmod_ident \"Int/97\" ==>{ Ex_pair.13 }<==
                Tmod_ident \"Pair/92\" ==>{ Ex_pair.9 }<==
                Tmod_ident \"String/102\" ==>{ Ex_pair.17 }<==
              Tmod_ident \"Int/97\" ==>{ Ex_pair.13 }<==
            Texp_ident \"P/113.to_string\" ==>{ Ex_pair.6 }<==

  $ $MERLIN single dump -what typedtree \
  > -filename ex_compressed.ml < ex_compressed.ml |
  > grep '==>'
  
  Paired: val x : int ==>{ Ex_compressed.0 }<==
     with val x : int ==>{ Ex_compressed.1 }<==
  
  Paired: module N : sig val x : int end ==>{ Ex_compressed.2 }<==
     with module N : sig val x : int end ==>{ Ex_compressed.4 }<==
  
  Paired: val x : int ==>{ Ex_compressed.1 }<==
     with val x : int ==>{ Ex_compressed.3 }<==
      M/86 ==>{ Ex_compressed.5 }<==
                N/83 ==>{ Ex_compressed.2 }<==
                                Tpat_var \"x/81\" ==>{ Ex_compressed.0 }<==
                          value_description x/82 (ex_compressed.ml[13,174+4]..ex_compressed.ml[13,174+23]) ==>{ Ex_compressed.1 }<==
                              Ttyp_constr \"int/1!\" ==>{ <predef:int> }<==
                Tsig_module \"N/85\" ==>{ Ex_compressed.4 }<==
                      value_description x/84 (ex_compressed.ml[9,107+4]..ex_compressed.ml[9,107+23]) ==>{ Ex_compressed.3 }<==
                          Ttyp_constr \"int/1!\" ==>{ <predef:int> }<==
            Texp_ident \"M/86.N.x\" ==>{ Ex_compressed.3 }<==

  $ $OCAMLC -bin-annot an_external_module.ml 
  $ $MERLIN single dump -what typedtree \
  > -filename ex_compressed_with_hole.ml < ex_compressed_with_hole.ml |
  > grep '==>'
  
  Paired: val x : int ==>{ An_external_module.0 }<==
     with val x : int ==>{ Ex_compressed_with_hole.0 }<==
  
  Paired: module N : sig val x : int end ==>{ Ex_compressed_with_hole.1 }<==
     with module N : sig val x : int end ==>{ Ex_compressed_with_hole.3 }<==
  
  Paired: val x : int ==>{ Ex_compressed_with_hole.0 }<==
     with val x : int ==>{ Ex_compressed_with_hole.2 }<==
      M/87 ==>{ Ex_compressed_with_hole.4 }<==
                N/84 ==>{ Ex_compressed_with_hole.1 }<==
                            Tmod_ident \"An_external_module!\" ==>{ An_external_module }<==
                          value_description x/83 (ex_compressed_with_hole.ml[7,115+4]..ex_compressed_with_hole.ml[7,115+23]) ==>{ Ex_compressed_with_hole.0 }<==
                              Ttyp_constr \"int/1!\" ==>{ <predef:int> }<==
                Tsig_module \"N/86\" ==>{ Ex_compressed_with_hole.3 }<==
                      value_description x/85 (ex_compressed_with_hole.ml[3,48+4]..ex_compressed_with_hole.ml[3,48+23]) ==>{ Ex_compressed_with_hole.2 }<==
                          Ttyp_constr \"int/1!\" ==>{ <predef:int> }<==
            Texp_ident \"M/87.N.x\" ==>{ Ex_compressed_with_hole.2 }<==
          Tmod_ident \"M/87.N\" ==>{ Ex_compressed_with_hole.3 }<==
