// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateSubscription,FundSubscription,AddConsumer} from "script/Interactions.s.sol";


contract DeployRaffle is Script{
    function run() public {
            deployContract();
    }
    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperconfig = new HelperConfig(); 
        //local -> deploy mocks, get local config
        //sepolia -> getSepoliaETHConfig
        HelperConfig.NetworkConfig memory config = helperconfig.getConfig();

        if(config.subscriptionID == 0)//-> if you dont have any subscription id
        {
            //create subscription
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionID , config.vrfCoordinator) = createSubscription.createSubscriptions(config.vrfCoordinator , config.account);

            //fund it
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(config.vrfCoordinator, config.subscriptionID, config.link , config.account);
        }

        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gaslane,
            config.subscriptionID,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        //we have to add a consumer
        AddConsumer addConsumer = new AddConsumer();
        //don't need to boradcast
        addConsumer.addConsumer(address(raffle) , config.vrfCoordinator, config.subscriptionID , config.account);

        return (raffle, helperconfig);
    }
}