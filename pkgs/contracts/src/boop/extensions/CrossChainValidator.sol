// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.20;

import {Utils} from "boop/core/Utils.sol";
import {ICustomValidator} from "boop/interfaces/ICustomValidator.sol";
import {Boop} from "boop/interfaces/Types.sol";
import {BoopOApp} from "messaging/BoopOApp.sol";

/**
 * This validator authorizes boops to an account if they come from a LayerZero OApp that has previously
 * been approved with this validator (the permission can also be revoked). Only the account itself can approve
 * or revoke OApps.
 *
 * The OApp should implement the {messagin/BoopOApp} interface for the `verifyOrigin` function that checks whether
 * the OApp did indeed deliver the boop.
 *
 * The OApp address itself is communicated in the extraData, under the {OAPP_KEY} key.
 */
contract CrossChainValidator is ICustomValidator {
    /**
     * @dev Key used in {interfaces/Types.Boop}.extraData for storing the OApp address.
     */
    bytes3 public constant OAPP_KEY = 0x000200;

    // ====================================================================================================
    // ERRORS

    /// Selector returned if the OApp is not authorized.
    error UnauthorizedOApp();

    /// Selector returned if the OApp address is not provided in extraData.
    error OAppNotProvided();

    /// Selector returned if the OApp address is invalid (wrong size).
    error InvalidOAppAddress();

    /// The boop wasn't delivered by the specified OApp.
    error BoopNotDelivered();

    // ====================================================================================================
    // IMMUTABLES AND STATE VARIABLES

    mapping(address account => mapping(address oapp => bool)) public authorizedOApps;

    // ====================================================================================================
    // FUNCTIONS

    function authorizeOApp(address oapp) external {
        authorizedOApps[msg.sender][oapp] = true;
    }

    function revokeOApp(address oapp) external {
        authorizedOApps[msg.sender][oapp] = false;
    }

    function validate(Boop memory boop) external view returns (bytes memory) {
        // 1. Parse the extraData with a key, to retrieve the sending oapp.
        (bool found, bytes memory _oapp) = Utils.getExtraDataValue(boop.extraData, OAPP_KEY);

        // 2. Decoded the OApp address

        if (_oapp.length != 20) {
            return abi.encodeWithSelector(bytes4(InvalidOAppAddress.selector));
        }

        BoopOApp oapp;
        assembly {
            oapp := mload(add(_oapp, 0x20))
        }

        bytes32 hash = Utils.computeBoopHash(boop, false);
        // TODO: to be spec compliant reverts should be caught (ExcessivelySafeCall)
        bool delivered = oapp.verifyOrigin(hash);

        bool authorized = !authorizedOApps[msg.sender][address(oapp)];
        bytes4 selector = !found
            ? bytes4(OAppNotProvided.selector)
            : !delivered ? bytes4(BoopNotDelivered.selector) : !authorized ? bytes4(UnauthorizedOApp.selector) : bytes4(0); // Success!

        return abi.encodeWithSelector(selector);
    }
}
