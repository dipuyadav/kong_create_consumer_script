#!/bin/bash

# Prompt for username and tag
read -p "Enter username: " USERNAME
read -p "Enter tag for this consumer: " TAG
CUSTOM_ID="$USERNAME"

# Step 1: Create Consumer
CREATE_CONSUMER_RESPONSE=$(curl -s -X POST http://101.44.189.190:8001/default/consumers \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"$USERNAME\", \"custom_id\": \"$CUSTOM_ID\", \"tags\": [\"$TAG\"]}")

CONSUMER_ID=$(echo "$CREATE_CONSUMER_RESPONSE" | jq -r '.id')

if [[ "$CONSUMER_ID" == "null" || -z "$CONSUMER_ID" ]]; then
  echo "❌ Failed to create consumer. Response:"
  echo "$CREATE_CONSUMER_RESPONSE"
  exit 1
fi

echo "✅ Consumer created with ID: $CONSUMER_ID"

# Step 2: Generate 32-character random key (16 bytes = 32 hex characters)
KEY=$(openssl rand -hex 16)

# Step 3: Add Key to Consumer
ADD_KEY_RESPONSE=$(curl -s -X POST http://101.44.189.190:8001/default/consumers/$CONSUMER_ID/key-auth \
  -H "Content-Type: application/json" \
  -d "{\"key\": \"$KEY\"}")

if echo "$ADD_KEY_RESPONSE" | grep -q '"id":'; then
  echo "✅ Key added to consumer"
else
  echo "❌ Failed to add key. Response:"
  echo "$ADD_KEY_RESPONSE"
  exit 1
fi

# Step 4: Prompt for ACL group name
read -p "Enter ACL group name: " GROUP

# Step 5: Add ACL
ADD_ACL_RESPONSE=$(curl -s -X POST http://101.44.25.136:8001/default/consumers/$CONSUMER_ID/acls \
  -H "Content-Type: application/json" \
  -d "{\"group\":\"$GROUP\",\"tags\":[\"$GROUP\"]}")

if echo "$ADD_ACL_RESPONSE" | grep -q '"group":'; then
  echo "✅ ACL group added"
else
  echo "❌ Failed to add ACL. Response:"
  echo "$ADD_ACL_RESPONSE"
  exit 1
fi

# Step 6: Add Rate-Limiting Plugin
ADD_PLUGIN_RESPONSE=$(curl -s -X POST http://101.44.25.136:8001/default/consumers/$CONSUMER_ID/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "enabled": true,
    "name": "rate-limiting",
    "consumer": { "id": "'"$CONSUMER_ID"'" },
    "protocols": ["grpc", "grpcs", "http", "https"],
    "config": {
      "error_code": 429,
      "error_message": "API rate limit exceeded",
      "fault_tolerant": true,
      "hide_client_headers": false,
      "limit_by": "consumer",
      "second": 300,
      "policy": "local"
    }
  }')

if echo "$ADD_PLUGIN_RESPONSE" | grep -q '"name":'; then
  echo "✅ Rate-limiting plugin added"
else
  echo "❌ Failed to add plugin. Response:"
  echo "$ADD_PLUGIN_RESPONSE"
  exit 1
fi

# Final output
echo ""
echo "🎉 All steps completed successfully."
echo "🔑 Your generated key is: $KEY"
