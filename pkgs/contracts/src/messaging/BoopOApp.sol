// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.20;

interface BoopOApp {
    /**
     * Called by {boop/extensions/CrossChainValidator} to ascertain that a boop was delivered from this OApp.
     */
    function verifyOrigin(bytes32 boopHash) external view returns(bool);
}