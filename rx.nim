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

proc addOnSubscribe[A](o: var Observer[A], p: proc(s: SimpleSubscriber[A])) =
  o.onSubscribe = p

proc observer[A](xs: seq[A]): Observer[A] =
  result.addOnSubscribe(proc(s: SimpleSubscriber[A]) =
    for x in xs:
      s.onNext(x)
    s.onComplete()
  )

proc single[A](a: A): Observer[A] = observer(@[a])

proc subscriber[A](onNext: proc(a: A)): SimpleSubscriber[A] =
  result.onNext = onNext
  result.onComplete = noop
  result.onError = noop

proc subscribe[A](o: Observer[A], s: SimpleSubscriber[A]) =
  o.onSubscribe(s)

when isMainModule:
  let
    o = observer(@[1, 2, 3, 4, 5])
    o1 = single(6)
    s = subscriber[int](println)
  o.subscribe(s)
  o1.subscribe(s)