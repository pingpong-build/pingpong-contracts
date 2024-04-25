deploy-mt:
	forge script script/MockToken.s.sol:MockTokenScript --private-key ${PRIVATE_KEY} --broadcast --rpc-url ${RPC_URL} --verify --etherscan-api-key ${ETHERSCAN_API_KEY}

deploy-bridger:
	forge script script/Bridger.s.sol:BridgerScript --private-key ${PRIVATE_KEY} --broadcast --rpc-url ${RPC_URL} --verify --etherscan-api-key ${ETHERSCAN_API_KEY}

