# Test servers

The integration tests need these servers. Docker with Compose must be installed. The cluster uses host networking, so it works on Linux only.

1. Make the certificates: `tests/servers/gen-certs.sh`
2. Start the servers: `docker compose -f tests/servers/docker-compose.yml up -d`
3. Run the tests: `REDISRS_TEST_SERVERS=true Rscript -e 'devtools::test()'`
4. Stop the servers: `docker compose -f tests/servers/docker-compose.yml down`
