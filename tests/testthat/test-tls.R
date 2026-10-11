test_that("TLS connection works with an insecure test certificate", {
  con <- local_con("tls")
  expect_equal(redis_cmd(con, "SET", "k", "v"), "OK")
  expect_equal(redis_cmd(con, "GET", "k"), "v")
})

test_that("TLS with certificate checks rejects the self-signed certificate", {
  skip_if_no_servers()
  expect_error(redis_connect("rediss://127.0.0.1:6380"), class = "redis_connection_error")
})

test_that("plain text to a TLS port fails as a connection error", {
  skip_if_no_servers()
  expect_error(redis_connect("redis://127.0.0.1:6380"), class = "redis_connection_error")
})
