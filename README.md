# private-paymaster

When users withdraw funds from a shielded pool or privacy preserving rollup, the best option to ensure privacy is to withdraw the funds to a fresh address, meaning no previous transactions have been done on that address. However, without ETH for gas fee, the fresh address is not able to submit a transaction on-chain to withdraw funds.

We implement an ERC-4337 compatible paymaster that pays for the deployment of a smart account and the gas fee for the funds withdrawal. The user can generate the withdrawal proof as usual, then parse this proof to be the paymaster data in the correct format. Subsequently, the user then submits a UserOp operation for the bundler to execute the transaction.

### Getting Started

1. To compile the contracts, run `forge build`. 
2. To run the contracts, run `forge test`.
3. To deploy the contracts, run `forge create --rpc-url <your_rpc_url> --private-key <your_private_key> src/PrivatePaymaster.sol:PrivatePaymaster`.

The `cli` folder contains scripts to generate the paymaster data to be included in the UserOp.

### Deployed Addresses

Test contracts are deployed on the Sepolia testnet:
1. MockToken: `0xA76AE5A1BE9BCd287e884Cc39C4Dd0EBfecc0E7c`
2. MockMixer: `0xA836380122e58Dff60D3404d8994671b0eF6CCd8`
3. PrivatePaymaster: `0x08fbF62FE4973C36550F7dD71757e9ECb63b137E`

Other deployments of PrivatePaymaster to support the multichain future: 
1. Optimism Goerli: `0x5B21e28119069aED609595c99Cb78f5dfE2DC004`
2. Polygon Mumbai: `0x27d4D43e89FB920F063Df7Bf711bfc48c3dAfF5F`
3. Gnosis Chain: `0xEFfDC753F92D784ff0A51EB43e191dD7aB13DB9a`
4. Linea: `0xEFfDC753F92D784ff0A51EB43e191dD7aB13DB9a`

### Trampoline Fork
https://github.com/eerkaijun/trampoline
