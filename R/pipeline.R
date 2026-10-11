#' Run several commands in one round trip
#'
#' @param con A connection from [redis_connect()].
#' @param cmds A list. Each element is one command as a character vector or a
#'   list, for example `list(c("SET", "a", "1"), list("INCRBY", "a", 5))`.
#' @return A list with one reply per command. A command that failed gives a
#'   `redis_error` condition object in its slot. It is returned, not thrown.
#'   In cluster mode, one failed command can fail the whole pipeline.
#' @details After a connection error, the whole pipeline is sent once more on
#'   a new connection. If the first attempt reached the server, commands such
#'   as `INCR` run twice.
#' @examplesIf identical(Sys.getenv("REDISRS_EXAMPLES"), "true")
#' con <- redis_connect("redis://localhost:6379")
#' redis_pipeline(con, list(c("SET", "n", "1"), c("INCR", "n"), c("GET", "n")))
#' redis_cmd(con, "DEL", "n")
#' redis_close(con)
#' @export
redis_pipeline <- function(con, cmds) {
  call <- sys.call()
  check_con(con, call)
  if (!is.list(cmds)) stop(usage_error("cmds must be a list of commands", call))
  if (length(cmds) == 0L) return(list())
  packed <- lapply(cmds, function(cmd) as_args(as.list(cmd), call))
  run_command(con, function(ptr) ptr$pipeline(packed), call)
}
