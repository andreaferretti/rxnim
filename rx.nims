task run, "run rx":
  --threads: on
  --run
  switch("out", "rxx")
  setCommand "c", "rx"

task tests, "test rx":
  --threads: on
  --run
  setCommand "c", "test"