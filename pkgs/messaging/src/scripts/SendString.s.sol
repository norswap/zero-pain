// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { MyOApp } from "../MyOApp.sol";
import { MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

/// @title LayerZero OApp Message Sending Script
/// @notice Demonstrates how to send messages between OApp deployments
contract SendMessage is Script {
    using OptionsBuilder for bytes;

    function run() external {
        address oapp = vm.envAddress("OAPP_ADDRESS");
        MyOApp _oapp = MyOApp(oapp);
        uint32 dstEid = uint32(vm.envUint("DST_EID"));
        string memory message = "Hello World";
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(100_000, 0);

        // 1. Quote the gas cost first
        MessagingFee memory fee = _oapp.quoteSendString(
            dstEid,
            message,
            options,
            false // Pay in native gas, not ZRO tokens
        );

        console.log("Estimated native fee:", fee.nativeFee);
        console.log("Estimated LZ token fee:", fee.lzTokenFee);

        // 2. Send the message with the quoted fee
        vm.startBroadcast();
        _oapp.sendString{value: fee.nativeFee}(
            dstEid,
            message,
            options
        );
        vm.stopBroadcast();

        console.log("Message sent successfully!");
    }
}