test_that("an invalid URL is a usage error without network", {
  expect_error(redis_connect("http://example.com"), class = "redis_usage_error")
})

test_that("a refused connection is a connection error", {
  skip_on_cran()
  expect_error(redis_connect("redis://127.0.0.1:1"), class = "redis_connection_error")
})

test_that("connect, ping and close", {
  con <- local_con("plain")
  expect_s3_class(con, "redisrs_connection")
  expect_equal(redis_cmd(con, "PING"), "PONG")
  redis_close(con)
  expect_error(redis_cmd(con, "PING"), class = "redis_usage_error")
})

test_that("print hides the password", {
  con <- local_con("auth")
  out <- capture.output(print(con))
  expect_false(any(grepl("secret", out)))
  expect_true(any(grepl("6381", out)))
})

test_that("a wrong password is an auth error", {
  skip_if_no_servers()
  expect_error(redis_connect("redis://:wrong@127.0.0.1:6381"), class = "redis_auth_error")
})

test_that("username and token_fn supply credentials", {
  skip_if_no_servers()
  c2 <- redis_connect("redis://127.0.0.1:6381", username = "default", token_fn = function() "secret")
  on.exit(redis_close(c2))
  expect_equal(redis_cmd(c2, "PING"), "PONG")
})

test_that("redact_url hides a password that contains @", {
  expect_equal(redact_url("redis://user:p@ss@h:6379/0"), "redis://***@h:6379/0")
  expect_equal(redact_url("rediss://:secret@h:6380"), "rediss://***@h:6380")
  expect_equal(redact_url("redis://h:6379"), "redis://h:6379")
})

test_that("redact_url hides a password in a Unix socket URL", {
  expect_equal(
    redact_url("redis+unix:///tmp/r.sock?db=1&user=u&pass=s3cret"),
    "redis+unix:///tmp/r.sock?db=1&user=u&pass=***"
  )
  expect_equal(redact_url("unix:///tmp/r.sock?pass=a&db=2"), "unix:///tmp/r.sock?pass=***&db=2")
})

test_that("an error call does not show the password or token_fn", {
  err <- tryCatch(
    redis_connect("http://:secret@example.com", token_fn = function() "s3cret"),
    error = identity
  )
  expect_s3_class(err, "redis_usage_error")
  shown <- paste(deparse(conditionCall(err)), collapse = "")
  expect_false(grepl("secret", shown))
  expect_false(grepl("s3cret", shown))
})

test_that("a refused connection does not show the password", {
  skip_on_cran()
  err <- tryCatch(redis_connect("redis://:secret@127.0.0.1:1"), error = identity)
  expect_s3_class(err, "redis_connection_error")
  expect_false(grepl("secret", paste(deparse(conditionCall(err)), collapse = "")))
})

test_that("username and the token_fn result must be one string", {
  expect_error(redis_connect("redis://127.0.0.1:1", username = 1), class = "redis_usage_error")
  expect_error(redis_connect("redis://127.0.0.1:1", username = NA_character_), class = "redis_usage_error")
  expect_error(redis_connect("redis://127.0.0.1:1", token_fn = function() 123), class = "redis_usage_error")
  expect_error(redis_connect("redis://127.0.0.1:1", token_fn = function() c("a", "b")), class = "redis_usage_error")
  expect_error(redis_connect("redis://:old@127.0.0.1:1", token_fn = function() NULL), class = "redis_usage_error")
})

test_that("redact_url hides a percent-encoded pass parameter", {
  expect_equal(redact_url("redis+unix:///tmp/r.sock?%70ass=secret"), "redis+unix:///tmp/r.sock?%70ass=***")
  expect_equal(redact_url("unix:///tmp/r.sock?db=1&PA%53S=x"), "unix:///tmp/r.sock?db=1&PA%53S=***")
})
