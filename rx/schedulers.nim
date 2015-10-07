import os, times

type Scheduler* = object
  scheduleNow: proc(p: proc())
  scheduleLater: proc(p: proc(), t: TimeInterval)
  now*: proc(): Time

template millis(t: TimeInterval): auto =
  t.milliseconds + 1000 * t.seconds # fix me

template schedule*(s: Scheduler, p: expr) =
  s.scheduleNow(p)

template schedule*(s: Scheduler, p, t: expr) =
  s.scheduleLater(p, t)

proc immediateScheduler*(): Scheduler =
  result.scheduleNow = proc(p: proc()) = p()
  result.scheduleLater = proc(p: proc(), t: TimeInterval) =
    sleep(t.millis)
    p()
  result.now = proc(): Time =
    epochTime().fromSeconds()