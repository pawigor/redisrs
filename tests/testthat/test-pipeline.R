test_that("a pipeline returns one reply per command", {
  con <- local_con("plain")
  out <- redis_pipeline(con, list(c("SET", "a", "1"), list("INCRBY", "a", 5), c("GET", "a")))
  expect_equal(out, list("OK", 6, "6"))
})

test_that("an empty pipeline returns an empty list", {
  con <- local_con("plain")
  expect_equal(redis_pipeline(con, list()), list())
})

test_that("a failed command does not hide the other replies", {
  con <- local_con("plain")
  redis_cmd(con, "SET", "s", "x")
  out <- redis_pipeline(con, list(c("LPUSH", "s", "y"), c("GET", "s")))
  expect_s3_class(out[[1]], "redis_error")
  expect_equal(out[[2]], "x")
})

test_that("mode commands are refused in a pipeline", {
  con <- local_con("plain")
  expect_error(redis_pipeline(con, list(c("PING"), c("MONITOR"))), class = "redis_usage_error")
})

test_that("cmds must be a list", {
  con <- local_con("plain")
  expect_error(redis_pipeline(con, c("PING")), class = "redis_usage_error")
})
