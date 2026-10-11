use redis::Value;

/// A Redis reply in plain Rust types. `robj.rs` turns it into an R value.
#[derive(Debug, Clone, PartialEq)]
pub enum Reply {
    Nil,
    Int(i64),
    Double(f64),
    Bool(bool),
    Str(String),
    Bytes(Vec<u8>),
    Array(Vec<Reply>),
    Map(Vec<(String, Reply)>),
    Error { code: String, message: String },
}

/// R strings cannot hold NUL, so bytes with NUL stay raw even when valid UTF-8.
fn bytes_reply(b: Vec<u8>, raw: bool) -> Reply {
    if raw || b.contains(&0) {
        return Reply::Bytes(b);
    }
    match String::from_utf8(b) {
        Ok(s) => Reply::Str(s),
        Err(e) => Reply::Bytes(e.into_bytes()),
    }
}

fn key_string(v: Value) -> String {
    match from_value(v, false) {
        Reply::Str(s) => s,
        Reply::Int(i) => i.to_string(),
        Reply::Double(d) => d.to_string(),
        Reply::Bytes(b) => String::from_utf8_lossy(&b).into_owned(),
        other => format!("{other:?}"),
    }
}

pub fn from_value(v: Value, raw: bool) -> Reply {
    match v {
        Value::Nil => Reply::Nil,
        Value::Int(i) => Reply::Int(i),
        Value::Double(d) => Reply::Double(d),
        Value::Boolean(b) => Reply::Bool(b),
        Value::Okay => Reply::Str("OK".into()),
        Value::SimpleString(s) => Reply::Str(s),
        Value::BulkString(b) => bytes_reply(b, raw),
        Value::VerbatimString { text, .. } => Reply::Str(text),
        Value::Array(items) | Value::Set(items) => {
            Reply::Array(items.into_iter().map(|x| from_value(x, raw)).collect())
        }
        Value::Push { data, .. } => {
            Reply::Array(data.into_iter().map(|x| from_value(x, raw)).collect())
        }
        Value::Map(pairs) => Reply::Map(
            pairs
                .into_iter()
                .map(|(k, v)| (key_string(k), from_value(v, raw)))
                .collect(),
        ),
        Value::Attribute { data, .. } => from_value(*data, raw),
        Value::ServerError(e) => Reply::Error {
            code: e.code().to_string(),
            message: e.details().unwrap_or("").to_string(),
        },
        // Without the num-bigint feature, a big number holds its decimal digits as bytes.
        Value::BigNumber(digits) => Reply::Str(String::from_utf8_lossy(&digits).into_owned()),
        // Value is non_exhaustive: keep the text form of any variant added later.
        other => Reply::Str(format!("{other:?}")),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use redis::Value;

    fn bulk(b: &[u8]) -> Value {
        Value::BulkString(b.to_vec())
    }

    #[test]
    fn utf8_bulk_string_is_str() {
        assert_eq!(from_value(bulk("héllo".as_bytes()), false), Reply::Str("héllo".into()));
    }

    #[test]
    fn bulk_with_nul_is_bytes() {
        assert_eq!(from_value(bulk(b"X\n\0\0"), false), Reply::Bytes(b"X\n\0\0".to_vec()));
    }

    #[test]
    fn invalid_utf8_is_bytes() {
        assert_eq!(from_value(bulk(&[0xff, 0xfe]), false), Reply::Bytes(vec![0xff, 0xfe]));
    }

    #[test]
    fn raw_flag_forces_bytes() {
        assert_eq!(from_value(bulk(b"abc"), true), Reply::Bytes(b"abc".to_vec()));
    }

    #[test]
    fn scalars() {
        assert_eq!(from_value(Value::Nil, false), Reply::Nil);
        assert_eq!(from_value(Value::Int(3_000_000_000), false), Reply::Int(3_000_000_000));
        assert_eq!(from_value(Value::Double(1.5), false), Reply::Double(1.5));
        assert_eq!(from_value(Value::Boolean(true), false), Reply::Bool(true));
        assert_eq!(from_value(Value::Okay, false), Reply::Str("OK".into()));
        assert_eq!(from_value(Value::SimpleString("PONG".into()), false), Reply::Str("PONG".into()));
    }

    #[test]
    fn arrays_and_sets_are_arrays() {
        let v = Value::Array(vec![Value::Int(1), Value::Array(vec![bulk(b"a")])]);
        assert_eq!(
            from_value(v, false),
            Reply::Array(vec![Reply::Int(1), Reply::Array(vec![Reply::Str("a".into())])])
        );
        let s = Value::Set(vec![bulk(b"x")]);
        assert_eq!(from_value(s, false), Reply::Array(vec![Reply::Str("x".into())]));
    }

    #[test]
    fn map_has_string_keys() {
        let v = Value::Map(vec![(bulk(b"f1"), bulk(b"v1")), (Value::Int(2), Value::Nil)]);
        assert_eq!(
            from_value(v, false),
            Reply::Map(vec![("f1".into(), Reply::Str("v1".into())), ("2".into(), Reply::Nil)])
        );
    }

    #[test]
    fn raw_flag_applies_to_map_values_not_keys() {
        let v = Value::Map(vec![(bulk(b"f"), bulk(b"v"))]);
        assert_eq!(from_value(v, true), Reply::Map(vec![("f".into(), Reply::Bytes(b"v".to_vec()))]));
    }
}
