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

(*----------------------------------------------------------------------
  Timeouts

  This section provides the ability to evaluate expressions with a
  "timeout", a maximum amount of time the expression may take
  before being abandoned. For instance,

      timeout 5.0 (lazy expr)

  forces `expr` for up to five seconds; if `expr` produces a value
  within that budget, its value is returned; otherwise the special
  exception `Timeout` is raised in place of a result. The budget is
  a count of seconds, but fractional budgets are supported:
  `timeout 0.1 (lazy expr)` caps `expr` at one hundred milliseconds.

  Timeouts are useful whenever a computation could fail to
  terminate or could take an unacceptable amount of time -- for
  example, in a unit-test harness that must remain responsive
  even when one of its tests runs forever.

  This section uses facilities of OCaml well beyond the scope 
  of this book. The interested student may want to look this
  over after they've completed the full course.
 *)

(* The exception raised by `timeout` when its time budget expires
   before the wrapped computation completes. *)
exception Timeout

(* The three possible ways a `timeout` call can end:
     - `Done (Ok v)`    -- the computation returned `v`
     - `Done (Error e)` -- the computation raised exception `e`
     - `Timed_out`      -- the watchdog fired before the computation
                           finished
   We collapse "returned" and "raised" into the standard
   `('a, exn) result` type, then pair that with a separate
   `Timed_out` constructor so the synchronization protocol used
   inside `timeout` needn't mix exception-throwing with
   outcome-reporting. *)
type 'a outcome = Done of ('a, exn) result | Timed_out

(* timeout time f -- Forces lazy computation `f`, returning what `f`
   returns if it completes within `time` seconds (fractional values
   allowed), and raising `Timeout` otherwise. Exceptions raised by
   `f` itself propagate to the caller unchanged.

   Implemented as a race between two helper threads -- a worker that
   runs the computation and a watchdog that sleeps for the time
   budget -- moderated by the main thread, which sleeps on a
   condition variable until one of them reports an outcome.

   Note that when the watchdog fires and `timeout` raises, the
   worker thread is NOT killed; any side effects in `f` that haven't
   yet executed may still execute in the background. Forcibly
   killing threads is unsafe (mutexes left locked, partial state),
   so we accept the leak. For non-terminating workloads such as
   deadlocks, the worker is stuck and harmless; for runaway
   terminating workloads it will eventually complete and silently
   discard its result. *)
let timeout (time : float) (f : 'a Lazy.t) : 'a =

  (* Shared state. `m` guards `outcome` (and serializes the
     condition-variable protocol); `c` is what the main thread
     sleeps on; `outcome` records the first reported result. *)
  let m = Mutex.create () in
  let c = Condition.create () in
  let outcome : 'a outcome option ref = ref None in

  (* `finish o` -- The reporting protocol used by both helper
     threads. Takes the lock, and IF no outcome has been recorded
     yet, records `o` and wakes the main thread. Otherwise the
     report is silently dropped: only the first finisher wins. *)
  let finish o =
    Mutex.lock m;
    if !outcome = None then begin
      outcome := Some o;
      Condition.signal c
    end;
    Mutex.unlock m in

  (* Worker thread. Forces `f`, catching any exception so it
     becomes part of the reported outcome rather than silently
     terminating the worker. *)
  let _ = Thread.create (fun () ->
    finish (Done (try Ok (Lazy.force f) with e -> Error e))) () in

  (* Watchdog thread. Sleeps (real sleep, not busy-waiting) for the
     time budget, then reports `Timed_out`. *)
  let _ = Thread.create (fun () ->
    Thread.delay time;
    finish Timed_out) () in

  (* Main thread waits. Standard condition-variable idiom:
     `Condition.wait c m` atomically releases `m` and parks the
     thread, then re-acquires `m` and returns when signaled. The
     `while` guards against spurious wakeups. *)
  Mutex.lock m;
  while !outcome = None do Condition.wait c m done;
  Mutex.unlock m;

  (* Dispatch on the recorded outcome. Three real cases plus an
     impossible one (the wait loop guarantees outcome is `Some _`,
     but the `None -> assert false` arm preserves exhaustiveness
     without resorting to a wildcard). *)
  match !outcome with
  | Some (Done (Ok v))    -> v
  | Some (Done (Error e)) -> raise e
  | Some Timed_out        -> raise Timeout
  | None                  -> assert false ;;
