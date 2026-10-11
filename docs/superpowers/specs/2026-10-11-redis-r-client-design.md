# redisrs: a Redis and Valkey client for R

Date: 2026-10-11
Status: draft for review
Working package name: `redisrs`

## Goal

`redisrs` is an R package that connects R to Redis and Valkey. It works with AWS managed services (ElastiCache, ElastiCache Serverless, MemoryDB) without workarounds. The package wraps the Rust crate `redis-rs` through extendr. We do not write a Redis protocol implementation.

The package goes to GitHub first. The final target is CRAN.

## Why this package

R has two Redis clients on CRAN. Neither one works well with AWS.

- `redux` covers all Redis commands, but it has no TLS support. An SSL pull request is open and not merged. It has no Redis Cluster support. The last push was in September 2025.
- `RcppRedis` is active, but its authors say that it covers only a subset of the Redis API.

AWS ElastiCache Serverless and MemoryDB require TLS. Cluster mode is common on AWS. Today an R user cannot connect to these services in a normal way.

The name `rredis` is not available. CRAN has an archived package with that name.

## Decisions

These decisions come from the brainstorming session.

- The core is `redis-rs`, called from R through extendr. We do not use `hiredis` or a new protocol implementation.
- The API is our own and is not compatible with `redux`. Users get full freedom through one generic command function. Convenience functions sit on top for AWS use.
- AWS credentials come from the R package `paws.common`. The token signature is made in Rust with the crate `aws-sigv4`. We do not use the full AWS SDK for Rust.
- TLS uses `rustls`, not `native-tls`. This removes the dependency on the system OpenSSL.

## Scope

### Version 1 includes

- Connection by URL: `redis://`, `rediss://` (TLS), and Unix sockets.
- Password authentication (AUTH and ACL user with password).
- IAM authentication for ElastiCache and MemoryDB.
- Redis Cluster mode. The client sends each key to the correct node.
- A generic command function that accepts any Redis command.
- Pipelines: many commands in one network round trip.
- Helpers that store and read R objects with `serialize()` and `unserialize()`.
- Automatic reconnection with one retry after a network failure.

### Version 1 excludes

These features come later. They use the same core.

- Pub/Sub.
- Streams with consumer groups.
- Sentinel.
- Asynchronous mode.
- A `redux`-compatible API.

## Architecture

The package has three layers.

### Layer 1: Rust core

Location: `src/rust/`.

The Rust core has these jobs:

- It holds one connection object. The object is a plain `redis-rs` connection or a cluster connection.
- It runs one command or a pipeline.
- It converts Redis replies into R values.
- It converts Rust errors into R conditions.
- It signs IAM tokens with `aws-sigv4`.

The connection object goes to R as an external pointer. When the garbage collector removes the pointer, R frees the connection. A call to `redis_close()` also frees it.

### Layer 2: R base functions

These functions are thin R wrappers around the Rust core.

| Function | Purpose |
|---|---|
| `redis_connect(url, ..., cluster = FALSE, token_fn = NULL)` | Open a connection. |
| `redis_cmd(con, ...)` | Run one command, for example `redis_cmd(con, "SET", "k", "v")`. |
| `redis_pipeline(con, cmds)` | Run a list of commands in one round trip. Return a list of replies. |
| `redis_close(con)` | Close the connection. |

`token_fn` is an R function without arguments. It returns a password string. The Rust core calls it at each connect and reconnect. If `token_fn` is `NULL`, the client uses the password from the URL.

### Layer 3: R convenience functions

| Function | Purpose |
|---|---|
| `redis_connect_elasticache(host, port, user, region, cluster, iam = TRUE)` | Build the URL, turn on TLS, and set `token_fn` to an IAM token generator. |
| `elasticache_iam_token(host, user, region, credentials = NULL)` | Return a fresh IAM token. If `credentials` is `NULL`, credentials come from `paws.common::locate_credentials()`. |
| `redis_set_object(con, key, value, ex = NULL)` | Serialize an R object and store it. `ex` is the expiry in seconds. |
| `redis_get_object(con, key)` | Read and unserialize an R object. If the key does not exist, return `NULL`. |

