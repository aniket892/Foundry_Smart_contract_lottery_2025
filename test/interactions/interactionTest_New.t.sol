//SPDX-License-Identifier:MIT
pragma solidity 0.8.19;

import {Test,console} from "forge-std/Test.sol";
import {CreateSubscription,FundSubscription,AddConsumer} from "script/Interactions.s.sol"; 
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig , CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

//Finish this in btw 2 days
contract InteractionTest_New is Test, FundSubscription{
     
    CreateSubscription createSub;
    FundSubscription fundSub;
    AddConsumer addcon;
    HelperConfig helperConfig;
    LinkToken linkToken;

    address vrf;
    address link;
    address account;
    uint256 subID;

    function setUp() public 
    {
        createSub = new CreateSubscription();
        fundSub = new FundSubscription();
        addcon = new AddConsumer();
        helperConfig = new HelperConfig();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        vrf = config.vrfCoordinator;
        link = config.link;
        account = config.account;
        subID = config.subscriptionID;
    }

    /*///////////////////////////
    createSubscriptionUsingConfig
    ///////////////////////////*/
    
    function testcreateSubscriptionUsingConfigCoversLogic() public {
    (uint256 returnedSubId,) = createSub.createSubscriptionUsingConfig();

    // check: subscription created
    assert(returnedSubId != 0);
    }
 
     /*///////////////////////////
        createSubscriptions
    ///////////////////////////*/
    function testcreateSubscriptions() public {
        (uint256 SubId,) = createSub.createSubscriptions(vrf, account);

        // check: subscription created
        assert(SubId != 0);
    }


    /*///////////////////////////
        fundSubscription
    ///////////////////////////*/
    function testfundSubscriptionActuallyWorks() public {
        
       // STEP 1: Create subscription
    (uint256 SubId, ) = createSub.createSubscriptions(vrf, account);
    (uint96 InitialBalance,, , ,) = VRFCoordinatorV2_5Mock(vrf).getSubscription(SubId);


    // STEP 2: Deal LINK to account (simulate LINK ownership)
    //vm.deal(account, 10 ether); // Give native ETH to pay gas (optional)

    // STEP 3: Approve transfer (optional depending on mock)
    //linkToken = LinkToken(link);

    // The default sender (who deployed LinkToken) owns the LINK
    // address defaultSender = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    // vm.prank(defaultSender);
    // linkToken.transfer(account, 500 ether);

    // STEP 4: Fund the subscription
    fundSub.fundSubscription(vrf, SubId, link, account);
    

    // STEP 5: Assert balance is increased in the VRFCoordinator mock
    (uint96 FinalBalance,, , ,) = VRFCoordinatorV2_5Mock(vrf).getSubscription(SubId);
    console.log("Final Balance in Subscription: ", FinalBalance);

    assertEq(FinalBalance, InitialBalance + FUND_AMOUNT, "Funding failed: balance mismatch");
    }
}