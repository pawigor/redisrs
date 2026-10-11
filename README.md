# redisrs

redisrs is a Redis and Valkey client for R. It uses the Rust crate `redis-rs`. It supports TLS, Redis Cluster, pipelines, and IAM authentication for AWS ElastiCache and MemoryDB.

## Installation

You need Rust 1.88 or newer (`rustc` and `cargo`). Install it from https://rustup.rs.

```r
remotes::install_github("<owner>/redisrs")
```

## Usage

```r
library(redisrs)
con <- redis_connect("redis://localhost:6379")
redis_cmd(con, "SET", "greeting", "hello")
redis_cmd(con, "GET", "greeting")
redis_pipeline(con, list(c("INCR", "n"), c("INCR", "n")))
redis_set_object(con, "model", lm(mpg ~ wt, mtcars), ex = 3600)
redis_close(con)
```

## TLS

Use a `rediss://` URL for TLS. The client trusts the certificate authorities in the system certificate store. For a test server with a self-signed certificate, add `#insecure` to the URL, for example `rediss://localhost:6380/#insecure`. This turns off the certificate check, so do not use it in production.

Host names in URLs must be ASCII. The client does not convert international domain names.

## AWS ElastiCache with IAM

Install `paws.common` for IAM authentication. It finds your AWS credentials.

```r
con <- redis_connect_elasticache(
  endpoint = "my-cache-abc123.serverless.euw1.cache.amazonaws.com",
  cache_name = "my-cache",
  user_id = "app-user",
  region = "eu-west-1",
  cluster = TRUE,
  serverless = TRUE
)
```

The client makes a new token at each connect and reconnect.

## Errors

Each error has one of these classes: `redis_error`, `redis_connection_error`, `redis_auth_error`, `redis_usage_error`. All of them also have the class `redisrs_error`.

## Limits

Version 1 has no Pub/Sub, Streams helpers, Sentinel, or asynchronous mode. Stream commands work through `redis_cmd()`.

## Development

If you change `src/rust/Cargo.toml` or `src/rust/Cargo.lock`, run `Rscript tools/vendor-crates.R` from the package root. The script rebuilds `src/rust/vendor.tar.xz`, which CRAN needs for an offline build.

The integration tests need Docker. See `tests/servers/README.md`.
