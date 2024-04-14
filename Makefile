deploy-mt:
	forge script script/MappedToken.s.sol:MappedTokenScript --private-key ${PRIVATE_KEY} --broadcast --rpc-url ${RPC_URL}

