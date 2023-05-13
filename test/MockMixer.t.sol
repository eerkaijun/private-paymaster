// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/MockMixer.sol";
import "../src/MockToken.sol";

contract MockMixerTest is Test {
    MockMixer public mixer;
    MockToken public token;

    uint256 amount = 10 ether;

    // personal address with 0 balance for testing purposes :-D
    address recipientAddress = 0x6201df57Cb9f15B1232cF333a78926A303f6Bbac;

    function setUp() public {
        token = new MockToken("USDC", "USDC");
        mixer = new MockMixer(address(token));
        token.mint(address(mixer), amount);
    }

    function testWithdraw() public {
        assertEq(token.balanceOf(address(mixer)), amount);

        // form a Proof struct (extAmount and recipient)
        // instantiate a sample Proof with random values
        bytes memory proof = "0x00";
        bytes32 root = bytes32("0x01");
        bytes32[2] memory inputNullifiers = [bytes32("0x02"), bytes32("0x03")];
        bytes32[2] memory outputCommitments = [bytes32("0x04"), bytes32("0x05")];
        int256 extAmount = (-9 ether);
        
        MockMixer.Proof memory proofArgs = MockMixer.Proof(proof, root, inputNullifiers, outputCommitments, recipientAddress, extAmount);

        // pass the struct to the "transact" function
        mixer.transact(proofArgs);

        // make assertion that balance increase correctly
        assertEq(token.balanceOf(address(recipientAddress)), uint256(-extAmount));
    }
    

}
