// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {MyOApp} from "./../MyOApp.sol";
import {BaseDeployScript} from "./BaseDeployScript.sol";

contract DeployOApp is BaseDeployScript {
    bytes32 private constant DEPLOYMENT_SALT = bytes32(uint256(0));
    uint32 private constant EXECUTOR_CONFIG_TYPE = 1;
    uint32 private constant ULN_CONFIG_TYPE = 2;

    function deploy() internal override {
        address endpoint = vm.envAddress("ENDPOINT_ADDRESS");
        address sendLib = vm.envAddress("SEND_LIB_ADDRESS");
        address receiveLib = vm.envAddress("RECEIVE_LIB_ADDRESS");

        address owner = vm.envAddress("OWNER_ADDRESS");
        (address oapp,) =
            deployDeterministic("MyOApp", type(MyOApp).creationCode, abi.encode(endpoint, owner), DEPLOYMENT_SALT);
        MyOApp _oapp = MyOApp(oapp);

        uint32 srcEid = uint32(vm.envUint("SRC_EID"));
        uint32 dstEid = uint32(vm.envUint("DST_EID"));
        uint32 gracePeriod = uint32(vm.envUint("GRACE_PERIOD"));

        // Set send library for outbound messages.
        ILayerZeroEndpointV2(endpoint).setSendLibrary(oapp, dstEid, sendLib);

        // Set receive library for inbound messages.
        // TODO Is this correct? (we're passing current chain EID — should we pass the remote chain EID?)
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(oapp, srcEid, receiveLib, gracePeriod);

        // ### Send Configuration (A → B) ###
        // This doesn't work (`setConfig` is not a thing), but might not be needed if defaults are fine.

        //        address[] memory empty;
        //        address[] memory requiredDVNs = new address[](1);
        //        requiredDVNs[0] = vm.envAddress("LZ_DVN_ADDRESS");
        //
        //        // UlnConfig defines security parameters (DVNs + confirmation threshold) for A → B
        //        // Send config requests these settings to be applied to the DVNs and Executor for messages sent from A to B.
        //        // Zero values will be interpretted as defaults, so to apply NIL settings, use max value for type.
        //        UlnConfig memory uln = UlnConfig({
        //            // minimum block confirmations required on A before sending to B
        //            confirmations: 15,
        //            requiredDVNCount: 1,
        //            optionalDVNCount: type(uint8).max,
        //            // optional DVN threshold
        //            optionalDVNThreshold: 0,
        //            // sorted list of required DVN addresses
        //            requiredDVNs: requiredDVNs,
        //            // sorted list of optional DVNs
        //            optionalDVNs: empty
        //        });
        //
        //        // ExecutorConfig sets message size limit + fee‑paying executor for A → B
        //        ExecutorConfig memory exec = ExecutorConfig({
        //            // max bytes per cross-chain message
        //            maxMessageSize: 10000,
        //            // address that pays destination execution fees on B
        //            executor: owner
        //        });
        //
        //        bytes memory encodedUln = abi.encode(uln);
        //        bytes memory encodedExec = abi.encode(exec);
        //
        //        SetConfigParam[] memory params = new SetConfigParam[](2);
        //        params[0] = SetConfigParam(dstEid, EXECUTOR_CONFIG_TYPE, encodedExec);
        //        params[1] = SetConfigParam(dstEid, ULN_CONFIG_TYPE, encodedUln);
        //
        //        // Set config for messages sent from A to B
        //        ILayerZeroEndpointV2(endpoint).setConfig(oapp, sendLib, params);

        // Assume the peer is the same OApp with same owner, deployed on the remote chain with the remote endpoint.
        address remoteEndpoint = vm.envAddress("REMOTE_ENDPOINT_ADDRESS");
        address peer = getCreate2Address(type(MyOApp).creationCode, abi.encode(owner, remoteEndpoint), DEPLOYMENT_SALT);

        // Set peer for remote chain.
        _oapp.setPeer(dstEid, bytes32(uint256(uint160(peer))));
    }
}
