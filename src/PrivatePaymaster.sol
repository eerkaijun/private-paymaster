// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BasePaymaster } from "account-abstraction/core/BasePaymaster.sol";
import { IEntryPoint } from "account-abstraction/interfaces/IEntryPoint.sol";
import { UserOperation } from "account-abstraction/interfaces/UserOperation.sol";

contract PrivatePaymaster is BasePaymaster {

    //calculated cost of the postOp
    uint256 constant public COST_OF_POST = 15000;

    address public immutable theFactory;

    constructor(address accountFactory, IEntryPoint _entryPoint) BasePaymaster(_entryPoint) {
        theFactory = accountFactory;
    }

    /**
      * validate the request:
      * if this is a constructor call, make sure it is a known account.
      * verify the sender has enough tokens.
      * (since the paymaster is also the token, there is no notion of "approval")
      */
    function _validatePaymasterUserOp(UserOperation calldata userOp, bytes32 /*userOpHash*/, uint256 requiredPreFund)
    internal view override returns (bytes memory context, uint256 validationData) {
        
    }

    // when constructing an account, validate constructor code and parameters
    // we trust our factory (and that it doesn't have any other public methods)
    function _validateConstructor(UserOperation calldata userOp) internal virtual view {
        address factory = address(bytes20(userOp.initCode[0 : 20]));
        require(factory == theFactory, "TokenPaymaster: wrong account factory");
    }

    /**
     * actual charge of user.
     * this method will be called just after the user's TX with mode==OpSucceeded|OpReverted (account pays in both cases)
     * BUT: if the user changed its balance in a way that will cause  postOp to revert, then it gets called again, after reverting
     * the user's TX , back to the state it was before the transaction started (before the validatePaymasterUserOp),
     * and the transaction should succeed there.
     */
    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost) internal override {

    }
    
}
