// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {Script} from "forge-std/Script.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    uint256 constant DEFAULT_ANVIL_PK =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address linkToken;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            // Sepolia testnet
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function run() external {}

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 30,
                vrfCoordinator: address(
                    0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
                ),
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscriptionId: 3745,
                callbackGasLimit: 500000,
                linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                deployerKey: vm.envUint("SEPOLIA_PK")
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        uint96 baseFee = 0.25 ether; // 0.25 link
        uint96 gasPriceLink = 1e9; // 1gwei LINK

        vm.startBroadcast();
        LinkToken link = new LinkToken();
        VRFCoordinatorV2Mock mock = new VRFCoordinatorV2Mock(
            baseFee,
            gasPriceLink
        );
        vm.stopBroadcast();

        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 30,
                vrfCoordinator: address(mock),
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscriptionId: 0,
                callbackGasLimit: 500000,
                linkToken: address(link),
                deployerKey: DEFAULT_ANVIL_PK
            });
    }
}
