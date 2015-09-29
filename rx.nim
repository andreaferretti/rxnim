import os, threadpool

type
  Observable[A] = object
    onSubscribe: proc(s: Subscriber[A])
  ConnectableObservable[A] = object
    source: Observable[A]
    listeners: seq[Subscriber[A]]
  Subscriber[A] = object
    onNext: proc(a: A)
    onComplete: proc()
    onError: proc()

proc noop() = discard
proc noop(a: auto) = discard

proc println[A](a: A) = echo(a)

proc create[A](p: proc(s: Subscriber[A])): Observable[A] =
  result.onSubscribe = p

proc observer[A](xs: seq[A]): Observable[A] =
  create(proc(s: Subscriber[A]) =
    for x in xs:
      s.onNext(x)
    s.onComplete()
  )

proc single[A](a: A): Observable[A] = observer(@[a])

proc subscriber[A](onNext: proc(a: A), onComplete: proc() = noop, onError: proc() = noop): Subscriber[A] =
  result.onNext = onNext
  result.onComplete = onComplete
  result.onError = onError

proc subscribe[A](o: Observable[A], s: Subscriber[A]) =
  o.onSubscribe(s)

proc subscribe[A](o: var ConnectableObservable[A], s: Subscriber[A]) =
  o.listeners.add(s)

proc map[A, B](o: Observable[A], f: proc(a: A): B): Observable[B] =
  create(proc(s: Subscriber[B]) =
    o.subscribe(subscriber(
      onNext = proc(a: A) = s.onNext(f(a)),
      onComplete = s.onComplete,
      onError = s.onError
    ))
  )

proc filter[A](o: Observable[A], f: proc(a: A): bool): Observable[A] =
  create(proc(s: Subscriber[A]) =
    o.subscribe(subscriber(
      onNext = proc(a: A) =
        if f(a): s.onNext(a),
      onComplete = s.onComplete,
      onError = s.onError
    ))
  )

proc delay[A](o: Observable[A], millis: int): Observable[A] =
  create(proc(s: Subscriber[A]) =
    o.subscribe(subscriber(
      onNext = proc(a: A) =
        s.onNext(a)
        sleep(millis),
      onComplete = s.onComplete,
      onError = s.onError
    ))
  )

proc delay[A](o: Observable[A], millis: proc(a: A): int): Observable[A] =
  create(proc(s: Subscriber[A]) =
    o.subscribe(subscriber(
      onNext = proc(a: A) =
        s.onNext(a)
        sleep(millis(a)),
      onComplete = s.onComplete,
      onError = s.onError
    ))
  )

proc buffer[A](o: Observable[A], n: int): Observable[seq[A]] =
  create(proc(s: Subscriber[seq[A]]) =
    var buffer = newSeq[A](n)
    var i = 0
    o.subscribe(subscriber(
      onNext = proc(a: A) =
        buffer[i] = a
        i += 1
        if i == n:
          s.onNext(buffer)
          buffer = newSeq[A](n)
          i = 0,
      onComplete = s.onComplete,
      onError = s.onError
    ))
  )

proc concat[A](o1, o2: Observable[A]): Observable[A] =
  create(proc(s: Subscriber[A]) =
    o1.subscribe(subscriber(
      onNext = s.onNext,
      onComplete = proc() =
        o2.subscribe(s),
      onError = s.onError
    ))
  )

proc sendToNewThread[A](o: Observable[A]): Observable[A] =

  create(proc(s: Subscriber[A]) =
    var ch: Channel[A]
    ch.open()

    proc readFromOtherThread() {.thread.} =
      while true:
        let a = ch.recv()
        s.onNext(a)

    # var th: Thread[void]
    # createThread[void](th, readFromOtherThread)
    spawn readFromOtherThread()

    o.subscribe(subscriber(
      onNext = proc(a: A) =
        ch.send(a),
      onComplete = s.onComplete,
      onError = s.onError
    ))
  )

proc publish[A](o: Observable[A]): ConnectableObservable[A] =
  result.listeners = @[]
  result.source = o

proc connect[A](o: ConnectableObservable[A]) =
  o.source.subscribe(subscriber(
    onNext = proc(a: A) =
      for l in o.listeners:
        l.onNext(a),
    onComplete = proc() =
      for l in o.listeners:
        l.onComplete(),
    onError = proc() =
      for l in o.listeners:
        l.onError()
  ))

when isMainModule:
  import future
  var o = observer(@[1, 2, 3, 4, 5])
    .map((x: int) => x * x)
    .filter((x: int) => x > 3)
    .delay((x: int) => 100 * x)
    .sendToNewThread()
    .concat(single(6))
    .concat(single(3))
    .buffer(2)
    .publish()

  o.subscribe(subscriber[seq[int]](println))
  o.subscribe(subscriber[seq[int]](println))
  o.connect()