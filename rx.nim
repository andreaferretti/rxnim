import os

type
  Observer[A] = object
    onSubscribe: proc(s: SimpleSubscriber[A])
  SimpleSubscriber[A] = object
    onNext: proc(a: A)
    onComplete: proc()
    onError: proc()

proc noop() = discard
proc noop(a: auto) = discard

proc println[A](a: A) = echo(a)

proc create[A](p: proc(s: SimpleSubscriber[A])): Observer[A] =
  result.onSubscribe = p

proc observer[A](xs: seq[A]): Observer[A] =
  create(proc(s: SimpleSubscriber[A]) =
    for x in xs:
      s.onNext(x)
    s.onComplete()
  )

proc single[A](a: A): Observer[A] = observer(@[a])

proc subscriber[A](onNext: proc(a: A), onComplete: proc(), onError: proc()): SimpleSubscriber[A] =
  result.onNext = onNext
  result.onComplete = onComplete
  result.onError = onError

proc subscriber[A](onNext: proc(a: A)): SimpleSubscriber[A] =
  subscriber(onNext, noop, noop)

proc subscribe[A](o: Observer[A], s: SimpleSubscriber[A]) =
  o.onSubscribe(s)

proc map[A, B](o: Observer[A], f: proc(a: A): B): Observer[B] =
  create(proc(s: SimpleSubscriber[B]) =
    o.subscribe(subscriber(
      onNext = proc(a: A) = s.onNext(f(a)),
      onComplete = s.onComplete,
      onError = s.onError
    ))
  )

proc filter[A](o: Observer[A], f: proc(a: A): bool): Observer[A] =
  create(proc(s: SimpleSubscriber[A]) =
    o.subscribe(subscriber(
      onNext = proc(a: A) =
        if f(a): s.onNext(a),
      onComplete = s.onComplete,
      onError = s.onError
    ))
  )

proc delay[A](o: Observer[A], millis: int): Observer[A] =
  create(proc(s: SimpleSubscriber[A]) =
    o.subscribe(subscriber(
      onNext = proc(a: A) =
        s.onNext(a)
        sleep(millis),
      onComplete = s.onComplete,
      onError = s.onError
    ))
  )

proc concat[A](o1, o2: Observer[A]): Observer[A] =
  create(proc(s: SimpleSubscriber[A]) =
    o1.subscribe(subscriber(
      onNext = s.onNext,
      onComplete = proc() =
        o2.subscribe(s),
      onError = s.onError
    ))
  )


when isMainModule:
  import future
  let
    o = observer(@[1, 2, 3, 4, 5])
      .map((x: int) => x * x)
      .filter((x: int) => x > 3)
      .delay(500)
      .concat(single(6))
    s = subscriber[int](println)
  o.subscribe(s)