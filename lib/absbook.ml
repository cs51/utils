(*
                  General utilities used in the book
                Abstraction and Design for Computation
                         -.-. ... ..... .----
                          Stuart M. Shieber

    Note that some of these may not work on Windows systems, as they
    do not provide full support for Sys and Unix modules.
 *)


(*----------------------------------------------------------------------
  Functional utilities
 *)

(* id x -- The identity function. Returns `x`. *)

let id x = x ;;

(* const x -- Returns the constant function returning `x`. *)

let const x _ = x
  
(* reduce f list -- Applies `f` to the elements of `list`
   left-to-right (as in `List.fold_left`) using first element of
   `list` as initial value. This is a traditional higher-order
   function, standard in the literature, but an oversight in not
   appearing in the `Stdlib` or `List` modules. *)

let reduce (f : 'a -> 'a -> 'a) (list : 'a list) : 'a = 
  match list with
  | head::tail -> List.fold_left f head tail
  | [] -> failwith "can't reduce empty list" ;;

(* range min max -- Returns a list of integers from `min` to `max`
   inclusive. *)
  
let rec range (min : int) (max : int) : int list =
  if min > max then []
  else min :: range (min + 1) max ;;

(*----------------------------------------------------------------------
  Assertions and debugging
 *)

(* unit_test condition msg -- Tests `condition` and prints an indicative
   message `msg` related to the condition along with a passed or failed
   string *)

let unit_test (condition : bool) (msg : string) : unit =
  if condition then
    Printf.printf "%s passed\n" msg
  else
    Printf.printf "%s FAILED\n" msg ;;

(* unit_test_within tolerance test_value expected msg -- Tests that
   `test_value` and `expected` value are within a `tolerance`,
   printing `msg` accordingly as per `unit_test` *)

let unit_test_within (tolerance : float)
                     (test_value : float)
                     (expected : float)
                     (msg : string)
                   : unit =
  unit_test (abs_float (test_value -. expected) < tolerance) msg ;;
  
(* verify assertion format_string ... -- Verifies that the boolean
   `assertion` evaluates to `true`, continuing silently if so; if the
   assertion fails (evaluates to `false`) it prints the
   `format_string`, as per `Printf.printf`, which can reference
   further arguments as well. Example of usage:

        # let n = 5 in
          verify (n mod 2 = 0) "n is %d, but should be even\n" n ;;
        n is 5, but should be even
        - : unit = ()
 *)

let verify (condition : bool)
           (fmt : ('a, out_channel, unit) format)
         : 'a =
  if condition then Printf.ifprintf stdout fmt
  else Printf.printf fmt ;;

  
(*----------------------------------------------------------------------
  Performance monitoring        
 *)

(* repeat count f x -- Applies `f` to `x` repeatedly, for `count`
   iterations, ignoring all but the last application, and returning
   the result of the last application. *)
let rec repeat (count : int) (f : 'a -> 'b) (x : 'a) : 'b =
  if count <= 0 then raise (Invalid_argument "repeat: count less than 1")
  else if count = 1 then f x
  else (ignore (f x);
        repeat (count - 1) f x) ;;
  
(* call_timed ?(count = 1) f x -- Applies `f` to `x` for `count`
   iterations returning a pair of the last result and the time in
   milliseconds to execute all of the iterations. *)
let call_timed ?(count = 1) (f : 'a -> 'b) (x : 'a) : 'b * float =
  let t0 = Unix.gettimeofday() in 
  let result = repeat count f x in 
  let t1 = Unix.gettimeofday() in
  (result, 1000. *. (t1 -. t0)) ;;

(* call_reporting_time f x -- Applies `f` to `x` for `count`
   iterations returning the last result, reporting timing information
   on `stdout` as a side effect. *)
let call_reporting_time ?(count : int = 1) (f : 'a -> 'b) (x : 'a) : 'b =
  let result, time = call_timed ~count f x in
  Printf.printf "time (msecs): %f\n" time;
  result ;;
