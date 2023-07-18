// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, , , , , uint256 deployerKey) = helperConfig
            .activeNetworkConfig();
        return createSubscription(vrfCoordinator, deployerKey);
    }

    function createSubscription(
        address vrfCoordinator,
        uint256 deployerKey
    ) public returns (uint64) {
        VRFCoordinatorV2Mock vrfCoordinatorMock = VRFCoordinatorV2Mock(
            vrfCoordinator
        );
        console.log("creating subscription on chain: ", block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 subId = vrfCoordinatorMock.createSubscription();
        vm.stopBroadcast();

        console.log("created subscription with id: ", subId);
        return subId;
    }

    function run() external returns (uint64) {}
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() internal {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subscriptionId,
            ,
            address linkToken,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        fundSubscription(
            vrfCoordinator,
            linkToken,
            subscriptionId,
            deployerKey
        );
    }

    function fundSubscription(
        address vrfCoordinator,
        address link,
        uint64 subId,
        uint256 deployerKey
    ) public {
        console.log("funding subscription: ", subId);
        console.log("using vrfCoordinator: ", vrfCoordinator);
        console.log("on chainId: ", block.chainid);

        if (block.chainid == 31337) {
            // Local blockchain
            vm.startBroadcast();
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerWithConfig(address raffle) internal {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subscriptionId,
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        addConsumer(raffle, vrfCoordinator, subscriptionId, deployerKey);
    }

    function addConsumer(
        address raffle,
        address vrfCoordinator,
        uint64 subId,
        uint256 deployerKey
    ) public {
        console.log("adding consumer contract: ", raffle);
        console.log("on chain: ", block.chainid);

        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerWithConfig(raffle);
    }
}
