#' Store and read R objects
#'
#' `redis_set_object()` stores `serialize(value)`. `redis_get_object()` reads
#' the bytes and calls `unserialize()`. Only read keys that you wrote with
#' `redis_set_object()`: `unserialize()` on untrusted data is not safe.
#'
#' @param con A connection from [redis_connect()].
#' @param key The key.
#' @param value Any R object.
#' @param ex Expiry in seconds, or `NULL` for no expiry.
#' @export
redis_set_object <- function(con, key, value, ex = NULL) {
  bytes <- serialize(value, NULL, xdr = TRUE)
  if (is.null(ex)) {
    redis_cmd(con, "SET", key, bytes)
  } else {
    if (!is.numeric(ex) || length(ex) != 1L || is.na(ex) || ex < 1 || ex != trunc(ex)) {
      stop(usage_error("ex must be a positive whole number of seconds"))
    }
    redis_cmd(con, "SET", key, bytes, "EX", ex)
  }
  invisible(NULL)
}

#' @rdname redis_set_object
#' @export
redis_get_object <- function(con, key) {
  bytes <- redis_cmd_raw(con, "GET", key)
  if (is.null(bytes)) NULL else unserialize(bytes)
}
