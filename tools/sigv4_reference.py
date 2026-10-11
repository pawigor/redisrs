# Prints the ElastiCache IAM token test vectors that src/rust/src/iam.rs and
# tests/testthat/test-elasticache.R check against. botocore signs the tokens
# with a frozen clock, so the output is fixed. Not part of the R package.
#
#   python3 -m venv /tmp/boto && /tmp/boto/bin/pip install botocore
#   /tmp/boto/bin/python -I tools/sigv4_reference.py
#
# Checked with botocore 1.43.111.
import datetime
import botocore.auth as auth
from botocore.awsrequest import AWSRequest
from botocore.credentials import Credentials

AK = "AKIDEXAMPLE"
SK = "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY"


def token(cache, user, region, when, serverless=False, session=None):
    auth.get_current_datetime = lambda: when
    params = {"Action": "connect", "User": user}
    if serverless:
        params["ResourceType"] = "ServerlessCache"
    req = AWSRequest(method="GET", url=f"http://{cache}/", params=params)
    auth.SigV4QueryAuth(Credentials(AK, SK, session), "elasticache", region, expires=900).add_auth(req)
    return req.prepare().url.removeprefix("http://")


d1 = datetime.datetime(2026, 1, 1, 0, 0, 0)
d2 = datetime.datetime(2026, 3, 15, 12, 30, 45)
print(token("my-cache", "my-user", "us-east-1", d1))
print(token("my-cache", "my-user", "us-east-1", d1, serverless=True))
print(token("my-repl-group", "app-user", "eu-west-1", d2, session="FQoGZXIvYXdzEXAMPLE/token+abc="))
