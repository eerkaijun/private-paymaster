// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockMixer {
    mapping(bytes32 => bool) public nullifierHashes;
    ERC20 token;

    struct Proof {
        bytes proof;
        bytes32 root;
        bytes32[2] inputNullifiers;
        bytes32[2] outputCommitments;
        address recipient; // smart account address that we want to deploy
        int256 extAmount; // amount to withdraw
    }

    constructor(address _tokenAddress) {
        token = ERC20(_tokenAddress);
    }

    // public function to allow users to submit proofs
    function transact(Proof calldata _proof) public virtual {
        // Deposit functionality
        if (_proof.extAmount > 0) {
            token.transferFrom(
                msg.sender,
                address(this),
                uint256(_proof.extAmount)
            );
        }

        _transact(_proof);

        // Withdrawal functionality
        if (_proof.extAmount < 0) {
            require(
                _proof.recipient != address(0),
                "Can't withdraw to zero address"
            );

            token.transfer(
                _proof.recipient,
                uint256(_proof.extAmount)
            );
        }
    }

    function _transact(Proof calldata _proof) internal {
        for (uint256 i = 0; i < _proof.inputNullifiers.length; i++) {
            require(
                !isSpent(_proof.inputNullifiers[i]),
                "Input is already spent"
            );
        }

        require(
            _verifyProof(_proof.proof),
            "Invalid proof"
        );

        for (uint256 i = 0; i < _proof.inputNullifiers.length; i++) {
            nullifierHashes[_proof.inputNullifiers[i]] = true;
        }

        _insert(
            _proof.outputCommitments[0],
            _proof.outputCommitments[1]
        );
    }

    /** @dev whether a note is already spent */
    function isSpent(bytes32 _nullifierHash) public view returns (bool) {
        return nullifierHashes[_nullifierHash];
    }

    function _verifyProof(bytes calldata _proof) internal view returns (bool) {
        /// @dev We are just mocking this mixer, so we don't actually implement the proof verification
        /// @dev This function should return ZK proof verification logic
        return true;
    }

    function _insert(bytes32 _outputCommitment1, bytes32 _outputCommitment2) internal {
        /// @dev We are just mocking this mixer, so we don't actually implement the merkle tree
        /// @dev This function should insert the output commitments into the merkle tree
    }
}