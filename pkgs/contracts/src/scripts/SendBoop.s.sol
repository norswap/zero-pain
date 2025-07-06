// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.20;

import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { Encoding } from "boop/core/Encoding.sol";
import { Boop } from "boop/interfaces/Types.sol";
import { console } from "forge-std/console.sol";
import { MyOApp } from "./../messaging/MyOApp.sol";
import { BoopTestUtils } from "./BoopTestUtils.sol";

/// @title LayerZero OApp Message Sending Script
/// @notice Demonstrates how to send messages between OApp deployments
contract SendBoop is BoopTestUtils {
    using OptionsBuilder for bytes;

    function run() external {


//        string memory mocksDeploymentPath =
//                        string(abi.encodePacked("./deployments/", chainName, "/mocks/deployment.json"));
//        string memory mocksDeploymentJson = vm.readFile(mocksDeploymentPath);
//        address token = vm.parseJsonAddress(mocksDeploymentJson, "$.MockTokenA");
//
//        Boop memory _boop = createSignedBoopForMintToken(account, account, address(0), token, ctrlKey);
//        bytes memory boop = Encoding.encode(_boop);

        address oapp = vm.envAddress("OAPP_ADDRESS");
        address account = vm.envAddress("BOOP_ACCOUNT");
        address token = vm.envAddress("TOKEN_ADDRESS");
        uint256 privKey = vm.envUint("CONTROLLING_KEY");
        MyOApp _oapp = MyOApp(oapp);
        uint32 dstEid = uint32(vm.envUint("DST_EID"));
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(100_000, 0);

        // Mint with account, to account, payed by the submitter.
        Boop memory _boop = createSignedBoopForMintToken(account, account, address(0), token, privKey);
        bytes memory boop = Encoding.encode(_boop);

        // 1. Quote the gas cost first
        MessagingFee memory fee = _oapp.quoteSendString(dstEid, boop, options);

        console.log("Estimated native fee:", fee.nativeFee);
        console.log("Estimated LZ token fee:", fee.lzTokenFee);

        // 2. Send the message with the quoted fee
        vm.startBroadcast();
        _oapp.sendBoop{value: fee.nativeFee}(dstEid, boop, options);
        vm.stopBroadcast();

        console.log("Message sent successfully!");
    }
}
