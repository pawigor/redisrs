test_that("R objects survive a round trip", {
  con <- local_con("plain")
  df <- data.frame(a = 1:3, b = c("x", "y", "z"))
  redis_set_object(con, "df", df)
  expect_identical(redis_get_object(con, "df"), df)
})

test_that("a missing key gives NULL", {
  con <- local_con("plain")
  expect_null(redis_get_object(con, "nope"))
})

test_that("ex sets an expiry", {
  con <- local_con("plain")
  redis_set_object(con, "t", 1, ex = 100)
  ttl <- redis_cmd(con, "TTL", "t")
  expect_true(ttl > 0 && ttl <= 100)
})

test_that("ex must be a positive whole number", {
  con <- local_con("plain")
  expect_error(redis_set_object(con, "t", 1, ex = 0), class = "redis_usage_error")
  expect_error(redis_set_object(con, "t", 1, ex = 1.5), class = "redis_usage_error")
})

test_that("a plain string value is not unserialized by mistake", {
  con <- local_con("plain")
  redis_cmd(con, "SET", "s", "hello")
  expect_error(redis_get_object(con, "s"))
})
