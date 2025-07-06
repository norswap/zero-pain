// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {OAppOptionsType3} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {OApp, Origin, MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Encoding} from "boop/core/Encoding.sol";
import {EntryPoint} from "boop/core/EntryPoint.sol";
import {Utils} from "boop/core/Utils.sol";
import {Boop} from "boop/interfaces/Types.sol";
import {BoopOApp} from "./BoopOApp.sol";

contract MyOApp is OApp, OAppOptionsType3, BoopOApp {
    // ====================================================================================================
    // FIELDS

    /// Records the hash of the boop that is being delivered.
    bytes32 private transient deliveringBoop;

    EntryPoint public entryPoint;

    /// Msg type for sending a string, for use in OAppOptionsType3 as an enforced option
    uint16 public constant SEND = 1;

    // =================================================================================================================
    // CONSTRUCTOR

    /// Initialize with Endpoint V2, Boop Entrypoint, and owner address.
    constructor(address _endpoint, address _entryPoint, address _owner) OApp(_endpoint, _owner) Ownable(_owner) {
        entryPoint = EntryPoint(_entryPoint);
    }

    // =================================================================================================================
    // EVENTS

    /// Emitted whenever a boop is received.
    event BoopReceived(uint32 srcEid, bytes boop);

    // ==================================================================================================== F
    // QUOTE LOGIC

    /**
     * @notice Quotes the gas needed to pay for the full omnichain transaction in native gas or ZRO token.
     * @param _dstEid Destination chain's endpoint ID.
     * @param _boop The encoded boop to send.
     * @param _options Message execution options (e.g., for sending gas to destination).
     * @return fee A `MessagingFee` struct containing the calculated gas fee in either the native token or ZRO token.
     */
    function quoteSendString(uint32 _dstEid, bytes calldata _boop, bytes calldata _options)
        public
        view
        returns (MessagingFee memory fee)
    {
        // TODO might want to decope the boop to set the gas limit
        bool _payInLzToken = false;
        // TODO we might not need this combination
        // combineOptions (from OAppOptionsType3) merges enforced options set by the contract owner
        // with any additional execution options provided by the caller
        fee = _quote(_dstEid, _boop, combineOptions(_dstEid, SEND, _options), _payInLzToken);
    }

    // ====================================================================================================
    // SEND LOGIC

    /// @notice Send a string to a remote OApp on another chain
    /// @param _dstEid   Destination Endpoint ID (uint32)
    /// @param _boop  The boop to send
    /// @param _options  Execution options for gas on the destination (bytes)
    function sendBoop(uint32 _dstEid, bytes calldata _boop, bytes calldata _options) external payable {
        // TODO set the proper gas limit
        // TODO we might not need the combine
        address payable refundRecipient = payable(msg.sender);
        // MessagingFee: pay all gas as native token; no ZRO
        _lzSend(_dstEid, _boop, combineOptions(_dstEid, SEND, _options), MessagingFee(msg.value, 0), refundRecipient);
    }

    // ====================================================================================================
    // RECEIVE LOGIC

    // Override _lzReceive to decode the incoming bytes and apply your logic.
    // The base OAppReceiver.lzReceive ensures:
    //   • Only the LayerZero Endpoint can call this method
    //   • The sender is a registered peer (peers[srcEid] == origin.sender)

    /// @notice Invoked by OAppReceiver when EndpointV2.lzReceive is called
    /// @dev   _origin    Metadata (source chain, sender address, nonce)
    /// @dev   _guid      Global unique ID for tracking this message
    /// @param _boop      The boop we sent from another chain
    /// @dev   _executor  Executor address that delivered the message
    /// @dev   _extraData Additional data from the Executor (unused here)
    function _lzReceive(
        Origin calldata _origin,
        bytes32, /*_guid*/
        bytes calldata _boop,
        address, /*_executor*/
        bytes calldata /*_extraData*/
    ) internal override {
        Boop memory boop = Encoding.decode(_boop);
        bytes32 hash = Utils.computeBoopHash(boop, false);
        deliveringBoop = hash;
        emit BoopReceived(_origin.srcEid, _boop);
        entryPoint.submit(_boop);
    }

    function verifyOrigin(bytes32 boopHash) external view returns (bool) {
        return deliveringBoop == boopHash;
    }
}
