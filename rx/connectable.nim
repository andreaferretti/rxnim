import rx/core

type ConnectableObservable*[A] = object
  source: Observable[A]
  listeners: seq[Subscriber[A]]

proc subscribe*[A](o: var ConnectableObservable[A], s: Subscriber[A]) =
  o.listeners.add(s)

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
    onError = proc(e: ref Exception) =
      for l in o.listeners:
        l.onError(e)
  ))
{.pop.}