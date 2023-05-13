// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BasePaymaster } from "account-abstraction/core/BasePaymaster.sol";
import { IEntryPoint } from "account-abstraction/interfaces/IEntryPoint.sol";
import { UserOperation } from "account-abstraction/interfaces/UserOperation.sol";
import { MockMixer } from "./MockMixer.sol";

contract PrivatePaymaster is BasePaymaster {

    uint256 public constant PAYMASTER_FEE = 0.01 ether;

    //calculated cost of the postOp
    uint256 constant public COST_OF_POST = 15000;

    MockMixer public mixer;

    constructor(address _mixerAddress, IEntryPoint _entryPoint) BasePaymaster(_entryPoint) {
        mixer = MockMixer(_mixerAddress);
    }

    /**
      * validate the request:
      * if this is a constructor call, make sure it is a known account.
      * verify the sender has enough tokens.
      * (since the paymaster is also the token, there is no notion of "approval")
      */
    function _validatePaymasterUserOp(UserOperation calldata userOp, bytes32 /*userOpHash*/, uint256 requiredPreFund)
    internal override returns (bytes memory context, uint256 validationData) {
        // decode proof sent to the mixer for withdrawal
        bytes32 root = bytes32(userOp.paymasterAndData[20:52]);
        bytes32[2] memory inputNullifiers = [bytes32(userOp.paymasterAndData[52:84]), bytes32(userOp.paymasterAndData[84:116])];
        bytes32[2] memory outputCommitments = [bytes32(userOp.paymasterAndData[116:148]), bytes32(userOp.paymasterAndData[148:180])];
        address recipient = address(bytes20(userOp.paymasterAndData[180:200]));
        int256 extAmount = abi.decode(userOp.paymasterAndData[200:232], (int256));
        bytes memory proof = bytes(userOp.paymasterAndData[232:]);
        
        address account = userOp.sender;
        bytes memory _context = abi.encode(account, extAmount);

        /// @dev should we use try catch statement here, or just let the transaction reverts if invalid proof is provided
        try mixer.transact(MockMixer.Proof(
            proof, 
            root, 
            inputNullifiers, 
            outputCommitments, 
            recipient, 
            extAmount
        )) {
            return (_context, 0);
        } catch {
            return ("", 0);
        }
    }

    /**
     * actual charge of user.
     * this method will be called just after the user's TX with mode==OpSucceeded|OpReverted (account pays in both cases)
     * BUT: if the user changed its balance in a way that will cause  postOp to revert, then it gets called again, after reverting
     * the user's TX , back to the state it was before the transaction started (before the validatePaymasterUserOp),
     * and the transaction should succeed there.
     */
    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost) internal override {
        // redeem gas fee
        if (mode != PostOpMode.postOpReverted) {
            (address account, int256 withdrawAmount) = abi.decode(context, (address, int256));
            uint256 amount = uint256(withdrawAmount) - PAYMASTER_FEE;
            (bool success, ) = payable(account).call{ value: amount }("");
            require(success, "error");
        }
    }
    
}
