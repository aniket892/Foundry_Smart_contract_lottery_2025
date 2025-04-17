//SPDX-License-Identifier:MIT
pragma solidity 0.8.19;

import {Script,console} from "lib/forge-std/src/Script.sol";
import {HelperConfig,CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script, CodeConstants{

    /////Event//////
    event creatingSubscription();

    function createSubscriptionUsingConfig() public returns (uint256 , address ) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        //create subscription
        (uint256 subID, ) = createSubscriptions(vrfCoordinator , account);
        return (subID ,  vrfCoordinator);
    }

    function createSubscriptions(address vrfCoordinator , address account) public returns (uint256 , address ){
        console.log("Creating Subscription on chain Id: ", block.chainid);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();//this line will make a subscription by vrfcoordinator
        vm.stopBroadcast();
        
        console.log("Your Subscription ID: ",subId);
        console.log("Please update the subscription Id in Your HelperConfig.s.sol");

        return (subId , vrfCoordinator );
    }
    function run() public  {
        createSubscriptionUsingConfig();
    }
    
}

contract FundSubscription is Script,CodeConstants {
     uint256 public constant FUND_AMOUNT = 300 ether;//3 links
    
    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionID;
        address linkToken = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;
        fundSubscription( vrfCoordinator, subscriptionId, linkToken, account);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken , address account) public {
        //we are going to fund that subscription
        console.log("Funding Subscription: ",subscriptionId);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainID: ",block.chainid);

        if(block.chainid == LOCAL_CHAINID)// I want to check the console.log does give any output or not
        {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        }
        else{
            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall( vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script{

    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subID = helperConfig.getConfig().subscriptionID;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        addConsumer( mostRecentlyDeployed, vrfCoordinator, subID, account);
    }

    function addConsumer( address contractToAddToVrf, address vrfCoordinator , uint256 subID, address account) public {
        console.log("Adding consumer contract: ", contractToAddToVrf);
        console.log("To vrfCoordinator: ",vrfCoordinator);
        console.log("On chainID: ",block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subID , contractToAddToVrf);
        vm.stopBroadcast();
    }
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle",block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}