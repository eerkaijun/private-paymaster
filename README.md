# private-paymaster

When users withdraw funds from a shielded pool or privacy preserving rollup, the best option to ensure privacy is to withdraw the funds to a fresh address, meaning no previous transactions have been done on that address. However, without ETH for gas fee, the fresh address is not able to submit a transaction on-chain to withdraw funds.

We implement an ERC-4337 compatible paymaster that pays for the deployment of a smart account and the gas fee for the funds withdrawal. The user can then submit a UserOp operation for the bundler to execute the transaction.
