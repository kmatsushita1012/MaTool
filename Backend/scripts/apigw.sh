#!/bin/bash
METHOD=${1:-GET}
RAW_PATH=${2:-/}
BODY=${3:-""}
AUTH_ENABLED=false

# --- オプション解析 ---
while [[ "$1" =~ ^- ]]; do
  case "$1" in
    --auth)
      AUTH_ENABLED=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# --- クエリ文字列とパスを分離 ---
PATH_ONLY=$(echo "$RAW_PATH" | cut -d'?' -f1)
QUERY_STRING=$(echo "$RAW_PATH" | cut -s -d'?' -f2)

# --- proxy パラメータ生成 ---
# 先頭の / を削除した文字列を proxy に設定
PROXY_VALUE=$(echo "$PATH_ONLY" | sed 's#^/##')

# --- pathParameters JSON ---
if [ -n "$PROXY_VALUE" ]; then
    PATH_PARAMS_JSON="{\"proxy\":\"$PROXY_VALUE\"}"
else
    PATH_PARAMS_JSON="{}"
fi

# --- クエリパラメータを JSON に変換 ---
if [ -n "$QUERY_STRING" ]; then
    QUERY_JSON=$(echo "$QUERY_STRING" | jq -R 'split("&") | map(split("=")) | map({(.[0]): .[1]}) | add')
else
    QUERY_JSON="{}"
fi

# --- JSON ペイロード作成 ---
HEADERS_JSON="{}"
if [ "$AUTH_ENABLED" = true ]; then
  HEADERS_JSON=$(jq -n '{"authorization": "Bearer AUTH_TOKEN"}')
fi

JSON_PAYLOAD=$(jq -n \
  --arg method "$METHOD" \
  --arg rawPath "$PATH_ONLY" \
  --arg rawQueryString "$QUERY_STRING" \
  --arg body "$BODY" \
  --argjson pathParams "$PATH_PARAMS_JSON" \
  --argjson queryParams "$QUERY_JSON" \
  --argjson headers "$HEADERS_JSON" \
  '{
    version: "2.0",
    routeKey: ($method + " " + $rawPath),
    rawPath: $rawPath,
    rawQueryString: $rawQueryString,
    headers: $headers,
    queryStringParameters: $queryParams,
    pathParameters: $pathParams,
    body: $body,
    isBase64Encoded: false,
    requestContext: {
      accountId: "123456789012",
      apiId: "local",
      domainName: "localhost",
      domainPrefix: "localhost",
      http: {
        method: $method,
        path: $rawPath,
        protocol: "HTTP/1.1",
        sourceIp: "127.0.0.1",
        userAgent: "curl/7.64.1"
      },
      requestId: "id",
      routeKey: ($method + " " + $rawPath),
      stage: "$default",
      time: "26/Oct/2025:12:00:00 +0000",
      timeEpoch: 1737844800000
    }
  }'
)

# --- 実行 ---
curl -X POST http://127.0.0.1:7000/invoke \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD"
