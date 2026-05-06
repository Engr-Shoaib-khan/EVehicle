#!/bin/bash

# Configuration
REPO="Engr-Shoaib-khan/EVehicle"

# Define the rules in JSON
RULES='{
  "required_status_checks": {
    "strict": true,
    "contexts": ["backend-test", "flutter-analysis"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "required_conversation_resolution": true
}'

echo "Applying protection to main branch..."
gh api -X PUT "repos/$REPO/branches/main/protection" -H "Accept: application/vnd.github.v3+json" -f "required_status_checks=$(echo $RULES | jq -c .required_status_checks)" -f "enforce_admins=true" -f "required_pull_request_reviews=$(echo $RULES | jq -c .required_pull_request_reviews)" -f "required_conversation_resolution=true"

echo "Applying protection to develop branch..."
gh api -X PUT "repos/$REPO/branches/develop/protection" -H "Accept: application/vnd.github.v3+json" -f "required_status_checks=$(echo $RULES | jq -c .required_status_checks)" -f "enforce_admins=true" -f "required_pull_request_reviews=$(echo $RULES | jq -c .required_pull_request_reviews)" -f "required_conversation_resolution=true"

echo "Done!"
