CS51 Utilities
==

`cs51/utils` contains some useful utilities for problem sets and labs
throughout CS51. The `Absbook` module will also be referenced
throughout the course textbook, _Abstraction and Design in
Computation_.


Installation
--
The fastest way to install `cs51/utils` is with `opam`:

```
opam pin add CS51Utils https://github.com/cs51/utils.git
```

For more information on `opam pin`, please consult the
[opam documentation](https://opam.ocaml.org/doc/Usage.html)

The advantage of the opam-based method is that other opam packages can
depend on this one, and opam will recompile them automatically as
necessary.

`cs51/utils` can also be installed directly using `make install` and
uninstalled using `make uninstall`.


Tests
--

Certain parts of `cs51/utils` have unit tests, which can be run with
```
$ make test
```

Using `cs51/utils` in utop
--

Run `make utop` (a thin wrapper around `dune utop lib`) to open a
`utop` session with the library loaded:

```ocaml
$ make utop
...
utop # CS51Utils.Absbook.id 51 ;;
- : int = 51
```

