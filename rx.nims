task run, "run rx":
  --threads: on
  --run
  setCommand "c", "rx"

task tests, "test rx":
  --threads: on
  --run
  setCommand "c", "test"