`paws.common` is in `Suggests`. If the user calls an IAM function and `paws.common` is not installed, the package stops with a clear error message.

## IAM authentication

An IAM token is a presigned SigV4 request to the ElastiCache service. The token is valid for 15 minutes. AWS closes a connection that uses an IAM token after 12 hours.

The flow is:

1. R calls `paws.common::locate_credentials()`. This reads environment variables, `~/.aws` profiles, EC2 and ECS roles, and SSO.
2. R passes the access key, secret key, session token, region, host, and user to the Rust core.
3. The Rust core builds the presigned request with `aws-sigv4` and returns the token string.
4. The Rust core uses the token as the password for AUTH.

The Rust core calls `token_fn` at each connect and reconnect. Thus a reconnect after 12 hours gets a new token.

The R callback is safe because the synchronous `redis-rs` API runs on the main R thread. An asynchronous mode will need a different design. That is one reason why version 1 excludes it.

## Reply conversion

| Redis reply | R value |
|---|---|
| Simple string, bulk string (valid UTF-8) | `character` of length 1 |
| Bulk string (binary data) | `raw` vector |
| Integer | `numeric` (R `integer` has only 32 bits) |
| Double (RESP3) | `numeric` |
| Boolean (RESP3) | `logical` |
| Nil | `NULL` |
| Array, set | `list` |
| Map (RESP3) | named `list` |
| Error | R condition of class `redis_error` |

Arguments to `redis_cmd()` can be `character`, `numeric`, `integer`, `logical`, or `raw`. The R layer converts each argument to bytes. A `raw` argument goes to Redis without change.

## Errors

Each error is an R condition with a class. The user can catch each class with `tryCatch()`.

| Class | Cause | Behavior |
|---|---|---|
| `redis_error` | The server replies with an error, for example a wrong key type. | The connection stays open. No retry. |
| `redis_connection_error` | Network failure or TLS failure. | The client reconnects once, with a new token from `token_fn`. If the second attempt fails, the error goes to the user. |
| `redis_auth_error` | The server rejects the password or the token. | No retry. |

All three classes also have the class `redisrs_error`. A Rust panic does not stop the R session. extendr catches the panic and turns it into an R error.

## Testing

### Rust unit tests

You run them with `cargo test` in `src/rust/`. They cover:

- Reply conversion for each row of the conversion table.
- IAM token signature against a fixed test vector. The test uses a fixed time and fixed keys. It does not need AWS.

### R integration tests

The tests use `testthat` and run against Docker servers:

- Plain Valkey.
- Valkey with TLS and a self-signed certificate.
- A Valkey cluster with six nodes.

A `docker-compose.yml` file in `tests/servers/` starts these servers. If a server is not available, `skip_if_not()` skips the related tests. CRAN machines have no servers, so all integration tests skip there.

### Manual AWS test

The script `inst/manual/aws-smoke-test.R` connects to a real ElastiCache Serverless cache with IAM. You run it by hand. CI does not run it.

## Build and CRAN

- The package uses `rextendr` to create the extendr scaffold.
- All Rust crates are vendored into `src/rust/vendor.tar.xz`. CRAN builds packages without network access.
- `SystemRequirements: Cargo (Rust's package manager), rustc` is in `DESCRIPTION`.
- The build prints the `rustc` version, as CRAN policy requires.
- The vendored archive must stay under the CRAN size limit. If `rustls` and its crypto crates make it too large, we review the TLS backend choice.

## Continuous integration

GitHub Actions runs on each push:

- `R CMD check` on Linux, macOS, and Windows.
- The Docker integration tests on Linux only.
- One job that builds the package from the vendored crates with the network turned off.

## Risks

- The vendored archive can be too large for CRAN. We make sure that we know its size in the first implementation step, before we write the API.
- `redis-rs` changes its API between major versions. We pin one major version in `Cargo.toml`.
- Windows builds of Rust packages for R need the correct target toolchain. The CI job on Windows finds problems early.
