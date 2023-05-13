// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/MockMixer.sol";
import "../src/MockToken.sol";

contract MockMixerTest is Test {
    MockMixer public mixer;
    MockToken public token;

    uint256 amount = 10 ether;

    function setUp() public {
        token = new MockToken();
        mixer = new MockMixer(address(token));
        token.mint(address(mixer), amount);
    }

    function testWithdraw() public {
        assertEq(token.balanceOf(address(mixer)), amount);

        // TODO: form a Proof struct (extAmount and recipient)

        // TODO: pass the struct to the "transact" function

        // TODO: make assertion that balance increase correctly
    }
    

}
