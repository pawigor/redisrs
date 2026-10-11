use hmac::{Hmac, Mac};
use sha2::{Digest, Sha256};

type HmacSha256 = Hmac<Sha256>;

pub struct TokenRequest<'a> {
    pub cache_name: &'a str,
    pub user_id: &'a str,
    pub region: &'a str,
    pub access_key: &'a str,
    pub secret_key: &'a str,
    pub session_token: Option<&'a str>,
    pub amz_date: &'a str,
    pub serverless: bool,
}

/// SigV4 URI encoding: everything except A-Z a-z 0-9 - _ . ~ is %XX.
fn enc(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for b in s.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(b as char)
            }
            _ => out.push_str(&format!("%{b:02X}")),
        }
    }
    out
}

fn hmac(key: &[u8], msg: &str) -> Vec<u8> {
    let mut m = HmacSha256::new_from_slice(key).expect("HMAC accepts any key length");
    m.update(msg.as_bytes());
    m.finalize().into_bytes().to_vec()
}

/// Presigned `GET http://<cache_name>/?Action=connect&User=<user_id>`, as botocore builds it.
/// Parameter order in the output matches botocore: operation params, then auth params.
pub fn presign(r: &TokenRequest) -> String {
    let date = &r.amz_date[..8];
    let scope = format!("{date}/{}/elasticache/aws4_request", r.region);

    let mut op: Vec<(&str, String)> = vec![("Action", "connect".into()), ("User", r.user_id.into())];
    if r.serverless {
        op.push(("ResourceType", "ServerlessCache".into()));
    }
    let mut auth: Vec<(&str, String)> = vec![
        ("X-Amz-Algorithm", "AWS4-HMAC-SHA256".into()),
        ("X-Amz-Credential", format!("{}/{scope}", r.access_key)),
        ("X-Amz-Date", r.amz_date.into()),
        ("X-Amz-Expires", "900".into()),
        ("X-Amz-SignedHeaders", "host".into()),
    ];
    if let Some(t) = r.session_token {
        auth.push(("X-Amz-Security-Token", t.into()));
    }

    let encoded: Vec<(String, String)> = op
        .iter()
        .chain(auth.iter())
        .map(|(k, v)| (enc(k), enc(v)))
        .collect();
    let mut sorted = encoded.clone();
    sorted.sort();
    let join = |pairs: &[(String, String)]| {
        pairs.iter().map(|(k, v)| format!("{k}={v}")).collect::<Vec<_>>().join("&")
    };

    let empty_hash = hex::encode(Sha256::digest(b""));
    let canonical = format!("GET\n/\n{}\nhost:{}\n\nhost\n{empty_hash}", join(&sorted), r.cache_name);
    let to_sign = format!(
        "AWS4-HMAC-SHA256\n{}\n{scope}\n{}",
        r.amz_date,
        hex::encode(Sha256::digest(canonical.as_bytes()))
    );
    let key = hmac(
        &hmac(&hmac(&hmac(format!("AWS4{}", r.secret_key).as_bytes(), date), r.region), "elasticache"),
        "aws4_request",
    );
    let signature = hex::encode(hmac(&key, &to_sign));
    format!("{}/?{}&X-Amz-Signature={signature}", r.cache_name, join(&encoded))
}

#[cfg(test)]
mod tests {
    use super::*;

    const AK: &str = "AKIDEXAMPLE";
    const SK: &str = "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY";

    fn req<'a>(serverless: bool) -> TokenRequest<'a> {
        TokenRequest {
            cache_name: "my-cache",
            user_id: "my-user",
            region: "us-east-1",
            access_key: AK,
            secret_key: SK,
            session_token: None,
            amz_date: "20260101T000000Z",
            serverless,
        }
    }

    #[test]
    fn matches_botocore_replication_group() {
        assert_eq!(
            presign(&req(false)),
            "my-cache/?Action=connect&User=my-user&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIDEXAMPLE%2F20260101%2Fus-east-1%2Felasticache%2Faws4_request&X-Amz-Date=20260101T000000Z&X-Amz-Expires=900&X-Amz-SignedHeaders=host&X-Amz-Signature=e8b318dad7b7e107c532721e5285bf0a438c71b8c6b48a4368e27bb783d0f938"
        );
    }

    #[test]
    fn matches_botocore_serverless() {
        assert_eq!(
            presign(&req(true)),
            "my-cache/?Action=connect&User=my-user&ResourceType=ServerlessCache&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIDEXAMPLE%2F20260101%2Fus-east-1%2Felasticache%2Faws4_request&X-Amz-Date=20260101T000000Z&X-Amz-Expires=900&X-Amz-SignedHeaders=host&X-Amz-Signature=a04be4ab3f24739e3adba77f97b41461037af824596f3773a4de863ceefd018e"
        );
    }

    #[test]
    fn matches_botocore_with_session_token() {
        let r = TokenRequest {
            cache_name: "my-repl-group",
            user_id: "app-user",
            region: "eu-west-1",
            access_key: AK,
            secret_key: SK,
            session_token: Some("FQoGZXIvYXdzEXAMPLE/token+abc="),
            amz_date: "20260315T123045Z",
            serverless: false,
        };
        assert_eq!(
            presign(&r),
            "my-repl-group/?Action=connect&User=app-user&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIDEXAMPLE%2F20260315%2Feu-west-1%2Felasticache%2Faws4_request&X-Amz-Date=20260315T123045Z&X-Amz-Expires=900&X-Amz-SignedHeaders=host&X-Amz-Security-Token=FQoGZXIvYXdzEXAMPLE%2Ftoken%2Babc%3D&X-Amz-Signature=d0f33046dd166722c282a914ddaf5b273575336a4cb034fe9055f51417f8d05a"
        );
    }
}
