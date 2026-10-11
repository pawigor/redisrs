test_that("raise_failure maps each kind to its class", {
  f <- function(kind) structure(list(kind = kind, code = "X", message = "boom"), class = "redisrs_failure")
  expect_error(raise_failure(f("server")), class = "redis_error")
  expect_error(raise_failure(f("connection")), class = "redis_connection_error")
  expect_error(raise_failure(f("auth")), class = "redis_auth_error")
  expect_error(raise_failure(f("usage")), class = "redis_usage_error")
  expect_error(raise_failure(f("auth")), class = "redisrs_error")
})

test_that("conditions keep the code and message", {
  cnd <- redisrs_condition("redis_error", "WRONGTYPE bad", code = "WRONGTYPE")
  expect_s3_class(cnd, c("redis_error", "redisrs_error", "error", "condition"), exact = TRUE)
  expect_equal(cnd$code, "WRONGTYPE")
  expect_equal(conditionMessage(cnd), "WRONGTYPE bad")
})

test_that("is_failure only accepts failure lists", {
  expect_true(is_failure(structure(list(), class = "redisrs_failure")))
  expect_false(is_failure(list(kind = "server")))
  expect_false(is_failure("OK"))
})
