

# Test 1: Health check
curl http://localhost:8080/actuator/health

# Expected: {"status":"UP"}


# Test 2: Get all accounts (should show 10 accounts)
curl http://3.7.139.176:8080/api/accounts | jq

# Expected: JSON array with 10 accounts

# Test 3: Transfer money
curl -X POST http://3.7.139.176:8080/api/transfers \
  -H "Content-Type: application/json" \
  -d '{
    "fromAccountNumber": "ACC001",
    "toAccountNumber": "ACC002",
    "amount": 250.00,
    "description": "Test transfer"
  }' | jq

# Expected: JSON response with transaction details, status "SUCCESS"

# Test 4: Check account balance after transfer
curl http://localhost:8080/api/accounts/ACC001 | jq
# Alice should have: 5000 - 250 = 4750

curl http://localhost:8080/api/accounts/ACC002 | jq
# Bob should have: 3000 + 250 = 3250