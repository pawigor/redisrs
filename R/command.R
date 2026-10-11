#' Run one Redis command
#'
#' @param con A connection from [redis_connect()].
#' @param ... The command and its arguments. Each argument can be a character,
#'   numeric, logical or raw vector. A vector of length > 1 becomes several
#'   arguments. A raw vector is one argument.
#' @return The reply as an R value. Integers are doubles. Maps are named lists.
#'   Strings with invalid UTF-8 or NUL bytes are raw vectors.
#' @details `SUBSCRIBE`, `PSUBSCRIBE`, `SSUBSCRIBE` and `MONITOR` are refused.
#'   After a connection error the command is sent once more on a new
#'   connection. If the first attempt reached the server, a command such as
#'   `INCR` runs twice.
#' @export
redis_cmd <- function(con, ...) {
  call <- sys.call()
  check_con(con, call)
  args <- as_args(list(...), call)
  run_command(con, function(ptr) ptr$cmd(args, FALSE), call)
}

redis_cmd_raw <- function(con, ...) {
  call <- sys.call()
  check_con(con, call)
  args <- as_args(list(...), call)
  run_command(con, function(ptr) ptr$cmd(args, TRUE), call)
}

should_retry <- function(con, res) {
  identical(res$kind, "connection") ||
    (identical(res$kind, "auth") && !is.null(con$token_fn))
}

run_command <- function(con, f, call) {
  res <- f(con$ptr)
  if (is_failure(res) && should_retry(con, res)) {
    again <- connect_ptr(con)
    if (is_failure(again)) raise_failure(again, call)
    res <- f(con$ptr)
  }
  if (is_failure(res)) raise_failure(res, call)
  res
}
