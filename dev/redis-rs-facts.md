# redis-rs facts (version 1.7.1)

These facts come from the source of `redis` 1.7.1 and `extendr-api` 0.9.0, read on 2026-10-11. Later tasks use the names in this file.

## Versions and build

- `redis` is pinned to `=1.7.1`. Features: `cluster`, `tls-rustls`, `tls-rustls-insecure`. Default features are off.
- `extendr-api` is 0.9.0. `rustls` is 0.23.45 with `ring` 0.17.14.
- MSRV of `redis` 1.7.1: Rust 1.88. `Cargo.toml` and `SystemRequirements` say `rustc >= 1.88.0`.
- Tarball size: 4,713,140 bytes. `vendor.tar.xz`: 4,698,288 bytes. Plain `cargo vendor` gave 13.2 MB. `tools/vendor-crates.R` makes the archive and keeps it small.
- The offline install of the tarball works with no network and an empty `CARGO_HOME`.
- Crypto provider: `ring`. `aws-lc-rs` is absent. `openssl-sys` is absent.
- `tls-rustls-webpki-roots` is off. TLS uses only the system CA store through `rustls-native-certs`.
- `idna_adapter` is pinned to `=1.0.0`. This removes the ICU4X crates. Host names in URLs must be ASCII.
- `cargo test` links against R with `R_HOME=$(R RHOME)` and no rpath configuration.

## Values and errors

- `redis::Value` is `#[non_exhaustive]`. Its variants are:
  - `Nil`
  - `Int(i64)`
  - `BulkString(Vec<u8>)`
  - `Array(Vec<Value>)`
  - `SimpleString(String)`
  - `Okay`
  - `Map(Vec<(Value, Value)>)`
  - `Attribute { data: Box<Value>, attributes: Vec<(Value, Value)> }`
  - `Set(Vec<Value>)`
  - `Double(f64)`
  - `Boolean(bool)`
  - `VerbatimString { format: VerbatimFormat, text: String }`
  - `BigNumber(Vec<u8>)` (the `num-bigint` feature is off)
  - `Push { kind: PushKind, data: Vec<Value> }`
  - `ServerError(ServerError)`
- `ServerError` accessors: `code(&self) -> &str`, `details(&self) -> Option<&str>`, `kind(&self) -> Option<ServerErrorKind>`.
- `RedisError` methods:
  - `kind() -> ErrorKind`
  - `code() -> Option<&str>`
  - `detail() -> Option<&str>`
  - `is_io_error()`
  - `is_cluster_error()`
  - `is_connection_refusal()`
  - `is_timeout()`
  - `is_connection_dropped()`
  - `is_unrecoverable_error()`
  - `retry_method()`
- `ErrorKind` variants:
  - `Parse`
  - `AuthenticationFailed`
  - `UnexpectedReturnType`
  - `InvalidClientConfig`
  - `Io`
  - `Client`
  - `Extension`
  - `MasterNameNotFoundBySentinel`
  - `NoValidReplicasFoundBySentinel`
  - `EmptySentinelList`
  - `ClusterConnectionNotFound`
  - `Server(ServerErrorKind)`
  - `Serialize`
  - `RESP3NotSupported`
- The plan's `IoError` is now `Io`, and `ClientError` is now `Client`.
- `ServerErrorKind` variants: `ResponseError`, `ExecAbort`, `BusyLoading`, `NoScript`, `Moved`, `Ask`, `TryAgain`, `ClusterDown`, `CrossSlot`, `MasterDown`, `ReadOnly`, `NotBusy`, `NoSub`, `NoPerm`. There is no auth kind. Auth failures from the server carry the codes `WRONGPASS` or `NOAUTH`.
- `RedisError::from((ErrorKind, &'static str))` and `from((ErrorKind, &'static str, String))` exist.

## Connections

- `ConnectionInfo` and `RedisConnectionInfo` fields are `pub(crate)`. Use builder methods that take `self` and return `Self`:
  - `ConnectionInfo::redis_settings() -> &RedisConnectionInfo`, `ConnectionInfo::set_redis_settings(RedisConnectionInfo)`.
  - `RedisConnectionInfo::set_username(impl AsRef<str>)`, `set_password(impl AsRef<str>)`, `set_protocol(ProtocolVersion)`, and the getters `username()`, `password()`, `protocol()`.
- `ProtocolVersion::RESP3` exists.
- `Client::get_connection_with_timeout(Duration)` exists.
- `redis::cluster` is the sync cluster module (`ClusterClient`, `ClusterClientBuilder`, `ClusterConnection`, `cluster_pipe`).
- `ClusterClientBuilder` methods: `new(nodes)`, `use_protocol`, `connection_timeout`, `username`, `password`, `tls(TlsMode)`, `danger_accept_invalid_hostnames`, `certs`, `build`.
- `rediss://host:port/#insecure` gives `ConnectionAddr::TcpTls { insecure: true }`. This needs the `tls-rustls-insecure` feature. Any other URL fragment is an error.
- If the cluster builder has no TLS mode, it takes the mode from the first node's address. So `rediss://...#insecure` also works for clusters.

## Pipelines

- `Pipeline::ignore_errors()` exists. With it, a failed command comes back as a `Value::ServerError` in its slot, and the query succeeds.
- Cluster pipeline: `redis::cluster::cluster_pipe()` returns `ClusterPipeline`. It has `add_command` (from the shared `implement_pipeline_commands!` macro) and `query(&mut ClusterConnection)`. It has no `ignore_errors()`. An empty cluster pipeline is an error.

## Pub/Sub (for the future design only)

- Sync sharded Pub/Sub (`SSUBSCRIBE`) on a cluster connection: not supported. Only the async cluster connection handles sharded channels.

## extendr 0.9 names used by Task 6

- `Raw::from_bytes(&[u8])`, `Robj::as_raw_slice() -> Option<&[u8]>`, `Robj::as_str() -> Option<&str>`, `Robj::as_list() -> Option<List>`, `Robj::is_null()`.
- `List::from_values(iter)`, `List::from_names_and_values(names, values) -> Result<List>`.
- `Attributes::set_class(&mut self, class) -> Result<&mut Self>`.
- The `list!` macro comes from `extendr_macros` through the prelude.
