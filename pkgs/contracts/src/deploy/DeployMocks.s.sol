// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.20;

import {BaseDeployScript} from "src/deploy/BaseDeployScript.sol";
import {MockERC20} from "src/mocks/MockERC20.sol";

/**
 * @dev Deploys mock contracts for testing purposes.
 */
contract DeployMockERC20 is BaseDeployScript {
    bytes32 public constant SALT_TOKEN_A = bytes32(uint256(0));
    MockERC20 public mockTokenA;

    function deploy() internal override {
        mockTokenA = deployMockToken("MockTokenA", "MTA", SALT_TOKEN_A);
    }

    function deployMockToken(string memory name, string memory symbol, bytes32 salt) internal returns (MockERC20) {
        (address addr,) = deployDeterministic(
            name, "MockERC20", type(MockERC20).creationCode, abi.encode(name, symbol, uint8(18)), salt
        );
        return MockERC20(addr);
    }
}
