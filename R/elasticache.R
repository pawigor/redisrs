has_paws <- function() requireNamespace("paws.common", quietly = TRUE)

iam_token_at <- function(cache_name, user_id, region, serverless, credentials, amz_date) {
  rs_iam_token(
    cache_name, user_id, region,
    credentials$access_key_id, credentials$secret_access_key,
    credentials$session_token, amz_date, isTRUE(serverless)
  )
}

#' Make an ElastiCache IAM token
#'
#' @param cache_name The replication group ID or the serverless cache name.
#'   This is not the endpoint DNS name.
#' @param user_id The ElastiCache user ID. AUTH uses it as the user name.
#' @param region The AWS region, for example `"eu-west-1"`.
#' @param serverless `TRUE` for ElastiCache Serverless.
#' @param credentials A list with `access_key_id`, `secret_access_key` and
#'   `session_token`. If `NULL`, `paws.common::locate_credentials()` finds them.
#' @return A token string, valid for 15 minutes.
#' @examples
#' creds <- list(
#'   access_key_id = "AKIDEXAMPLE",
#'   secret_access_key = "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY",
#'   session_token = ""
#' )
#' elasticache_iam_token("my-cache", "my-user", "us-east-1", credentials = creds)
#' @export
elasticache_iam_token <- function(cache_name, user_id, region, serverless = FALSE,
                                  credentials = NULL) {
  if (is.null(credentials)) {
    if (!has_paws()) {
      stop(usage_error(paste(
        "IAM authentication needs the package 'paws.common'.",
        "Install it with install.packages(\"paws.common\")."
      )))
    }
    credentials <- paws.common::locate_credentials()
  }
  amz_date <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  iam_token_at(cache_name, user_id, region, serverless, credentials, amz_date)
}

#' Connect to AWS ElastiCache or MemoryDB with IAM
#'
#' @param endpoint The DNS name of the cache endpoint.
#' @inheritParams elasticache_iam_token
#' @param port The port. ElastiCache uses 6379 by default.
#' @param cluster `TRUE` for cluster mode. Use `TRUE` for ElastiCache Serverless.
#' @return A connection from [redis_connect()]. A new token is made at each
#'   connect and reconnect.
#' @examplesIf interactive() && nzchar(Sys.getenv("REDISRS_EC_ENDPOINT"))
#' con <- redis_connect_elasticache(
#'   endpoint = Sys.getenv("REDISRS_EC_ENDPOINT"),
#'   cache_name = Sys.getenv("REDISRS_EC_CACHE"),
#'   user_id = Sys.getenv("REDISRS_EC_USER"),
#'   region = Sys.getenv("REDISRS_EC_REGION"),
#'   cluster = TRUE, serverless = TRUE
#' )
#' redis_cmd(con, "PING")
#' redis_close(con)
#' @export
redis_connect_elasticache <- function(endpoint, cache_name, user_id, region, port = 6379,
                                      cluster = FALSE, serverless = FALSE) {
  url <- sprintf("rediss://%s:%d", endpoint, as.integer(port))
  token_fn <- function() elasticache_iam_token(cache_name, user_id, region, serverless)
  redis_connect(url, cluster = cluster, username = user_id, token_fn = token_fn)
}
