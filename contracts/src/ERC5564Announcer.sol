// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC5564Announcer} from "./interfaces/IERC5564Announcer.sol";

/// @notice Minimal ERC-5564 announcer. Deployed only if the canonical singleton
///         (0x55649E01B5Df198D18D95b5cc5051630cfD45564) is not available on Robinhood Chain.
contract ERC5564Announcer is IERC5564Announcer {
    function announce(uint256 schemeId, address stealthAddress, bytes memory ephemeralPubKey, bytes memory metadata)
        external
    {
        emit Announcement(schemeId, stealthAddress, msg.sender, ephemeralPubKey, metadata);
    }
}
