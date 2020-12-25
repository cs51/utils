(lang dune 1.10)
(name CS51Utils)
(source (github cs51/utils))
(authors "CS51 Heads")
(maintainers "heads@cs51.io")
(version 1.0.0)
(generate_opam_files true)

(package
 (name CS51Utils)
 (synopsis "CS51 Utilities")
 (description "Utilities that might be helpful during CS51.")
 (depends
   (alcotest (>= 1.2.0))
   (qcheck (>= 0.16))
   (qcheck-alcotest (>= 0.16))
 )
)
