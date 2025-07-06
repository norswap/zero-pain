// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.20;

import {Boop, ExtensionType} from "boop/interfaces/Types.sol";
import {Encoding} from "boop/core/Encoding.sol";
import {EntryPoint} from "boop/core/EntryPoint.sol";
import {MockERC20} from "src/mocks/MockERC20.sol";
import {Script} from "forge-std/Script.sol";
import {Utils} from "boop/core/Utils.sol";
import {HappyAccount} from "boop/happychain/HappyAccount.sol";

//import {console} from "forge-std/console.sol";

/// Common utility functions for Boop unit tests
contract BoopTestUtils is Script {
    using Encoding for Boop;

    uint256 public constant TOKEN_MINT_AMOUNT = 1000;
    uint192 public constant DEFAULT_NONCETRACK = uint192(0);

    // To be initialized by subclasses.
    EntryPoint public entryPoint;

    // ====================================================================================================
    // BOOP HELPERS

    function createSignedBoopForMintToken(
        address account,
        address mintTokenTo,
        address payer,
        address token,
        uint256 privKey
    ) public view returns (Boop memory boop) {
        bytes memory mintCallData = getMintTokenCallData(mintTokenTo, TOKEN_MINT_AMOUNT);
        boop = createSignedBoop(account, token, payer, privKey, mintCallData);
    }

    function createSignedBoopForAddExtension(
        address account,
        address extension,
        ExtensionType extensionType,
        bytes memory installData,
        uint256 privKey
    ) public view returns (Boop memory boop) {
        bytes memory callData = getInstallExtensionCallData(extension, extensionType, installData);
        boop = createSignedBoop(account, account, address(0), /* paid by submitter */ privKey, callData);
    }

    function createSignedBoop(address account, address dest, address payer, uint256 privKey, bytes memory callData)
        public
        view
        returns (Boop memory boop)
    {
        boop = getStubBoop(account, dest, payer, callData);
        boop.validatorData = signBoop(boop, privKey);
    }

    function getStubBoop(address _account, address _dest, address _payer, bytes memory _callData)
        public
        view
        returns (Boop memory)
    {
        return Boop({
            account: _account,
            gasLimit: 800_000,
            executeGasLimit: 400_000,
            validateGasLimit: 300_000,
            validatePaymentGasLimit: 200_000,
            dest: _dest,
            payer: _payer,
            value: 0,
            nonceTrack: DEFAULT_NONCETRACK,
            nonceValue: entryPoint.nonceValues(_account, DEFAULT_NONCETRACK),
            maxFeePerGas: 10_000_000_000,
            submitterFee: 100,
            callData: _callData,
            validatorData: "",
            extraData: ""
        });
    }

    function signBoop(Boop memory boop, uint256 privKey) public view returns (bytes memory signature) {
        // Compute hash with restore=true to restore all fields after hash computation
        bytes32 hash = Utils.computeBoopHash(boop, true);

        // Sign the hash
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, hash);
        signature = abi.encodePacked(r, s, v);
    }

    // ====================================================================================================
    // CALLDATA HELPERS

    function getMintTokenCallData(address mintTokenTo, uint256 amount) public pure returns (bytes memory) {
        return abi.encodeCall(MockERC20.mint, (mintTokenTo, amount));
    }

    function getInstallExtensionCallData(address extension, ExtensionType extensionType, bytes memory installData)
        public
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(HappyAccount.addExtension, (extension, extensionType, installData));
    }

    // ====================================================================================================
    // OTHER HELPERS

    function getTokenBalance(address token, address account) public view returns (uint256) {
        return MockERC20(token).balanceOf(account);
    }

    function getEthBalance(address account) public view returns (uint256) {
        return address(account).balance;
    }
}
