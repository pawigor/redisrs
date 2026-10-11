test_that("keys on different slots work in cluster mode", {
  con <- local_con("cluster")
  keys <- paste0("key-", 1:20)
  for (k in keys) redis_cmd(con, "SET", k, k)
  got <- vapply(keys, function(k) redis_cmd(con, "GET", k), "")
  expect_equal(unname(got), keys)
  for (k in keys) redis_cmd(con, "DEL", k)
})

test_that("a pipeline works across slots in cluster mode", {
  con <- local_con("cluster")
  out <- redis_pipeline(con, list(c("SET", "pa", "1"), c("SET", "pb", "2"), c("GET", "pa"), c("GET", "pb")))
  expect_equal(out[3:4], list("1", "2"))
  redis_pipeline(con, list(c("DEL", "pa"), c("DEL", "pb")))
})

test_that("cluster mode also refuses mode commands", {
  con <- local_con("cluster")
  expect_error(redis_cmd(con, "SSUBSCRIBE", "ch"), class = "redis_usage_error")
})
