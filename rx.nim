import os, threadpool, times

type
  Observable*[A] = object
    onSubscribe: proc(s: Subscriber[A])
  ConnectableObservable*[A] = object
    source: Observable[A]
    listeners: seq[Subscriber[A]]
  Subscriber*[A] = object
    onNext*: proc(a: A)
    onComplete*: proc()
    onError*: proc()
  Scheduler* = object
    scheduleNow: proc(p: proc())
    scheduleLater: proc(p: proc(), t: TimeInterval)
    now*: proc(): Time

template millis(t: TimeInterval): auto =
  t.milliseconds + 1000 * t.seconds # fix me

template schedule(s: Scheduler, p: expr) =
  s.scheduleNow(p)

template schedule(s: Scheduler, p, t: expr) =
  s.scheduleLater(p, t)

proc immediateScheduler*(): Scheduler =
  result.scheduleNow = proc(p: proc()) = p()
  result.scheduleLater = proc(p: proc(), t: TimeInterval) =
    sleep(t.millis)
    p()
  result.now = proc(): Time =
    epochTime().fromSeconds()

proc noop*() = discard
proc noop*(a: auto) = discard

proc println[A](a: A) = echo(a)

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

proc subscriber*[A](onNext: proc(a: A), onComplete: proc(), onError: proc()): Subscriber[A] =
  result.onNext = onNext
  result.onComplete = onComplete
  result.onError = onError

proc subscriber*[A](onNext: proc(a: A)): Subscriber[A] =
  result.onNext = onNext
  result.onComplete = noop
  result.onError = noop

proc subscribe*[A](o: Observable[A], s: Subscriber[A]) =
  o.onSubscribe(s)

proc subscribe*[A](o: var ConnectableObservable[A], s: Subscriber[A]) =
  o.listeners.add(s)

proc map*[A, B](o: Observable[A], f: proc(a: A): B): Observable[B] =
  create(proc(s: Subscriber[B]) =
    o.subscribe(subscriber(
      onNext = proc(a: A) = s.onNext(f(a)),
      onComplete = s.onComplete,
      onError = s.onError
    ))
  )

proc foreach*[A](o: Observable[A], f: proc(a: A)) =
  o.subscribe(subscriber[A](f))

proc filter*[A](o: Observable[A], f: proc(a: A): bool): Observable[A] =
  create(proc(s: Subscriber[A]) =
    o.subscribe(subscriber(
      onNext = proc(a: A) =
        if f(a): s.onNext(a),
      onComplete = s.onComplete,
      onError = s.onError
    ))
  )

proc take*[A](o: Observable[A], n: int): Observable[A] =
  var count = 0
  create(proc(s: Subscriber[A]) =
    o.subscribe(subscriber(
      onNext = proc(a: A) =
        if count <= n - 1:
          count += 1
          s.onNext(a)
        elif count == n:
          s.onComplete(),
      onComplete = proc() =
        if count < n:
          s.onComplete(),
      onError = proc() =
        if count < n:
          s.onError()
    ))
  )

proc drop*[A](o: Observable[A], n: int): Observable[A] =
  var count = 0
  create(proc(s: Subscriber[A]) =
    o.subscribe(subscriber(
      onNext = proc(a: A) =
        if count <= n - 1:
          count += 1
        else:
          s.onNext(a),
      onComplete = s.onComplete,
      onError = s.onError
    ))
  )

proc concat*[A](o1, o2: Observable[A]): Observable[A] =
  create(proc(s: Subscriber[A]) =
    o1.subscribe(subscriber(
      onNext = s.onNext,
      onComplete = proc() =
        o2.subscribe(s),
      onError = s.onError
    ))
  )

proc delay*[A](o: Observable[A], millis: int): Observable[A] =
  create(proc(s: Subscriber[A]) =
    o.subscribe(subscriber(
      onNext = proc(a: A) =
        s.onNext(a)
        sleep(millis),
      onComplete = s.onComplete,
      onError = s.onError
    ))
  )

proc delay*[A](o: Observable[A], millis: proc(a: A): int): Observable[A] =
  create(proc(s: Subscriber[A]) =
    o.subscribe(subscriber(
      onNext = proc(a: A) =
        s.onNext(a)
        sleep(millis(a)),
      onComplete = s.onComplete,
      onError = s.onError
    ))
  )

proc buffer*[A](o: Observable[A], n: int): Observable[seq[A]] =
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

proc buffer*[A](o: Observable[A], t: TimeInterval): Observable[seq[A]] =
  let millis = t.milliseconds + 1000 * t.seconds # fix this

  create(proc(s: Subscriber[seq[A]]) =
    var ch: Channel[A]
    ch.open()

    proc readFromOtherThread() {.thread.} =
      while true:
        let n = ch.peek()
        var buffer = newSeq[A](n)
        for i in 0 .. < n:
          buffer[i] = ch.recv()
        s.onNext(buffer)
        sleep(millis)

    spawn readFromOtherThread()

    o.subscribe(subscriber(
      onNext = proc(a: A) =
        ch.send(a),
      onComplete = s.onComplete,
      onError = s.onError
    ))
  )

proc sendToNewThread*[A](o: Observable[A]): Observable[A] =

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

proc publish*[A](o: Observable[A]): ConnectableObservable[A] =
  result.listeners = @[]
  result.source = o

{.push warning[SmallLshouldNotBeUsed]: off .}
proc connect*[A](o: ConnectableObservable[A]) =
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
{.pop.}

when isMainModule:
  import future, sequtils
  # var o = observer(@[1, 2, 3, 4, 5])
  #   .map((x: int) => x * x)
  #   .filter((x: int) => x > 3)
  #   .delay((x: int) => 100 * x)
  #   .sendToNewThread()
  #   .concat(single(6))
  #   .concat(single(3))
  #   .buffer(2)
  #   .publish()
  #
  # o.subscribe(subscriber[seq[int]](println))
  # o.subscribe(subscriber[seq[int]](println))
  # o.connect()
  #
  # repeat(12)
  #   .drop(3)
  #   .take(10)
  #   .sendToNewThread()
  #   .subscribe(subscriber[int](println))
  #
  # observer(1 .. 100)
  #   .delay((x: int) => x)
  #   .map((x: int) => x * x)
  #   .buffer(initInterval(seconds = 1))
  #   .subscribe(subscriber[seq[int]](println))
  let imm = immediateScheduler()
  imm.schedule(proc() =
    echo "Scheduled operation"
  )

  sync()