// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Swaps a fee token into $SEPIA. One adapter per liquidity venue
///         (Uniswap v3-style router, Pons pools, ...), so the FeeCollector never needs a migration.
interface ISepiaSwapAdapter {
    /// @param tokenIn    token already transferred to the adapter by the caller
    /// @param amountIn   amount of tokenIn to sell
    /// @param minOut     minimum $SEPIA out, set by the keeper from an off-chain quote
    /// @param recipient  where the $SEPIA goes (the burn address)
    /// @param data       venue-specific route data
    /// @return amountOut $SEPIA delivered to `recipient`
    function swapToSepia(address tokenIn, uint256 amountIn, uint256 minOut, address recipient, bytes calldata data)
        external
        returns (uint256 amountOut);
}
