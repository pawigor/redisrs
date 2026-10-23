use extendr_api::prelude::*;
use redis::{ErrorKind, RedisError};

/// The auth code of an error. A cluster startup failure is one Io error, and
/// the error of each node is only in its text.
fn auth_code(e: &RedisError) -> Option<&'static str> {
    let text = match e.code() {
        Some(code) => code.to_string(),
        None if e.kind() == ErrorKind::Io => e.to_string(),
        None => return None,
    };
    ["WRONGPASS", "NOAUTH"].into_iter().find(|c| text.contains(c))
}

fn kind_of(e: &RedisError) -> &'static str {
    if auth_code(e).is_some() || e.kind() == ErrorKind::AuthenticationFailed {
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
    failure_msg(kind_of(e), e.code().or(auth_code(e)).unwrap_or(""), &e.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn plain_server_error_is_server() {
        let e = RedisError::from((ErrorKind::Server(redis::ServerErrorKind::ResponseError), "x"));
        assert_eq!(kind_of(&e), "server");
    }

    #[test]
    fn cluster_startup_auth_failure_is_auth() {
        let e = RedisError::from((
            ErrorKind::Io,
            "It failed to check startup nodes.",
            "Failed to connect to each cluster node (127.0.0.1:7000: WRONGPASS: invalid username-password pair)".to_string(),
        ));
        assert_eq!(kind_of(&e), "auth");
        assert_eq!(auth_code(&e), Some("WRONGPASS"));
    }

    #[test]
    fn cluster_startup_refusal_is_connection() {
        let e = RedisError::from((
            ErrorKind::Io,
            "It failed to check startup nodes.",
            "Failed to connect to each cluster node (127.0.0.1:7000: Connection refused (os error 111))".to_string(),
        ));
        assert_eq!(kind_of(&e), "connection");
    }
}
