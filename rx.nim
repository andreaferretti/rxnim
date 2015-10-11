import threadpool, times
import rx/schedulers, rx/core, rx/ops, rx/connectable

export schedulers, core, ops, connectable



proc println[A](a: A) = echo(a)

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