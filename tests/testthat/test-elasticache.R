creds <- list(
  access_key_id = "AKIDEXAMPLE",
  secret_access_key = "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY",
  session_token = ""
)

test_that("the token matches the botocore reference", {
  tok <- iam_token_at("my-cache", "my-user", "us-east-1", FALSE, creds, "20260101T000000Z")
  expect_equal(
    tok,
    "my-cache/?Action=connect&User=my-user&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIDEXAMPLE%2F20260101%2Fus-east-1%2Felasticache%2Faws4_request&X-Amz-Date=20260101T000000Z&X-Amz-Expires=900&X-Amz-SignedHeaders=host&X-Amz-Signature=e8b318dad7b7e107c532721e5285bf0a438c71b8c6b48a4368e27bb783d0f938"
  )
})

test_that("serverless adds ResourceType", {
  tok <- iam_token_at("my-cache", "my-user", "us-east-1", TRUE, creds, "20260101T000000Z")
  expect_match(tok, "&ResourceType=ServerlessCache&", fixed = TRUE)
})

test_that("a session token is included", {
  c2 <- creds
  c2$session_token <- "abc/def"
  tok <- iam_token_at("c", "u", "us-east-1", FALSE, c2, "20260101T000000Z")
  expect_match(tok, "X-Amz-Security-Token=abc%2Fdef", fixed = TRUE)
})

test_that("elasticache_iam_token uses the current UTC time", {
  tok <- elasticache_iam_token("c", "u", "us-east-1", credentials = creds)
  today <- format(Sys.time(), "%Y%m%d", tz = "UTC")
  expect_match(tok, paste0("X-Amz-Date=", today), fixed = TRUE)
})

test_that("missing paws.common gives a clear usage error", {
  local_mocked_bindings(has_paws = function() FALSE)
  expect_error(elasticache_iam_token("c", "u", "us-east-1"), class = "redis_usage_error",
               regexp = "paws.common")
})
