# redisrs 0.1.0

* First release. Connect to Redis and Valkey with `redis_connect()`, run commands with `redis_cmd()` and `redis_pipeline()`, and store R objects with `redis_set_object()`.
* TLS, Redis Cluster and Unix sockets.
* IAM authentication for AWS ElastiCache with `redis_connect_elasticache()`.
* `redis_cmd()` and `redis_pipeline()` refuse commands that change the connection mode or get no normal reply, and `SELECT`. Put the database number in the URL.
