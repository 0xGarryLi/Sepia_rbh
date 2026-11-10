// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Subset of the ERC-6538 stealth meta-address registry used by Sepia.
///         https://eips.ethereum.org/EIPS/eip-6538
interface IERC6538Registry {
    event StealthMetaAddressSet(address indexed registrant, uint256 indexed schemeId, bytes stealthMetaAddress);

    function registerKeys(uint256 schemeId, bytes calldata stealthMetaAddress) external;

    function stealthMetaAddressOf(address registrant, uint256 schemeId) external view returns (bytes memory);
}
