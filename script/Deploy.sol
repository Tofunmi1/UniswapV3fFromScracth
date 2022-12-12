//// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../lib/forge-std/src/Script.sol";
import "../lib/solmate/src/tokens/ERC20.sol";

contract Deploy is Script {
    function run() public {
        uint256 wethBalance = 1 ether;
        uint256 usdcBalance = 5042 ether;
        int24 currentTick = 85176;
        uint160 currentSqrtP = 5602277097478614198912276234240;
        vm.startBroadcast();
        vm.stopBroadcast();
    }
}
