// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISepiaSwapAdapter} from "../interfaces/ISepiaSwapAdapter.sol";

/// @notice Uniswap v3 SwapRouter02 interface (no deadline field).
interface ISwapRouter02 {
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);
}

/// @title UniswapV3Adapter
/// @notice Sells fee tokens for $SEPIA through a Uniswap v3-style router on Robinhood Chain.
///         `data` is a v3 path (tokenIn | fee | ... | $SEPIA). The adapter checks both ends of the path,
///         so a keeper cannot route fees anywhere except into $SEPIA.
contract UniswapV3Adapter is ISepiaSwapAdapter {
    using SafeERC20 for IERC20;

    ISwapRouter02 public immutable router;
    address public immutable sepia;
    address public immutable feeCollector;

    error OnlyFeeCollector();
    error BadPath();

    constructor(ISwapRouter02 router_, address sepia_, address feeCollector_) {
        router = router_;
        sepia = sepia_;
        feeCollector = feeCollector_;
    }

    function swapToSepia(address tokenIn, uint256 amountIn, uint256 minOut, address recipient, bytes calldata data)
        external
        returns (uint256 amountOut)
    {
        if (msg.sender != feeCollector) revert OnlyFeeCollector();
        if (data.length < 43) revert BadPath();
        if (address(bytes20(data[0:20])) != tokenIn) revert BadPath();
        if (address(bytes20(data[data.length - 20:])) != sepia) revert BadPath();

        IERC20(tokenIn).forceApprove(address(router), amountIn);
        amountOut = router.exactInput(
            ISwapRouter02.ExactInputParams({path: data, recipient: recipient, amountIn: amountIn, amountOutMinimum: minOut})
        );
    }
}
