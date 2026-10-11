use extendr_api::prelude::*;

mod conn;
mod errors;
mod iam;
mod reply;
mod robj;

#[extendr]
pub struct RedisConn {
    conn: conn::Conn,
}

fn opt_string(x: &Robj) -> Option<String> {
    if x.is_null() {
        None
    } else {
        x.as_str().map(str::to_string)
    }
}

fn build_cmd(args: &List) -> std::result::Result<redis::Cmd, String> {
    let mut cmd = redis::Cmd::new();
    for (_, a) in args.iter() {
        let bytes = a.as_raw_slice().ok_or("internal: argument is not a raw vector")?;
        cmd.arg(bytes);
    }
    Ok(cmd)
}

#[extendr]
impl RedisConn {
    fn cmd(&mut self, args: List, raw: bool) -> Robj {
        let cmd = match build_cmd(&args) {
            Ok(c) => c,
            Err(m) => return errors::failure_msg("usage", "", &m),
        };
        match self.conn.query(&cmd) {
            Ok(v) => robj::to_robj(reply::from_value(v, raw)),
            Err(e) => errors::failure(&e),
        }
    }

    fn close(&mut self) {
        self.conn = conn::Conn::Closed;
    }
}

#[extendr]
fn rs_connect(url: &str, cluster: bool, username: Robj, password: Robj) -> Robj {
    let auth = conn::Auth {
        username: opt_string(&username),
        password: opt_string(&password),
    };
    match conn::open(url, cluster, &auth) {
        Ok(c) => RedisConn { conn: c }.into(),
        Err(e) => errors::failure(&e),
    }
}

extendr_module! {
    mod redisrs;
    impl RedisConn;
    fn rs_connect;
}
