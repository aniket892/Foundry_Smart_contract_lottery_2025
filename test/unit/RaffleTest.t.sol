// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {Test,console} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "lib/forge-std/src/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";

contract RaffleTest is Test,CodeConstants {
    //state variables
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gaslane;
    uint256 subscriptionID;
    uint32 callbackGasLimit;

    //address linkToken;
    
    address public PLAYER = makeAddr("player");
    uint256 public constant STARING_PLAYER_BALANCE = 10 ether;

    /////////// EVENTS ///////////
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed winner);

   /////////// MODIFIER ///////////
    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number +1);
        _;
    }

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        vm.deal(PLAYER,STARING_PLAYER_BALANCE);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gaslane = config.gaslane;
        subscriptionID = config.subscriptionID;
        callbackGasLimit = config.callbackGasLimit;
        //linkToken = config.link;
    }

    function testRaffleRevert_DontPayEnoughETH() public {
        //Arrange 
        vm.prank(PLAYER);
        //Act/Assert
        vm.expectRevert(Raffle.Raffle__SendMoretoEnterRaffle.selector);//selector??
        raffle.enterRaffle();//will not enter the raffle bco'z we are not sending any entrance fee-> enterRaffle{value: entranceFee}()
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        //Arrange
        vm.prank(PLAYER);// our PLAYER is going to enter the raffle
        //Act
        raffle.enterRaffle{value: entranceFee}();
        //Assert
        address playerRecorded = raffle.getPlayer(0);
        assertEq(playerRecorded, PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        //Arrange
        vm.prank(PLAYER);
        //Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEnter(PLAYER);
        //Assrt
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterIntoRaffleWhileCalculating() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();//to check enough time has passed we are gonna use some cheatcodes
        vm.warp(block.timestamp + interval +1);//->we will change the blocktime
        vm.roll(block.number +1);//->we will change the block number
        raffle.performUpkeep("");//->to close the Raffle

        //Act/Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /////////////CHECK UPKEEP/////////////////
 
    function testCheckUpkeepIfItDoesNotHaveAnyBalance() public {

        //Arrange
        vm.warp(block.timestamp + interval +1);//??
        vm.roll(block.number +1);//??

        //Act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");//"" means here 1 argument without mentioning it

        //Assert->the assert should return false bco'z we did not enter the raffle
        assert(upKeepNeeded == false);
    }

    function testCheckIfRaffleIsOpen() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number +1);
        raffle.performUpkeep("");

        //Act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        //Assert
        assert(upKeepNeeded == false);
    }

    /////CHALLENGE/////
    //CHECK -> RAFFLE->CHECKUPKEEP FUNCTION'S TIMEHASPASSED, AND UPKEEPNEEDED IS TRUE OR NOT IF REQUIRED CONDITION IS MET 
    function testCheckUpKeepReturnsFalseWhenEnoughTimeIsNotPassed() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepNeededReturnsTrue_WhenAllConditionsAreMet() public {
                //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number +1);
        //raffle.performUpkeep("");

        //Act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        console.log(upKeepNeeded);

        //Assert
        assert(upKeepNeeded);
    }
    ////////////////PERFORM UPKEEP///////////////
    
    function testPerformUpkeepIsOnlyRunsWhenUpkeepNeededIsTrue() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number +1);
        
        //Act/Assert
        //vm.expectRevert(Raffle.Raffle__UpkeepNotneeded.selector);
        raffle.performUpkeep("");
    }
    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        //Arrange
        uint256 currentBalance = 0;
        uint256 currentPlayer = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        currentPlayer = 1;
        //Act / Assert
        //abi.encodeWithSelector(CustomError.selector, 1, 2)
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotneeded.selector, currentBalance, currentPlayer, rState)//-> expectRevert for custom errors with parameters
        );
        raffle.performUpkeep("");
    }

    // what if we need to get data from emitted events in our tests?
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestID() public raffleEntered {//Well it is a pretty advanced test, we use Vm not vm , from Vm.sol

        //Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestID = entries[1].topics[1];//??

        //Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestID) > 0);
        assert(uint256(raffleState) == 1);
    }

                              /*////////////////////////////
                                   FulFillRandomWords
                              ///////////////////////////*/

    modifier skipFrok() {
        if(block.chainid != LOCAL_CHAINID)
        {
            return;
        }
        _;
    }
    function testFulfillrandomWords_CanOnlyBeCalledAfter_PerformUpkeep(uint256 requestID) public raffleEntered skipFrok{//Intro To Fuzz testing 
        //Act /Arrange /assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(requestID, address(raffle));
    }
    
    function testFulfillrandomWordsPicksAWinnerAndSendsMoney() public raffleEntered  skipFrok{
        //Arrange
        uint256 addtionalPlayers = 3;
        uint256 startingIndex = 1;
        address exxpectedWinner = address(1);
        
        for(uint256 i = startingIndex; i <= addtionalPlayers; i++)//Adding some additional Players
        {
            address newPlayer = address(uint160(i));// address(2) or address(1)
            hoax(newPlayer , 1 ether);
            raffle.enterRaffle{value : entranceFee}();
        }
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = exxpectedWinner.balance;

        //Act
        vm.recordLogs();//??
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();//??
        bytes32 requestID = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestID), address(raffle));

        //Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (addtionalPlayers+1);

        assert(recentWinner == exxpectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert( endingTimeStamp > startingTimeStamp );
    }
    //////////// LINKTOKEN BALANCE/////////////
    
}