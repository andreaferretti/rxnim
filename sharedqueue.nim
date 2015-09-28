type
  SharedCons[A] = object
    elem: A
    next: SharedQueue[A]
  SharedQueue*[A] = ptr SharedCons[A]

proc newShared[A]: ptr A =
  cast[ptr A](allocShared(sizeof(A)))

proc newSharedQueue[A]: SharedQueue[A] = nil

proc append[A](s: SharedQueue[A], a: A): SharedQueue[A] =
  result = newShared[SharedCons[A]]()
  result.next = s
  result.elem = a

iterator items*[A](s: SharedQueue[A]): A {.inline.} =
  var t = s
  while not t.isNil:
    yield t.elem
    t = t.next

proc atomicSend*[A](s: var SharedQueue[A], a: A) =
  let s1 = s.append(a)
  s = s1

proc localItems*[A](s: SharedQueue[A]): seq[A] =
  result = @[]
  for t in s:
    result.add(t)

when isMainModule:
  import threadpool

  proc localEcho[A](z: SharedQueue[A]) =
    let y = localItems(z)
    echo y

  var x = newSharedQueue[int]()
  x.atomicSend(1)
  x.atomicSend(2)
  x.atomicSend(3)

  spawn:
    localEcho(x)

  sync()