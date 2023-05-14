// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BasePaymaster } from "account-abstraction/core/BasePaymaster.sol";
import { IEntryPoint } from "account-abstraction/interfaces/IEntryPoint.sol";
import { UserOperation } from "account-abstraction/interfaces/UserOperation.sol";
import "account-abstraction/core/Helpers.sol";

interface ITornadoInstance {
  function token() external view returns (address);

  function denomination() external view returns (uint256);

  function deposit(bytes32 commitment) external payable;

  function withdraw(
    bytes calldata proof,
    bytes32 root,
    bytes32 nullifierHash,
    address payable recipient,
    address payable relayer,
    uint256 fee,
    uint256 refund
  ) external payable;
}


contract TestPaymaster is BasePaymaster {    
    ITornadoInstance public constant TORNADO_INSTANCE = ITornadoInstance(0x6Bf694a291DF3FeC1f7e69701E3ab6c592435Ae7);
    uint256 public constant PAYMASTER_FEE = 10000000000000000; // 0.01 ETH

    constructor(IEntryPoint _entryPoint, address _owner) BasePaymaster(_entryPoint) {
        _transferOwnership(_owner);
    }

    event Received(address, uint);
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function withdrawETH(address payable recipient) public {
        require(owner() == msg.sender, "only owner can withdraw eth");
        recipient.transfer(address(this).balance);
    }


    /**
     * Verify our external signer signed this request and decode paymasterData
     * paymasterData contains the following:
     * token address length 20
     * signature length 64 or 65
     */
    function _validatePaymasterUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 maxCost)
    internal virtual override returns (bytes memory context, uint256 validationData){
        (userOpHash);
        bytes32 root = bytes32(userOp.paymasterAndData[20:52]);
        bytes32 nullifierHash = bytes32(userOp.paymasterAndData[52:84]);
        bytes memory proof = bytes(userOp.paymasterAndData[84:]);
        //
        address account = userOp.sender;
        bytes memory _context = abi.encode(account);

        try TORNADO_INSTANCE.withdraw(
            proof,
            root,
            nullifierHash,
            payable(address(this)),
            payable(address(this)),
            0,
            0
        ){
            return (_context, _packValidationData(false, 0, 0));
        } catch {
            return ("", _packValidationData(true, 0, 0));
        }
        return (_context, _packValidationData(false, 0, 0));
    }

    /**
     * Perform the post-operation to charge the sender for the gas.
     */
    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost) internal override {
        if (mode != PostOpMode.postOpReverted) {
            (address account) = abi.decode(context, (address));
            uint256 amount = TORNADO_INSTANCE.denomination() - PAYMASTER_FEE;
            (bool success, ) = payable(account).call{ value: amount }("");
            require(success, "error");
        }
    }
}