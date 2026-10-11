redisrs_condition <- function(class, message, code = NA_character_, call = NULL) {
  structure(
    class = c(class, "redisrs_error", "error", "condition"),
    list(message = message, call = call, code = code)
  )
}

usage_error <- function(message, call = NULL) {
  redisrs_condition("redis_usage_error", message, call = call)
}

failure_classes <- c(
  server = "redis_error",
  connection = "redis_connection_error",
  auth = "redis_auth_error",
  usage = "redis_usage_error"
)

is_failure <- function(x) inherits(x, "redisrs_failure")

raise_failure <- function(x, call = NULL) {
  stop(redisrs_condition(failure_classes[[x$kind]], x$message, x$code, call))
}
