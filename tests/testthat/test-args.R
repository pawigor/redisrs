chr <- function(x) vapply(x, rawToChar, "")

test_that("character, integer, logical and raw are encoded", {
  out <- as_args(list("SET", "k", 5L, TRUE, as.raw(c(0, 1))))
  expect_equal(chr(out[1:4]), c("SET", "k", "5", "1"))
  expect_identical(out[[5]], as.raw(c(0, 1)))
})

test_that("doubles never use scientific notation for whole numbers", {
  expect_equal(chr(as_args(list("X", 1e6, 3e9, 2^53)))[-1], c("1000000", "3000000000", "9007199254740992"))
  expect_equal(chr(as_args(list("X", 0.5)))[-1], "0.5")
  expect_equal(chr(as_args(list("X", -Inf)))[-1], "-inf")
})

test_that("vectors expand into several arguments", {
  expect_equal(chr(as_args(list("DEL", c("a", "b", "c")))), c("DEL", "a", "b", "c"))
})

test_that("UTF-8 is sent as UTF-8 bytes", {
  out <- as_args(list("SET", "k", "hé"))
  expect_identical(out[[3]], as.raw(c(0x68, 0xc3, 0xa9)))
})

test_that("bad arguments are usage errors", {
  expect_error(as_args(list()), class = "redis_usage_error")
  expect_error(as_args(list("SET", NA)), class = "redis_usage_error")
  expect_error(as_args(list("SET", NULL)), class = "redis_usage_error")
  expect_error(as_args(list("SET", character())), class = "redis_usage_error")
  expect_error(as_args(list("SET", list(1))), class = "redis_usage_error")
})

test_that("mode commands are refused in any case", {
  for (cmd in c("SUBSCRIBE", "psubscribe", "SSubscribe", "monitor")) {
    expect_error(as_args(list(cmd, "ch")), class = "redis_usage_error")
  }
})

test_that("commands without a normal reply are refused", {
  for (cmd in list("UNSUBSCRIBE", "punsubscribe", "SUnsubscribe", c("client", "reply", "off"), c("CLIENT", "REPLY", "SKIP"))) {
    expect_error(as_args(as.list(cmd)), class = "redis_usage_error")
  }
  expect_length(as_args(list("CLIENT", "INFO")), 2)
})

test_that("SELECT is refused because a reconnect would lose it", {
  expect_error(as_args(list("select", 1L)), class = "redis_usage_error")
})

test_that("command names use ASCII case rules in any locale", {
  skip_on_cran()
  all <- tryCatch(system("locale -a", intern = TRUE, ignore.stderr = TRUE), error = function(e) character())
  tr <- grep("^tr_TR\\.utf-?8$", all, ignore.case = TRUE, value = TRUE)
  skip_if(length(tr) == 0L, "no Turkish locale")
  withr::local_locale(LC_CTYPE = tr[[1L]])
  expect_equal(command_name(list(charToRaw("multi"))), "MULTI")
  expect_error(as_args(list("unsubscribe")), class = "redis_usage_error")
})
