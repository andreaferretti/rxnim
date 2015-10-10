import os, threadpool, times
import rx/schedulers, rx/core, rx/connectable

export schedulers, core, connectable



proc println[A](a: A) = echo(a)

proc lift[A, B](o: Observable[A], f: proc(s: Subscriber[B], a: A), sch: Scheduler): auto =
  create(proc(s: Subscriber[B]) =
    o.subscribe(subscriber(
      onNext = proc(a: A) = sch.schedule(proc() =
        f(s, a)
      ),
      onComplete = proc() =
        sch.schedule(s.onComplete),
      onError = proc(e: ref Exception) = sch.schedule(proc() =
        s.onError(e)
      )
    ))
  )

proc map*[A, B](o: Observable[A], f: proc(a: A): B, sch = immediateScheduler()): Observable[B] =
  lift[A, B](o, proc(s: Subscriber[B], a: A) = s.onNext(f(a)), sch)

proc foreach*[A](o: Observable[A], f: proc(a: A)) =
  o.subscribe(subscriber[A](f))

proc filter*[A](o: Observable[A], f: proc(a: A): bool, sch = immediateScheduler()): Observable[A] =
  lift[A, A](o,
    proc(s: Subscriber[A], a: A) =
      if f(a): s.onNext(a),
    sch)

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
      onError = proc(e: ref Exception) =
        if count < n:
          s.onError(e)
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

proc delay*[A](o: Observable[A], t: TimeInterval, sch = immediateScheduler()): Observable[A] =
  create(proc(s: Subscriber[A]) =
    o.subscribe(subscriber(
      onNext = proc(a: A) = sch.schedule(proc() =
        s.onNext(a)
      , t),
      onComplete = proc() =
        sch.schedule(s.onComplete),
      onError = proc(e: ref Exception) = sch.schedule(proc() =
        s.onError(e)
      )
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

when isMainModule:
  import future, sequtils
  var o = observable(@[1, 2, 3, 4, 5])
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

  repeat(12)
    .drop(3)
    .take(10)
    .sendToNewThread()
    .subscribe(subscriber[int](println))

  observable(1 .. 100)
    .delay((x: int) => x)
    .map((x: int) => x * x)
    .buffer(initInterval(seconds = 1))
    .subscribe(subscriber[seq[int]](println))

  sync()