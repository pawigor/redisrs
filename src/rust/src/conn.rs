use redis::cluster::{ClusterClientBuilder, ClusterConnection};
use redis::{Client, Cmd, Connection, ErrorKind, IntoConnectionInfo, ProtocolVersion, RedisError, RedisResult, Value};
use std::time::Duration;

const CONNECT_TIMEOUT: Duration = Duration::from_secs(10);

pub enum Conn {
    Plain(Connection),
    Cluster(ClusterConnection),
    Closed,
}

pub struct Auth {
    pub username: Option<String>,
    pub password: Option<String>,
}

pub fn closed_error() -> RedisError {
    RedisError::from((ErrorKind::Client, "connection is closed"))
}

pub fn open(url: &str, cluster: bool, auth: &Auth) -> RedisResult<Conn> {
    let info = url.into_connection_info()?;
    let mut redis = info.redis_settings().clone().set_protocol(ProtocolVersion::RESP3);
    if let Some(u) = &auth.username {
        redis = redis.set_username(u);
    }
    if let Some(p) = &auth.password {
        redis = redis.set_password(p);
    }
    let info = info.set_redis_settings(redis);
    if cluster {
        let mut b = ClusterClientBuilder::new(vec![info.clone()])
            .use_protocol(ProtocolVersion::RESP3)
            .connection_timeout(CONNECT_TIMEOUT);
        if let Some(u) = info.redis_settings().username() {
            b = b.username(u);
        }
        if let Some(p) = info.redis_settings().password() {
            b = b.password(p);
        }
        Ok(Conn::Cluster(b.build()?.get_connection()?))
    } else {
        let client = Client::open(info)?;
        Ok(Conn::Plain(client.get_connection_with_timeout(CONNECT_TIMEOUT)?))
    }
}

impl Conn {
    pub fn query(&mut self, cmd: &Cmd) -> RedisResult<Value> {
        match self {
            Conn::Plain(c) => cmd.query(c),
            Conn::Cluster(c) => cmd.query(c),
            Conn::Closed => Err(closed_error()),
        }
    }

    pub fn query_pipeline(&mut self, cmds: Vec<Cmd>) -> RedisResult<Vec<Value>> {
        match self {
            Conn::Plain(c) => {
                let mut p = redis::pipe();
                p.ignore_errors();
                for cmd in cmds {
                    p.add_command(cmd);
                }
                p.query(c)
            }
            Conn::Cluster(c) => {
                let mut p = redis::cluster::cluster_pipe();
                for cmd in cmds {
                    p.add_command(cmd);
                }
                p.query(c)
            }
            Conn::Closed => Err(closed_error()),
        }
    }
}
