include .env

#--verify --etherscan-api-key ${ETHERSCAN_API_KEY}
deploy-mt:
# 	forge script script/MockToken.s.sol:MockTokenScript --private-key ${PRIVATE_KEY} --broadcast --rpc-url ${RPC_URL} --legacy --verify --etherscan-api-key ${ETHERSCAN_API_KEY}
	forge script script/MockToken.s.sol:MockTokenScript --private-key ${PRIVATE_KEY} --broadcast --rpc-url ${RPC_URL} --legacy --verify --verifier=blockscout --verifier-url https://explorer-api-holesky.morphl2.io/api\?

deploy-vault:
	forge script script/StakerVault.s.sol:StakerVaultScript --private-key ${PRIVATE_KEY} --broadcast --rpc-url ${RPC_URL} --legacy --verify --verifier=blockscout --verifier-url https://explorer-api-holesky.morphl2.io/api\?

deploy-mul3:
	forge script script/Multicall3.s.sol:Multicall3Script --private-key ${PRIVATE_KEY} --broadcast --rpc-url ${RPC_URL} --legacy --verify --verifier=blockscout --verifier-url https://explorer-api-holesky.morphl2.io/api\?

deploy-bridger:
	forge script script/Bridger.s.sol:BridgerScript --private-key ${PRIVATE_KEY} --broadcast --rpc-url ${RPC_URL} --verify --etherscan-api-key ${ETHERSCAN_API_KEY}

