#' Run one Redis command
#'
#' @param con A connection from [redis_connect()].
#' @param ... The command and its arguments. Each argument can be a character,
#'   numeric, logical or raw vector. A vector of length > 1 becomes several
#'   arguments. A raw vector is one argument.
#' @return The reply as an R value. Integers are doubles. Maps are named lists.
#'   Strings with invalid UTF-8 or NUL bytes are raw vectors.
#' @details `SUBSCRIBE`, `PSUBSCRIBE`, `SSUBSCRIBE`, `MONITOR`, the
#'   `UNSUBSCRIBE` commands, `CLIENT REPLY` and `SELECT` are refused. Put the
#'   database number in the URL instead of `SELECT`.
#'
#'   After a connection error the command is sent once more on a new
#'   connection. If the first attempt reached the server, a command such as
#'   `INCR` runs twice. Between `MULTI` or `WATCH` and `EXEC`, `DISCARD` or
#'   `UNWATCH`, there is no second attempt, because the new connection does
#'   not have the transaction.
#' @examplesIf identical(Sys.getenv("REDISRS_EXAMPLES"), "true")
#' con <- redis_connect("redis://localhost:6379")
#' redis_cmd(con, "SET", "greeting", "hello")
#' redis_cmd(con, "GET", "greeting")
#' redis_cmd(con, "DEL", "greeting")
#' redis_close(con)
#' @export
redis_cmd <- function(con, ...) {
  call <- sys.call()
  check_con(con, call)
  args <- as_args(list(...), call)
  run_command(con, function(ptr) ptr$cmd(args, FALSE), call, list(args))
}

redis_cmd_raw <- function(con, ...) {
  call <- sys.call()
  check_con(con, call)
  args <- as_args(list(...), call)
  run_command(con, function(ptr) ptr$cmd(args, TRUE), call, list(args))
}

# A connection inside MULTI or WATCH holds state that a reconnect loses.
# Inside MULTI, Redis only queues commands, so only EXEC, DISCARD and RESET
# change the state there. A rejected EXEC (wrong arguments, ACL) leaves MULTI
# open, but EXECABORT ends it.
track_tx <- function(con, args, ok, code = "") {
  name <- command_name(args)
  ends <- (ok && name %in% c("EXEC", "DISCARD", "RESET")) ||
    (name == "EXEC" && identical(code, "EXECABORT"))
  if (ends) {
    con$multi <- FALSE
    con$watch <- FALSE
  } else if (ok && !isTRUE(con$multi)) {
    if (name == "MULTI") con$multi <- TRUE
    if (name == "WATCH") con$watch <- TRUE
    if (name == "UNWATCH") con$watch <- FALSE
  }
}

in_tx <- function(con) isTRUE(con$multi) || isTRUE(con$watch)

# A command list with MULTI or WATCH is not sent twice: the first attempt can
# open the transaction before the connection fails.
should_retry <- function(con, res, cmds = list()) {
  if (in_tx(con)) return(FALSE)
  if (any(vapply(cmds, command_name, "") %in% c("MULTI", "WATCH"))) return(FALSE)
  identical(res$kind, "connection") ||
    (identical(res$kind, "auth") && !is.null(con$token_fn))
}

# `cmds` is the list of commands that `f` sends. With `pipeline = TRUE`, the
# result is one reply per command, and a failed command is a condition.
run_command <- function(con, f, call, cmds, pipeline = FALSE) {
  res <- f(con$ptr)
  if (is_failure(res) && in_tx(con) && identical(res$kind, "connection")) {
    # The transaction is gone. The next command can reconnect.
    con$multi <- FALSE
    con$watch <- FALSE
    raise_failure(res, call)
  }
  if (is_failure(res) && should_retry(con, res, cmds)) {
    again <- connect_ptr(con, call)
    if (is_failure(again)) raise_failure(again, call)
    res <- f(con$ptr)
  }
  if (!pipeline && (!is_failure(res) || identical(res$kind, "server"))) {
    track_tx(con, cmds[[1L]], !is_failure(res), if (is_failure(res)) res$code else "")
  }
  if (pipeline && !is_failure(res)) {
    for (i in seq_along(cmds)) {
      failed <- inherits(res[[i]], "condition")
      track_tx(con, cmds[[i]], !failed, if (failed) res[[i]]$code else "")
    }
  }
  if (is_failure(res)) raise_failure(res, call)
  res
}
