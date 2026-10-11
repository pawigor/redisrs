test_url <- function(name) {
  defaults <- c(
    plain = "redis://127.0.0.1:6379",
    auth = "redis://:secret@127.0.0.1:6381",
    tls = "rediss://127.0.0.1:6380/#insecure",
    cluster = "redis://127.0.0.1:7000"
  )
  Sys.getenv(paste0("REDISRS_TEST_", toupper(name)), defaults[[name]])
}

skip_if_no_servers <- function() {
  skip_on_cran()
  if (!identical(Sys.getenv("REDISRS_TEST_SERVERS"), "true")) {
    skip("set REDISRS_TEST_SERVERS=true to run server tests")
  }
}

local_con <- function(name, ..., env = parent.frame()) {
  skip_if_no_servers()
  con <- redis_connect(test_url(name), cluster = identical(name, "cluster"), ...)
  if (!identical(name, "cluster")) redis_cmd(con, "FLUSHALL")
  withr::defer(redis_close(con), envir = env)
  con
}
