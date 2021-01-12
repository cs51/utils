(*
                                CS 51
			Graphics Module Check

  A simple test to verify that the OCaml graphics module is available
  and properly hooked up to X11.
 *)

module G = Graphics ;;

let test () =
  G.auto_synchronize false;
  G.open_graph "";
  G.resize_window 100 100;

  G.set_color G.red;
  G.fill_rect 0 0 100 100;
  
  G.set_color G.white;
  G.fill_circle 50 15 10;
  G.fill_rect 42 35 16 55;
  
  ignore (G.read_key ()) ;;

let _ = test () ;;
