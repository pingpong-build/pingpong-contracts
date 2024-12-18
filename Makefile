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

deploy-pass:
	forge script script/MachinePassManager.s.sol:MachinePassManagerScript --private-key ${PRIVATE_KEY} --broadcast --rpc-url ${RPC_URL} --legacy

deploy-market:
	forge script script/MachineMarket.s.sol:MachineMarketScript --private-key ${PRIVATE_KEY} --broadcast --rpc-url ${RPC_URL} --legacy

deploy-mining-share:
	forge script script/MiningShareFactory.s.sol:MiningShareFactoryScript --private-key ${PRIVATE_KEY} --broadcast --rpc-url ${RPC_URL} --legacy

mint-mining-share:
	forge script script/MiningShareFactory.s.sol:MiningShareFactoryScript --sig "mint()" --private-key ${PRIVATE_KEY} --broadcast --rpc-url ${RPC_URL} --legacy

grant-mining-share:
	forge script script/MiningShareFactory.s.sol:MiningShareFactoryScript --sig "grant()" --private-key ${PRIVATE_KEY} --broadcast --rpc-url ${RPC_URL} --legacy

market-prepare:
	forge script script/MachineMarket.s.sol:MachineMarketScript  --sig "prepare()" --private-key ${PRIVATE_KEY} --broadcast --rpc-url ${RPC_URL} --legacy

invoke-mpf-%:
	$(eval CMD := $(subst invoke-mpf-,,$@))
	@echo "Invoke msf $(CMD) function"
	forge script script/MiningPassFactory.s.sol:MiningPassFactoryScript --sig "$(CMD)()" --private-key ${PRIVATE_KEY} --broadcast --rpc-url ${RPC_URL} --legacy --verify --etherscan-api-key ${ETHERSCAN_API_KEY}

deploy-fcm:
	forge script script/ForwardContractManager.s.sol:ForwardContractManagerScript --private-key ${PRIVATE_KEY} --broadcast --rpc-url ${RPC_URL} --legacy --verify --etherscan-api-key ${ETHERSCAN_API_KEY}

deploy-mc:
	#forge script script/MerchantController.s.sol:MerchantControllerScript --private-key ${PRIVATE_KEY} --broadcast --rpc-url ${RPC_URL} --legacy --verify --etherscan-api-key ${ETHERSCAN_API_KEY}
	forge script script/MerchantController.s.sol:MerchantControllerScript --private-key ${PRIVATE_KEY} --broadcast --rpc-url ${RPC_URL} --legacy

invoke-fcm-%:
	$(eval CMD := $(subst invoke-fcm-,,$@))
	@echo "Invoke fcm $(CMD) function"
	forge script script/ForwardContractManager.s.sol:ForwardContractManagerScript --sig "$(CMD)()" --private-key ${PRIVATE_KEY} --broadcast --rpc-url ${RPC_URL} --legacy --verify --etherscan-api-key ${ETHERSCAN_API_KEY}
