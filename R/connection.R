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
#' @examplesIf identical(Sys.getenv("REDISRS_EXAMPLES"), "true")
#' con <- redis_connect("redis://localhost:6379")
#' redis_cmd(con, "PING")
#' redis_close(con)
#' @export
redis_connect <- function(url, cluster = FALSE, username = NULL, token_fn = NULL) {
  # The full call can hold a password in `url` or in an inline `token_fn`.
  call <- sys.call()[1L]
  if (!is.character(url) || length(url) != 1L || is.na(url)) {
    stop(usage_error("url must be one string", call))
  }
  if (!is.null(token_fn) && !is.function(token_fn)) {
    stop(usage_error("token_fn must be a function or NULL", call))
  }
  if (!is.null(username) && !is_string(username)) {
    stop(usage_error("username must be one string or NULL", call))
  }
  con <- new.env(parent = emptyenv())
  con$url <- url
  con$cluster <- isTRUE(cluster)
  con$username <- username
  con$token_fn <- token_fn
  con$ptr <- NULL
  con$multi <- FALSE
  con$watch <- FALSE
  class(con) <- "redisrs_connection"
  res <- connect_ptr(con, call)
  if (is_failure(res)) raise_failure(res, call)
  con
}

is_string <- function(x) is.character(x) && length(x) == 1L && !is.na(x)

connect_ptr <- function(con, call = NULL) {
  password <- if (is.null(con$token_fn)) NULL else con$token_fn()
  if (!is.null(con$token_fn) && !is_string(password)) {
    stop(usage_error("token_fn must return one string", call))
  }
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
#' @return `NULL`, invisibly. After the call, `con` is closed, and each
#'   function that uses it gives a `redis_usage_error`.
#' @examplesIf identical(Sys.getenv("REDISRS_EXAMPLES"), "true")
#' con <- redis_connect("redis://localhost:6379")
#' redis_close(con)
#' @export
redis_close <- function(con) {
  if (inherits(con, "redisrs_connection") && !is.null(con$ptr)) {
    con$ptr$close()
    con$ptr <- NULL
  }
  invisible(NULL)
}

# Greedy up to the last @ before the path: a password can contain @.
# Unix socket URLs carry the password as the query parameter `pass`. Its
# name can be percent-encoded, so each name is decoded before the match.
redact_url <- function(url) {
  url <- sub("//[^/?#]*@", "//***@", url)
  m <- gregexpr("[?&][^=&#]*=[^&#]*", url)
  regmatches(url, m) <- lapply(regmatches(url, m), function(params) {
    name <- sub("=.*", "", substring(params, 2L))
    secret <- tolower(vapply(name, utils::URLdecode, "")) == "pass"
    params[secret] <- paste0(substr(params[secret], 1L, 1L), name[secret], "=***")
    params
  })
  url
}

#' @export
print.redisrs_connection <- function(x, ...) {
  state <- if (is.null(x$ptr)) "closed" else "open"
  mode <- if (x$cluster) "cluster" else "single"
  cat("<redisrs_connection> ", redact_url(x$url), " (", mode, ", ", state, ")
", sep = "")
  invisible(x)
}
