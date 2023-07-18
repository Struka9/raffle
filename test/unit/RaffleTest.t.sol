// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DeployRaffle} from "../../script/Raffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {console, Test} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {Vm} from "forge-std/Vm.sol";

contract RaffleTest is Test {
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address linkToken;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            linkToken,

        ) = helperConfig.activeNetworkConfig();

        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitializedInOpenState() external view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /////////////////////////////
    ///// enterRaffle //////////
    ///////////////////////////
    function testRaffleRevertsWhenYouDontPayEnough() external {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnougEth.selector);
        raffle.enterRaffle{value: 0}();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() external {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        assertEq(raffle.getPlayer(0), PLAYER);
    }

    function testEmitsEventOnEntrance() external {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterWhenRaffleIsCalculating() external {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        // Change the timestamp
        vm.warp(block.timestamp + interval + 1);

        vm.prank(address(vrfCoordinator));
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    ////////////////////
    //// checkUpkeep //
    ////////////////////
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfItsNotOpen() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        raffle.performUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(upkeepNeeded);
    }

    ////////////////////////
    // performUpkeep ///////
    ////////////////////////
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfNoUpkeepNeeded() public {
        uint256 balance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                balance,
                numPlayers,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    event PickedWinner(address indexed winner);

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipIfNotLocal() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEnteredAndTimePassed
    {
        vm.recordLogs();
        raffle.performUpkeep("");

        Vm.Log[] memory recordedLogs = vm.getRecordedLogs();
        bytes32 requestId = recordedLogs[1].topics[1];
        assert(uint256(requestId) > 0);
    }

    //// fulfillRandomWords

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEnteredAndTimePassed skipIfNotLocal {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksWinnerResetsAndSendsMoney()
        public
        raffleEnteredAndTimePassed
        skipIfNotLocal
    {
        uint256 additionalEntrance = 5;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < additionalEntrance + startingIndex;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }

        vm.recordLogs();
        raffle.performUpkeep("");

        Vm.Log[] memory recordedLogs = vm.getRecordedLogs();
        bytes32 requestId = recordedLogs[1].topics[1];
        uint256 prize = address(raffle).balance;

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getLengthOfPlayers() == 0);
        assert(
            raffle.getRecentWinner().balance == 1 ether + prize - entranceFee
        );
    }
}
