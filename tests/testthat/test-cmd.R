test_that("replies convert to R types", {
  con <- local_con("plain")
  expect_equal(redis_cmd(con, "SET", "s", "hé"), "OK")
  expect_equal(redis_cmd(con, "GET", "s"), "hé")
  expect_null(redis_cmd(con, "GET", "missing"))
  expect_identical(redis_cmd(con, "INCRBY", "n", 3e9), 3e9)
  expect_identical(redis_cmd(con, "INCRBYFLOAT", "f", 0.5), "0.5")
  redis_cmd(con, "RPUSH", "l", c("a", "b"))
  expect_equal(redis_cmd(con, "LRANGE", "l", 0, -1), list("a", "b"))
  redis_cmd(con, "HSET", "h", "f1", "v1", "f2", "v2")
  expect_equal(redis_cmd(con, "HGETALL", "h")[c("f1", "f2")], list(f1 = "v1", f2 = "v2"))
})

test_that("binary values with NUL come back as raw", {
  con <- local_con("plain")
  bytes <- as.raw(c(0x58, 0x0a, 0x00, 0x03))
  redis_cmd(con, "SET", "b", bytes)
  expect_identical(redis_cmd(con, "GET", "b"), bytes)
})

test_that("a server error is a redis_error and the connection stays open", {
  con <- local_con("plain")
  redis_cmd(con, "SET", "s", "x")
  err <- tryCatch(redis_cmd(con, "LPUSH", "s", "y"), redis_error = identity)
  expect_s3_class(err, "redis_error")
  expect_equal(err$code, "WRONGTYPE")
  expect_equal(redis_cmd(con, "PING"), "PONG")
})

test_that("mode commands are refused before they reach the server", {
  con <- local_con("plain")
  expect_error(redis_cmd(con, "SUBSCRIBE", "ch"), class = "redis_usage_error")
  expect_equal(redis_cmd(con, "PING"), "PONG")
})
