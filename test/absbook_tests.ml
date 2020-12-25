module Absbook = CS51Utils.Absbook

let test_identity_function =
  QCheck.Test.make ~count:1000 ~name:"test identity"
    QCheck.(int)
    (fun i -> Absbook.id i = i)

let tests = [ QCheck_alcotest.to_alcotest test_identity_function ]
