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
- AWS credentials come from the R package `paws.common`. The token signature is made in Rust with the small crates `hmac` and `sha2`. We do not use `aws-sigv4` or the AWS SDK for Rust, because they add many vendored crates. A test vector from botocore makes sure that the signature is correct.
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
- It signs IAM tokens with SigV4 (`hmac` and `sha2`).

The Rust core keeps the connection kind in an enum. Version 1 has two kinds: plain and cluster. Later versions add kinds without a change to the R API.

The connection goes to R as an external pointer inside an R object of class `redisrs_connection`. The user never gets a bare pointer. When the garbage collector removes the object, R frees the connection. A call to `redis_close()` also frees it.

### Layer 2: R base functions

These functions are thin R wrappers around the Rust core.

| Function | Purpose |
|---|---|
| `redis_connect(url, cluster = FALSE, username = NULL, token_fn = NULL)` | Open a connection. |
| `redis_cmd(con, ...)` | Run one command, for example `redis_cmd(con, "SET", "k", "v")`. Commands that change the connection mode are refused. |
| `redis_pipeline(con, cmds)` | Run a list of commands in one round trip. Return a list of replies. |
| `redis_close(con)` | Close the connection. |

`token_fn` is an R function without arguments. It returns a password string. The R layer calls it at each connect and reconnect, and passes the result to the Rust core. If `token_fn` is `NULL`, the client uses the password from the URL.

### Layer 3: R convenience functions

| Function | Purpose |
|---|---|
| `redis_connect_elasticache(endpoint, cache_name, user_id, region, port = 6379, cluster = FALSE, serverless = FALSE)` | Build a `rediss://` URL for `endpoint`, and set `token_fn` to an IAM token generator for `cache_name`. |
| `elasticache_iam_token(cache_name, user_id, region, serverless = FALSE, credentials = NULL)` | Return a fresh IAM token. If `credentials` is `NULL`, credentials come from `paws.common::locate_credentials()`. |

`endpoint` is the DNS name that the client connects to. `cache_name` is the replication group ID or the serverless cache name. The token signs `cache_name`, not `endpoint`. `user_id` is the ElastiCache user ID. AUTH uses the same `user_id` as the username.
| `redis_set_object(con, key, value, ex = NULL)` | Serialize an R object and store it. `ex` is the expiry in seconds. |
| `redis_get_object(con, key)` | Read and unserialize an R object. If the key does not exist, return `NULL`. |

`paws.common` is in `Suggests`. If the user calls an IAM function and `paws.common` is not installed, the package stops with a clear error message.

## IAM authentication

An IAM token is a presigned SigV4 request to the ElastiCache service. The request is `GET http://<cache_name>/?Action=connect&User=<user_id>`. For a serverless cache, the query also has `&ResourceType=ServerlessCache`. The token is this URL without `http://`. The payload hash is the SHA-256 of an empty body, as in botocore. The token is valid for 15 minutes. AWS closes a connection that uses an IAM token after 12 hours.

The flow is:

1. R calls `paws.common::locate_credentials()`. This reads environment variables, `~/.aws` profiles, EC2 and ECS roles, and SSO.
2. R passes the access key, secret key, session token, region, cache name, and user ID to the Rust core.
3. The Rust core builds the presigned request and returns the token string.
4. The R layer passes `user_id` and the token to the Rust core as the username and password for AUTH.

The R layer calls `token_fn` at each connect and reconnect. Thus a reconnect after 12 hours gets a new token. Rust never calls back into R. This keeps the Rust core free of R callbacks, which are safe only on the main R thread.

In cluster mode, `redis-rs` reconnects to single nodes internally with the password that it got at the start. After 15 minutes that token is no longer valid, so an internal reconnect can fail with an auth error. For this reason, if `token_fn` is set, the R layer also rebuilds the connection once after an auth error.

## Reply conversion

The client always uses RESP3. The user cannot select RESP2. Thus the shape of each reply stays the same in all versions.

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
| `redis_auth_error` | The server rejects the password or the token. | If `token_fn` is set, the client reconnects once with a new token. Else, no retry. |
| `redis_usage_error` | The user passes a command that changes the connection mode, an invalid URL, an invalid argument, or a closed connection. | Nothing goes to the server. No retry. |

All four classes also have the class `redisrs_error`.

A retry after a connection error sends the command again. If the first attempt reached the server before the failure, a command such as `INCR` runs twice. The documentation of `redis_cmd()` states this. A Rust panic does not stop the R session. extendr catches the panic and turns it into an R error.

## Extension points

Later versions add features without a change to the version 1 contract. Three rules in version 1 make this possible.

### Rule 1: `redis_cmd()` refuses mode commands

`redis_cmd()` and `redis_pipeline()` refuse these commands with a `redis_usage_error`:

- `SUBSCRIBE`, `PSUBSCRIBE`, `SSUBSCRIBE`
- `MONITOR`

After one of these commands, a connection stops replying to normal commands. If version 1 accepted them, a later refusal would break user code.

### Rule 2: RESP3 is fixed

Version 1 always uses RESP3. RESP2 and RESP3 give different shapes for the same reply. For example, `HGETALL` gives a flat list in RESP2 and a map in RESP3. A later switch would break user code.

### Rule 3: the connection has an R class

Each connection is an R object of class `redisrs_connection`. New connection types get new classes. Shared functions use S3 dispatch (selection of a function by the class of the object).

### Map of later features

| Feature | How it comes | Contract change |
|---|---|---|
| Streams | Commands already work through `redis_cmd()`. Later helpers, for example `redis_stream_read()`, convert replies into a `data.frame`. | No |
| Pub/Sub | `redis_subscribe(con, channels)` returns an object of class `redisrs_subscriber`. `redis_poll(sub, timeout)` reads messages. | No |
| Sentinel | A new connect function or a new URL scheme. | No |
| Asynchronous mode | `redis_connect_async()` returns a new class. Commands return promises. The synchronous API stays the same. | No |
| `redux`-compatible API | A separate set of functions on top of `redis_cmd()`. | No |

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
- `rustls` can select the `aws-lc-rs` crypto provider. That provider needs cmake and NASM, which CRAN and Windows machines do not always have. We make sure that the build uses `ring`.
- The synchronous Pub/Sub API of `redis-rs` can lack support for sharded channels in cluster mode. We find this out in the first implementation step. The result does not change version 1, but it changes the Pub/Sub design.
- Windows builds of Rust packages for R need the correct target toolchain. The CI job on Windows finds problems early.
