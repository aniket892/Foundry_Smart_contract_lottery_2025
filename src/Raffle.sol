// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

//SPDX-License-Identifier:MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
/**
 * @title   A smart Raffle contract
 * @author  Aniket Biswas
 * @notice  This contract is for creating a sample raffle
 * @dev     Implements Chinlink VRFv2.5
 */

contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__SendMoretoEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotneeded(uint256 balance, uint256 Playerslength, uint256 raffleState);

    //      struct RandomWordsRequest {
    //     bytes32 keyHash;
    //     uint256 subId;
    //     uint16 requestConfirmations;  -> this the struct of the VRF2PlusClient.sol
    //     uint32 callbackGasLimit;
    //     uint32 numWords;
    //     bytes extraArgs;
    //   }

    /*type declaration*/
    enum RaffleState {
        OPEN, //0
        CALCULATING //1
    }

    /*state variables*/
    uint16 private constant REQUEST_CONFORMATION = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    //@dev The duration of lottery in seconds
    uint256 private immutable i_interval; //-> interval btw the lottery rounds
    bytes32 private immutable i_keyhash;
    uint256 private immutable i_subscriptionID;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /*events */
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestID);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gaslane,
        uint256 subscriptionID,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        //??
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyhash = gaslane;
        i_subscriptionID = subscriptionID;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN; //or RaffleState(0)
    }

    function enterRaffle() external payable {
        //external to be more gas efficient
        //require(msg.value >= i_entranceFee, "Not enough ETH sent!");->this one is not so gas efficient bco'z of the string
        // require(msg.value >= i_entranceFee,SendMoretoEnterRaffle());->this one is available to very specfic version of solidity and compiler
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoretoEnterRaffle();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender)); //we need this payable keyword , to the msg.sender receives ETH

        emit RaffleEnter(msg.sender);
    }

    //when should the winner be picked?
    /**
     * @dev This is the function the chainlink nodes will call to see if the lottery is ready 
     * to pick a winner
     * The following should be true in order to for upkeepNeeded to be true:
     * 1.The time intreval has passed btw the Raffle runs
     * 2.The lottery is open
     * 3.The contract has ETH(The Raffle contract has Players )
     * 4.Implicitlly , your subscription has LINK
     * @param -ignored
     * @return upkeepNeeded ->true if it is time to return the lottery
     * @return -ignored
     */
    function checkUpkeep(bytes memory) public view returns (bool upkeepNeeded, bytes memory) {
        bool timehasPassed = (block.timestamp - s_lastTimeStamp) > i_interval;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;

        upkeepNeeded = timehasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    //1. Get a random number
    //2. Use random number to pick a player
    //3. Be automatically called
    function performUpkeep(bytes calldata) external {
        //check to see if enough time has passed
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotneeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        s_raffleState = RaffleState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyhash,
            subId: i_subscriptionID,
            requestConfirmations: REQUEST_CONFORMATION,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });
        uint256 requestID =  s_vrfCoordinator.requestRandomWords(request);
        emit RequestedRaffleWinner(requestID);
    }

    //CEI: Checks , Effects, Interaction Patterns
    function fulfillRandomWords(uint256 /*requestId*/, uint256[] calldata randomWords) internal override {
        //check

        //Effect (Intrenal Contract State)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN; //-> re opening the raffle after picking up the winner is done
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);

        //Interaction (External Contract Interactions)
        (bool success,) = recentWinner.call{value: address(this).balance}(""); //??
        if (!success){
            revert Raffle__TransferFailed();
        }
    }

    /**
     * Getter Function
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState)
    {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address)
    {
        return s_players[indexOfPlayer];
    }
    function getPlayerArrayLength() external view returns (uint256) 
    {
        return s_players.length;
    }
    function getLastTimeStamp() public view returns(uint256) {
        return s_lastTimeStamp;
    }
    function getRecentWinner() public view returns(address) {
        return s_recentWinner;
    }

}
