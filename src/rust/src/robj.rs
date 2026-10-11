use crate::reply::Reply;
use extendr_api::prelude::*;

pub fn to_robj(r: Reply) -> Robj {
    match r {
        Reply::Nil => Robj::from(()),
        // R integer has 32 bits, so all Redis integers become doubles.
        Reply::Int(i) => Robj::from(i as f64),
        Reply::Double(d) => Robj::from(d),
        Reply::Bool(b) => Robj::from(b),
        Reply::Str(s) => Robj::from(s),
        Reply::Bytes(b) => Raw::from_bytes(&b).into(),
        Reply::Array(items) => List::from_values(items.into_iter().map(to_robj)).into(),
        Reply::Map(pairs) => {
            let (names, values): (Vec<String>, Vec<Robj>) =
                pairs.into_iter().map(|(k, v)| (k, to_robj(v))).unzip();
            List::from_names_and_values(names, values).expect("names match values").into()
        }
        // Only nested errors reach here (pipeline slots). They are returned, not thrown.
        Reply::Error { code, message } => {
            let text = format!("{code} {message}").trim().to_string();
            let mut r: Robj = list!(message = text, call = (), code = code).into();
            r.set_class(&["redis_error", "redisrs_error", "error", "condition"])
                .expect("set class on a list");
            r
        }
    }
}
