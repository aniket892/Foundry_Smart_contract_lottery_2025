// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstants {
   
    /**VRF mock values */
    uint96 public Mock_baseFee = 0.25 ether; 
    uint96 public Mock_gasPrice = 1e9; 
    /**link / ETH price */
    int256 public Mock_weiPerUnitLink = 4e15;
    
    uint256 public constant SEPOLIA_CHAINID = 11155111;
    uint256 public constant LOCAL_CHAINID = 31337;
}

contract HelperConfig is CodeConstants, Script {

   /**errors */
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gaslane;
        uint256 subscriptionID;
        uint32 callbackGasLimit;
        address link;
        address account;
    }
    
    //local network state variables
    NetworkConfig public LocalNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor(){
        networkConfigs[SEPOLIA_CHAINID] = getSepoliaETHConfig();
    }
    
    function getConfig() public returns(NetworkConfig memory)
    {
        return getConfigByChainId(block.chainid);
    }

    function setConfig(
        uint256 chainId,
        NetworkConfig memory networkConfig
    ) public {
        networkConfigs[chainId] = networkConfig;
    }

    function getConfigByChainId(uint256 chainId) public returns(NetworkConfig memory)
    {
        if(networkConfigs[chainId].vrfCoordinator != address(0))//->address means here empty
        {
            return networkConfigs[chainId];
        }
        else if(chainId == LOCAL_CHAINID)
        {
            return getOrCreateAnvilETHconfig();
        }
        else{
            revert HelperConfig__InvalidChainId();
        }
    }

    function getSepoliaETHConfig() public pure returns(NetworkConfig memory) {
        return NetworkConfig(
            { 
                entranceFee: 0.01 ether,
                interval: 30, //30 seconds
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                gaslane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                subscriptionID: 0,
                callbackGasLimit: 500000,//gas
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                account: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
            }
        );
    }

    function getOrCreateAnvilETHconfig() public returns(NetworkConfig memory)
    {
        //check if we are already set to a netwokconfig
        if(LocalNetworkConfig.vrfCoordinator != address(0))
        {
            return LocalNetworkConfig;
        }

        //Deploy mocks
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock mockCoordinator = new VRFCoordinatorV2_5Mock(Mock_baseFee,Mock_gasPrice,Mock_weiPerUnitLink);//->deploying the mock contract
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        LocalNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
                interval: 30, //30 seconds
                vrfCoordinator: address(mockCoordinator),//->address of deployed mock contract
                gaslane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                subscriptionID: 0,
                callbackGasLimit: 500000,//gas
                link: address(linkToken),//?
                account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        });
        return LocalNetworkConfig;
    }
}
