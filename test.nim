import unittest, rx, future, times

type
  UnexpectedOnError = object of Exception
  TestResult[A] = object
    elems: seq[A]
    completed: bool

proc tester[A](): ref TestResult[A] =
  new result
  result.elems = @[]
  result.completed = false

proc collect[A](t: ref TestResult[A]): Subscriber[A] =
  subscriber(
    onNext = proc(a: A) =
      t.elems.add(a),
    onComplete = proc() =
      t.completed = true,
    onError = proc(e: ref Exception) =
      raise e
  )

proc `=~`(a, b: float): bool =
  (a - b).abs < 0.01

suite "basic observables":
  test "empty observable":
    var t = tester[int]()
    rx.empty[int]().subscribe(collect(t))
    check t.elems.len == 0
    check t.completed
  test "single element observable":
    var t = tester[int]()
    rx.single(5).subscribe(collect(t))
    check t.elems == @[5]
    check t.completed
  test "seq observable":
    var t = tester[int]()
    rx.observer(@[1, 2, 3, 4]).subscribe(collect(t))
    check t.elems == @[1, 2, 3, 4]
    check t.completed
  test "range observable":
    var t = tester[int]()
    rx.observer(1 .. 10).subscribe(collect(t))
    check t.elems == @[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    check t.completed

suite "basic operators":
  let o = observer(1 .. 5)

  test "map":
    var t = tester[int]()
    o.map(x => 2 * x).subscribe(collect(t))
    check t.elems == @[2, 4, 6, 8, 10]
    check t.completed
  test "filter":
    var t = tester[int]()
    o.filter(x => 2 < x).subscribe(collect(t))
    check t.elems == @[3, 4, 5]
    check t.completed
  test "take":
    var t = tester[int]()
    o.take(3).subscribe(collect(t))
    check t.elems == @[1, 2, 3]
    check t.completed
  test "drop":
    var t = tester[int]()
    o.drop(2).subscribe(collect(t))
    check t.elems == @[3, 4, 5]
    check t.completed
  test "concat":
    var t = tester[int]()
    o.concat(o).subscribe(collect(t))
    check t.elems == @[1, 2, 3, 4, 5, 1, 2, 3, 4, 5]
    check t.completed
  test "foreach":
    var t = tester[int]()
    o.foreach((x: int) => t.elems.add(x))
    check t.elems == @[1, 2, 3, 4, 5]

suite "delay operators":
  let o = observer(1 .. 5)

  test "delay with a fixed interval":
    var t = tester[int]()
    let before = epochTime()
    o.delay(200).subscribe(collect(t))
    let after = epochTime()
    check t.elems == @[1, 2, 3, 4, 5]
    check t.completed
    check before =~ (after - 1.0)
  test "delay with a variable interval":
    var t = tester[int]()
    let before = epochTime()
    o.delay(x => 100 * x).subscribe(collect(t))
    let after = epochTime()
    check t.elems == @[1, 2, 3, 4, 5]
    check t.completed
    check before =~ (after - 1.5)