# Independent SigV4 query presign for an ElastiCache IAM token (reference only).
import hashlib, hmac
from urllib.parse import quote

def enc(s): return quote(s, safe="-_.~")
def h(key, msg): return hmac.new(key, msg.encode(), hashlib.sha256).digest()

def presign(cache, user, region, ak, sk, amz_date, expires=900, serverless=False):
    date = amz_date[:8]
    scope = f"{date}/{region}/elasticache/aws4_request"
    params = {"Action": "connect", "User": user}
    if serverless:
        params["ResourceType"] = "ServerlessCache"
    params.update({
        "X-Amz-Algorithm": "AWS4-HMAC-SHA256",
        "X-Amz-Credential": f"{ak}/{scope}",
        "X-Amz-Date": amz_date,
        "X-Amz-Expires": str(expires),
        "X-Amz-SignedHeaders": "host",
    })
    cq = "&".join(f"{enc(k)}={enc(v)}" for k, v in sorted(params.items()))
    creq = "\n".join(["GET", "/", cq, f"host:{cache}\n", "host",
                      hashlib.sha256(b"").hexdigest()])
    sts = "\n".join(["AWS4-HMAC-SHA256", amz_date, scope,
                     hashlib.sha256(creq.encode()).hexdigest()])
    k = h(h(h(h(("AWS4" + sk).encode(), date), region), "elasticache"), "aws4_request")
    return hmac.new(k, sts.encode(), hashlib.sha256).hexdigest()

print(presign("my-cache", "my-user", "us-east-1", "AKIDEXAMPLE",
              "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY", "20260101T000000Z"))
print(presign("my-cache", "my-user", "us-east-1", "AKIDEXAMPLE",
              "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY", "20260101T000000Z", serverless=True))
