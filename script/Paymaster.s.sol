// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/MockToken.sol";

contract PaymasterScript is Script {
    MockToken public token;

    function setUp() public {
        token = MockToken(0xA76AE5A1BE9BCd287e884Cc39C4Dd0EBfecc0E7c);
    }

    function run() public {
        vm.broadcast(vm.envUint("PRIVATE_KEY"));
        // mint 10 ether to MockMixer
        token.mint(0xA836380122e58Dff60D3404d8994671b0eF6CCd8, 10 ether);
    }
}
