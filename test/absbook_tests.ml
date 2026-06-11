module Absbook = CS51Utils.Absbook

let test_identity_function =
  QCheck.Test.make ~count:1000 ~name:"test identity"
    QCheck.(int)
    (fun i -> Absbook.id i = i)

(* Timeout tests:
     - fast computation returns its value
     - slow computation raises Timeout
     - early-completing computation returns long before the time
       budget would expire (verifies early termination)
     - exception in the wrapped computation propagates to caller *)

let test_timeout_returns_value () =
  Alcotest.(check int)
    "fast computation returns 42"
    42 (Absbook.timeout 5.0 (lazy 42))

let test_timeout_fires_on_slow () =
  Alcotest.check_raises
    "slow computation raises Timeout"
    Absbook.Timeout
    (fun () ->
       ignore (Absbook.timeout 0.1
                 (lazy (Thread.delay 5.0; 0))))

let test_timeout_terminates_early () =
  let t0 = Unix.gettimeofday () in
  let v = Absbook.timeout 5.0 (lazy (Thread.delay 0.05; 7)) in
  let dt = Unix.gettimeofday () -. t0 in
  Alcotest.(check int) "value returned" 7 v;
  Alcotest.(check bool)
    "elapsed well under the 5 s budget" true (dt < 1.0)

exception Propagation_marker

let test_timeout_propagates_exception () =
  Alcotest.check_raises
    "wrapped exception propagates unchanged"
    Propagation_marker
    (fun () ->
       ignore (Absbook.timeout 5.0 (lazy (raise Propagation_marker))))

let tests = [
  QCheck_alcotest.to_alcotest test_identity_function;
  Alcotest.test_case "timeout returns value"     `Quick test_timeout_returns_value;
  Alcotest.test_case "timeout fires on slow"     `Slow  test_timeout_fires_on_slow;
  Alcotest.test_case "timeout terminates early"  `Quick test_timeout_terminates_early;
  Alcotest.test_case "timeout propagates exn"    `Quick test_timeout_propagates_exception;
]
