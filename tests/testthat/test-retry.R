kill_client <- function(con, id = redis_cmd(con, "CLIENT", "ID")) {
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

test_that("should_retry is FALSE inside MULTI or WATCH", {
  con <- new.env()
  con$token_fn <- NULL
  con$multi <- TRUE
  expect_false(should_retry(con, list(kind = "connection")))
  con$multi <- FALSE
  con$watch <- TRUE
  expect_false(should_retry(con, list(kind = "connection")))
})

test_that("track_tx follows MULTI and WATCH as Redis does", {
  con <- new.env()
  con$multi <- FALSE
  con$watch <- FALSE
  step <- function(..., ok = TRUE, code = "") track_tx(con, as_args(list(...)), ok, code)
  step("WATCH", "k")
  expect_true(con$watch)
  step("MULTI")
  step("UNWATCH") # queued inside MULTI: it does not end anything yet
  expect_true(con$multi)
  expect_true(con$watch)
  step("EXEC", "extra", ok = FALSE, code = "ERR") # rejected: MULTI is still open
  step("DISCARD", "extra", ok = FALSE, code = "ERR")
  expect_true(con$multi)
  step("EXEC", ok = FALSE, code = "EXECABORT") # this ends the transaction
  expect_false(con$multi)
  expect_false(con$watch)
  step("MULTI", ok = FALSE)
  expect_false(con$multi)
  step("WATCH", "k")
  step("UNWATCH")
  expect_false(con$watch)
  step("MULTI")
  step("RESET")
  expect_false(con$multi)
})

test_that("a pipeline with MULTI or WATCH is not sent twice", {
  con <- new.env()
  con$token_fn <- NULL
  res <- list(kind = "connection")
  expect_false(should_retry(con, res, list(as_args(list("WATCH", "k")), as_args(list("GET", "k")))))
  expect_false(should_retry(con, res, list(as_args(list("multi")))))
  expect_true(should_retry(con, res, list(as_args(list("GET", "k")))))
})

test_that("MULTI sent in a pipeline also stops the retry", {
  con <- local_con("plain")
  id <- redis_cmd(con, "CLIENT", "ID")
  redis_pipeline(con, list("MULTI"))
  kill_client(con, id)
  expect_error(redis_cmd(con, "SET", "k", "v"), class = "redis_connection_error")
  expect_equal(redis_cmd(con, "PING"), "PONG")
  expect_null(redis_cmd(con, "GET", "k"))
})

test_that("EXECABORT ends the transaction, so the retry works again", {
  con <- local_con("plain")
  redis_cmd(con, "MULTI")
  expect_error(redis_cmd(con, "SET", "k"), class = "redis_error")
  expect_error(redis_cmd(con, "EXEC"), class = "redis_error")
  kill_client(con)
  expect_equal(redis_cmd(con, "PING"), "PONG")
})

test_that("a dropped connection inside MULTI is not retried", {
  con <- local_con("plain")
  id <- redis_cmd(con, "CLIENT", "ID") # inside MULTI it would be queued
  redis_cmd(con, "MULTI")
  kill_client(con, id)
  expect_error(redis_cmd(con, "SET", "k", "v"), class = "redis_connection_error")
  expect_equal(redis_cmd(con, "PING"), "PONG")
  expect_null(redis_cmd(con, "GET", "k"))
})
