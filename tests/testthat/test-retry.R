kill_client <- function(con) {
  id <- redis_cmd(con, "CLIENT", "ID")
  other <- redis_connect(con$url, username = con$username, token_fn = con$token_fn)
  on.exit(redis_close(other))
  redis_cmd(other, "CLIENT", "KILL", "ID", id)
}

test_that("a dropped connection reconnects once", {
  con <- local_con("plain")
  kill_client(con)
  expect_equal(redis_cmd(con, "PING"), "PONG")
})

test_that("token_fn is called again on reconnect", {
  skip_if_no_servers()
  calls <- 0
  con <- redis_connect("redis://127.0.0.1:6381", username = "default",
                       token_fn = function() { calls <<- calls + 1; "secret" })
  on.exit(redis_close(con))
  expect_equal(calls, 1)
  kill_client(con)
  expect_equal(redis_cmd(con, "PING"), "PONG")
  expect_equal(calls, 3) # one for the first connect, one in kill_client, one for the reconnect
})

test_that("should_retry rules", {
  con <- new.env()
  con$token_fn <- NULL
  f <- function(kind) list(kind = kind)
  expect_true(should_retry(con, f("connection")))
  expect_false(should_retry(con, f("auth")))
  expect_false(should_retry(con, f("server")))
  expect_false(should_retry(con, f("usage")))
  con$token_fn <- function() "x"
  expect_true(should_retry(con, f("auth")))
})
