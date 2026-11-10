// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ISepiaSwapAdapter} from "./interfaces/ISepiaSwapAdapter.sol";
import {IWETH} from "./interfaces/IWETH.sol";

/// @title FeeCollector
/// @notice Receives Sepia protocol fees, sends a published share to the ops wallet (relayer gas,
///         infrastructure, development) and uses the rest to buy $SEPIA and burn it.
/// @dev    $SEPIA is launched on Pons and may have no burn() function, so "burn" means sending
///         to the dead address. Burns are counted on-chain in `totalBurned`.
///         STATUS: work in progress, unaudited, not deployed.
contract FeeCollector is ReentrancyGuard, Ownable2Step {
    using SafeERC20 for IERC20;

    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    /// @notice The ops share can never exceed 30% of fees.
    uint16 public constant OPS_CEILING_BPS = 3_000;

    IERC20 public immutable sepia;
    IWETH public immutable weth;

    ISepiaSwapAdapter public adapter;
    address public opsWallet;
    uint16 public opsShareBps;
    mapping(address => bool) public isKeeper;

    uint256 public totalBurned;

    event Burned(address indexed tokenIn, uint256 amountIn, uint256 sepiaBurned);
    event OpsPaid(address indexed token, uint256 amount);
    event AdapterSet(address indexed adapter);
    event OpsSet(address indexed opsWallet, uint16 opsShareBps);
    event KeeperSet(address indexed keeper, bool allowed);

    error NotKeeper();
    error ZeroAddress();
    error ShareTooHigh();
    error NothingToBurn();
    error SlippageExceeded();

    modifier onlyKeeper() {
        if (!isKeeper[msg.sender] && msg.sender != owner()) revert NotKeeper();
        _;
    }

    constructor(IERC20 sepia_, IWETH weth_, address opsWallet_, uint16 opsShareBps_, address owner_) Ownable(owner_) {
        if (address(sepia_) == address(0) || address(weth_) == address(0) || opsWallet_ == address(0)) {
            revert ZeroAddress();
        }
        if (opsShareBps_ > OPS_CEILING_BPS) revert ShareTooHigh();
        sepia = sepia_;
        weth = weth_;
        opsWallet = opsWallet_;
        opsShareBps = opsShareBps_;
        emit OpsSet(opsWallet_, opsShareBps_);
    }

    receive() external payable {}

    /// @notice Turn collected fees of one token into burned $SEPIA.
    /// @param tokenIn  fee token, or ETH placeholder for native ETH
    /// @param amountIn amount to process (ops share is taken from it first)
    /// @param minOut   minimum $SEPIA to receive for the swapped part (slippage guard)
    /// @param data     route data for the adapter
    function buybackAndBurn(address tokenIn, uint256 amountIn, uint256 minOut, bytes calldata data)
        external
        onlyKeeper
        nonReentrant
        returns (uint256 burned)
    {
        if (amountIn == 0) revert NothingToBurn();
        if (tokenIn == ETH) {
            weth.deposit{value: amountIn}();
            tokenIn = address(weth);
        }

        uint256 ops = (amountIn * opsShareBps) / 10_000;
        if (ops != 0) {
            IERC20(tokenIn).safeTransfer(opsWallet, ops);
            emit OpsPaid(tokenIn, ops);
        }
        uint256 swapIn = amountIn - ops;

        if (tokenIn == address(sepia)) {
            // Fees already paid in $SEPIA are burned directly.
            sepia.safeTransfer(DEAD, swapIn);
            burned = swapIn;
        } else {
            IERC20(tokenIn).safeTransfer(address(adapter), swapIn);
            uint256 before = sepia.balanceOf(DEAD);
            adapter.swapToSepia(tokenIn, swapIn, minOut, DEAD, data);
            burned = sepia.balanceOf(DEAD) - before; // measured, not trusted from the adapter
            if (burned < minOut) revert SlippageExceeded();
        }

        totalBurned += burned;
        emit Burned(tokenIn, swapIn, burned);
    }

    // ------------------------------------------------------------------
    // Admin (owner is a multisig; every change is an on-chain event)
    // ------------------------------------------------------------------

    function setAdapter(ISepiaSwapAdapter adapter_) external onlyOwner {
        if (address(adapter_) == address(0)) revert ZeroAddress();
        adapter = adapter_;
        emit AdapterSet(address(adapter_));
    }

    function setOps(address opsWallet_, uint16 opsShareBps_) external onlyOwner {
        if (opsWallet_ == address(0)) revert ZeroAddress();
        if (opsShareBps_ > OPS_CEILING_BPS) revert ShareTooHigh();
        opsWallet = opsWallet_;
        opsShareBps = opsShareBps_;
        emit OpsSet(opsWallet_, opsShareBps_);
    }

    function setKeeper(address keeper, bool allowed) external onlyOwner {
        isKeeper[keeper] = allowed;
        emit KeeperSet(keeper, allowed);
    }
}
