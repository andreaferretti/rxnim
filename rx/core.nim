type
  Observable*[A] = object
    onSubscribe: proc(s: Subscriber[A])
  Subscriber*[A] = object
    onNext*: proc(a: A)
    onComplete*: proc()
    onError*: proc(e: ref Exception)

proc noop*() = discard
proc noop*(a: auto) = discard

proc create*[A](p: proc(s: Subscriber[A])): Observable[A] =
  result.onSubscribe = p

proc observer*[A](xs: seq[A] or Slice[A]): Observable[A] =
  create(proc(s: Subscriber[A]) =
    for x in xs:
      s.onNext(x)
    s.onComplete()
  )

proc empty*[A](): Observable[A] =
  create(proc(s: Subscriber[A]) =
    s.onComplete()
  )

proc single*[A](a: A): Observable[A] = observer(@[a])

proc repeat*[A](a: A): Observable[A] =
  create(proc(s: Subscriber[A]) =
    while true:
      s.onNext(a)
  )

proc subscriber*[A](onNext: proc(a: A), onComplete: proc(), onError: proc(e: ref Exception)): Subscriber[A] =
  result.onNext = onNext
  result.onComplete = onComplete
  result.onError = onError

proc subscriber*[A](onNext: proc(a: A)): Subscriber[A] =
  result.onNext = onNext
  result.onComplete = noop
  result.onError = noop

proc subscribe*[A](o: Observable[A], s: Subscriber[A]) =
  o.onSubscribe(s)