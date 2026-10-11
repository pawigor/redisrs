# Manual test against a real ElastiCache cache. CI does not run it.
# You need: an ElastiCache user with IAM auth, AWS credentials for a role that
# has elasticache:Connect, and network access to the endpoint (for example, run
# this on an EC2 host in the same VPC).
#
# Usage:
#   REDISRS_EC_ENDPOINT=... REDISRS_EC_CACHE=... REDISRS_EC_USER=... \
#   REDISRS_EC_REGION=... REDISRS_EC_SERVERLESS=true Rscript inst/manual/aws-smoke-test.R
library(redisrs)
env <- function(x) Sys.getenv(paste0("REDISRS_EC_", x))
serverless <- identical(env("SERVERLESS"), "true")
con <- redis_connect_elasticache(
  endpoint = env("ENDPOINT"), cache_name = env("CACHE"), user_id = env("USER"),
  region = env("REGION"), cluster = serverless, serverless = serverless
)
print(con)
stopifnot(identical(redis_cmd(con, "PING"), "PONG"))
redis_cmd(con, "SET", "redisrs-smoke", "ok", "EX", 60)
stopifnot(identical(redis_cmd(con, "GET", "redisrs-smoke"), "ok"))
redis_close(con)
cat("ElastiCache smoke test passed
")
