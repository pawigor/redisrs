mode_commands <- c("SUBSCRIBE", "PSUBSCRIBE", "SSUBSCRIBE", "MONITOR")

format_number <- function(x) {
  whole <- is.finite(x) & x == trunc(x) & abs(x) <= 2^53
  # 15 significant digits when they round-trip, else 17, which always does.
  out <- sprintf("%.15g", x)
  inexact <- as.numeric(out) != x
  out[inexact] <- sprintf("%.17g", x[inexact])
  out[whole] <- formatC(x[whole], format = "f", digits = 0)
  out[is.infinite(x)] <- ifelse(x[is.infinite(x)] > 0, "inf", "-inf")
  out
}

as_args <- function(dots, call = NULL) {
  if (length(dots) == 0L) stop(usage_error("no command given", call))
  out <- list()
  for (x in dots) {
    if (is.raw(x)) {
      out[[length(out) + 1L]] <- x
      next
    }
    if (length(x) == 0L) stop(usage_error("empty or NULL argument", call))
    if (!is.atomic(x)) stop(usage_error("arguments must be character, numeric, logical or raw", call))
    if (anyNA(x)) stop(usage_error("NA is not a valid Redis argument", call))
    s <- if (is.character(x)) {
      enc2utf8(x)
    } else if (is.logical(x)) {
      ifelse(x, "1", "0")
    } else if (is.integer(x)) {
      as.character(x)
    } else if (is.numeric(x)) {
      format_number(x)
    } else {
      stop(usage_error("arguments must be character, numeric, logical or raw", call))
    }
    for (el in s) out[[length(out) + 1L]] <- charToRaw(el)
  }
  name <- tryCatch(toupper(rawToChar(out[[1L]])), error = function(e) "")
  if (name %in% mode_commands) {
    stop(usage_error(paste0(name, " changes the connection mode and is not supported by redis_cmd()"), call))
  }
  out
}
