#' Connect to Redis or Valkey
#'
#' @param url A URL such as `redis://host:6379`, `rediss://host:6380` for TLS,
#'   or `redis+unix:///path/to.sock`. A password in the URL is used for AUTH.
#' @param cluster If `TRUE`, use Redis Cluster mode.
#' @param username User name for AUTH. It replaces the user name in `url`.
#' @param token_fn A function without arguments that returns the password.
#'   It is called at each connect and reconnect, for example to get a fresh
#'   IAM token.
#' @return An object of class `redisrs_connection`.
#' @export
redis_connect <- function(url, cluster = FALSE, username = NULL, token_fn = NULL) {
  call <- sys.call()
  if (!is.character(url) || length(url) != 1L || is.na(url)) {
    stop(usage_error("url must be one string", call))
  }
  if (!is.null(token_fn) && !is.function(token_fn)) {
    stop(usage_error("token_fn must be a function or NULL", call))
  }
  con <- new.env(parent = emptyenv())
  con$url <- url
  con$cluster <- isTRUE(cluster)
  con$username <- username
  con$token_fn <- token_fn
  con$ptr <- NULL
  class(con) <- "redisrs_connection"
  res <- connect_ptr(con)
  if (is_failure(res)) raise_failure(res, call)
  con
}

connect_ptr <- function(con) {
  password <- if (is.null(con$token_fn)) NULL else con$token_fn()
  res <- rs_connect(con$url, con$cluster, con$username, password)
  if (!is_failure(res)) con$ptr <- res
  res
}

check_con <- function(con, call = NULL) {
  if (!inherits(con, "redisrs_connection")) {
    stop(usage_error("con must be a redisrs_connection", call))
  }
  if (is.null(con$ptr)) stop(usage_error("connection is closed", call))
  invisible(con)
}

#' Close a connection
#' @param con A connection from [redis_connect()].
#' @export
redis_close <- function(con) {
  if (inherits(con, "redisrs_connection") && !is.null(con$ptr)) {
    con$ptr$close()
    con$ptr <- NULL
  }
  invisible(NULL)
}

redact_url <- function(url) sub("//[^@/]*@", "//***@", url)

#' @export
print.redisrs_connection <- function(x, ...) {
  state <- if (is.null(x$ptr)) "closed" else "open"
  mode <- if (x$cluster) "cluster" else "single"
  cat("<redisrs_connection> ", redact_url(x$url), " (", mode, ", ", state, ")
", sep = "")
  invisible(x)
}
