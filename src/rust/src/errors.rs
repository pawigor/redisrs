use extendr_api::prelude::*;
use redis::{ErrorKind, RedisError};

fn kind_of(e: &RedisError) -> &'static str {
    if matches!(e.code(), Some("WRONGPASS") | Some("NOAUTH")) || e.kind() == ErrorKind::AuthenticationFailed {
        return "auth";
    }
    if e.is_io_error() || e.is_connection_dropped() || e.is_connection_refusal() || e.is_timeout() {
        return "connection";
    }
    match e.kind() {
        ErrorKind::Io | ErrorKind::ClusterConnectionNotFound => "connection",
        ErrorKind::InvalidClientConfig | ErrorKind::Client => "usage",
        _ => "server",
    }
}

pub fn failure_msg(kind: &str, code: &str, message: &str) -> Robj {
    let mut r: Robj = list!(kind = kind, code = code, message = message).into();
    r.set_class(&["redisrs_failure"]).expect("set class on a list");
    r
}

pub fn failure(e: &RedisError) -> Robj {
    failure_msg(kind_of(e), e.code().unwrap_or(""), &e.to_string())
}
