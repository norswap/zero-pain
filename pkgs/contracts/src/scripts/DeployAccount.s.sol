// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.20;

import {Encoding} from "boop/core/Encoding.sol";
import {EntryPoint} from "boop/core/EntryPoint.sol";
import {Boop, ExtensionType} from "boop/interfaces/Types.sol";
import {console} from "forge-std/console.sol";
import {BoopTestUtils} from "./BoopTestUtils.sol";
import {HappyAccount} from "../boop/happychain/HappyAccount.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {HappyAccountBeaconProxyFactory} from "boop/happychain/factories/HappyAccountBeaconProxyFactory.sol";

contract DeployAccount is BoopTestUtils {
    bytes32 private constant SALT = bytes32(0);

    function run() external {
        vm.startBroadcast();
        string memory chainName = vm.envString("CHAIN_NAME");
        string memory boopDeploymentPath =
            string(abi.encodePacked("./deployments/", chainName, "/boop/deployment.json"));
        string memory boopDeploymentJson = vm.readFile(boopDeploymentPath);

        address _accountFactory = vm.parseJsonAddress(boopDeploymentJson, "$.HappyAccountBeaconProxyFactory");
        HappyAccountBeaconProxyFactory accountFactory = HappyAccountBeaconProxyFactory(_accountFactory);
        address crossChainValidator = vm.parseJsonAddress(boopDeploymentJson, "$.CrossChainValidator");
        address _entryPoint = vm.parseJsonAddress(boopDeploymentJson, "$.EntryPoint");
        entryPoint = EntryPoint(_entryPoint);

        string memory msgingDeploymentPath =
                        string(abi.encodePacked("./deployments/", chainName, "/messaging/deployment.json"));
        string memory msgingDeploymentJson = vm.readFile(msgingDeploymentPath);
        address oapp = vm.parseJsonAddress(msgingDeploymentJson, "$.MyOApp");

        (address ctrlAddr, uint256 ctrlKey) = makeAddrAndKey("ctrl-foobar-4");
        address account = accountFactory.createAccount(SALT, ctrlAddr);

        console.log("account address", account);
        console.log("controlling address", ctrlAddr);
        console.log("controlling private key", ctrlKey);

        bytes memory installData = abi.encodeWithSignature("authorizeOApp(address)", oapp);
        Boop memory _boop =
            createSignedBoopForAddExtension(account, crossChainValidator, ExtensionType.Validator, installData, ctrlKey);
        bytes memory boop = Encoding.encode(_boop);

        entryPoint.submit(boop);
        vm.stopBroadcast();
    }
}
