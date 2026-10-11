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
