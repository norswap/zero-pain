// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.20;

import {Utils} from "boop/core/Utils.sol";
import {ICustomValidator} from "boop/interfaces/ICustomValidator.sol";
import {Boop} from "boop/interfaces/Types.sol";
import {BoopOApp} from "messaging/BoopOApp.sol";

/**
 * TODO update
 *
 * This validator maintains a mapping from (account, target) pair to session keys, and authorizes
 * boops from the given account to the target if they are signed with the session key.
 *
 * Only the account is abilitated to modify its own mappings.
 *
 * Session key validation is restricted to boops that are not paid for by the account itself,
 * as this opens a griefing vector where a malicious app destroys user funds by spamming, and
 * unlike paymasters and submitters, account are not usually set up to handle this.
 *
 * The session key is represented as an address (as that is the result of ecrecover), which is not
 * strictly speaking a key, but we call it that anyway for simplicity.
 */
contract CrossChainValidator is ICustomValidator {
    /**
     * @dev Key used in {interfaces/Types.Boop}.extraData for storing the OApp address.
     */
    bytes3 constant OAPP_KEY = 0x000200;

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
