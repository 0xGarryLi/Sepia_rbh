// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC5564Announcer} from "./interfaces/IERC5564Announcer.sol";

/// @title SepiaRouter
/// @notice Sends payments to ERC-5564 stealth addresses (funds + announcement in one tx)
///         and moves funds out of them without linking the one-time address to its owner.
/// @dev    The router never keeps a balance between transactions. Funds go straight to the
///         stealth address on send, and straight to the destination on withdrawal.
///         STATUS: work in progress, unaudited, not deployed.
contract SepiaRouter is EIP712, ReentrancyGuard, Ownable2Step {
    using SafeERC20 for IERC20;

    /// @notice ERC-5564 scheme 1: secp256k1 with view tags.
    uint256 public constant SCHEME_ID = 1;
    /// @notice Placeholder address for native ETH in events and withdraw intents.
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    /// @notice Hard ceiling for the protocol fee: 1%. The owner can lower the live cap, never raise it above this.
    uint16 public constant FEE_CEILING_BPS = 100;

    bytes32 public constant WITHDRAW_TYPEHASH = keccak256(
        "Withdraw(address owner,address token,address to,uint256 amount,address relayer,uint256 relayerFee,uint256 protocolFee,uint256 nonce,uint256 deadline)"
    );

    /// @notice A withdrawal intent signed by the one-time (stealth) key.
    struct Withdraw {
        address owner; // the one-time address
        address token; // ERC-20 being withdrawn
        address to; // destination for amount - fees
        uint256 amount; // amount pulled from `owner`
        address relayer; // receives `relayerFee`; for withdrawWithPermit also the only allowed caller
        uint256 relayerFee;
        uint256 protocolFee;
        uint256 nonce;
        uint256 deadline;
    }

    IERC5564Announcer public immutable announcer;
    address public feeCollector;
    uint16 public maxFeeBps;
    mapping(address owner => uint256) public nonces;

    event FeeCollectorSet(address indexed feeCollector);
    event MaxFeeBpsSet(uint16 maxFeeBps);
    event Withdrawn(
        address indexed owner,
        address indexed token,
        address indexed to,
        uint256 amountOut,
        uint256 relayerFee,
        uint256 protocolFee
    );

    error ZeroAddress();
    error FeeTooHigh();
    error FeesExceedAmount();
    error Expired();
    error BadNonce();
    error BadSignature();
    error WrongCaller();
    error EthTransferFailed();

    constructor(IERC5564Announcer announcer_, address feeCollector_, uint16 maxFeeBps_, address owner_)
        EIP712("SepiaRouter", "1")
        Ownable(owner_)
    {
        if (address(announcer_) == address(0) || feeCollector_ == address(0)) revert ZeroAddress();
        if (maxFeeBps_ > FEE_CEILING_BPS) revert FeeTooHigh();
        announcer = announcer_;
        feeCollector = feeCollector_;
        maxFeeBps = maxFeeBps_;
        emit FeeCollectorSet(feeCollector_);
        emit MaxFeeBpsSet(maxFeeBps_);
    }

    // ------------------------------------------------------------------
    // Sending
    // ------------------------------------------------------------------

    /// @notice Pay ETH to a stealth address and announce it.
    /// @param stealth          address computed by the payer from the recipient's meta-address
    /// @param ephemeralPubKey  33-byte compressed ephemeral public key
    /// @param metadata         byte 0 = view tag, then selector / token / amount (ERC-5564 layout)
    function sendETH(address payable stealth, bytes calldata ephemeralPubKey, bytes calldata metadata)
        external
        payable
        nonReentrant
    {
        if (stealth == address(0)) revert ZeroAddress();
        _sendEth(stealth, msg.value);
        announcer.announce(SCHEME_ID, stealth, ephemeralPubKey, metadata);
    }

    /// @notice Pay an ERC-20 to a stealth address and announce it. Requires prior approval.
    function sendToken(
        IERC20 token,
        uint256 amount,
        address stealth,
        bytes calldata ephemeralPubKey,
        bytes calldata metadata
    ) external nonReentrant {
        if (stealth == address(0)) revert ZeroAddress();
        token.safeTransferFrom(msg.sender, stealth, amount);
        announcer.announce(SCHEME_ID, stealth, ephemeralPubKey, metadata);
    }

    // ------------------------------------------------------------------
    // Withdrawing
    // ------------------------------------------------------------------

    /// @notice Path A — ETH. Called by the one-time address itself; gas is paid from the received ETH.
    function sweepETH(address payable to, uint256 protocolFee) external payable nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        _checkFees(msg.value, 0, protocolFee);
        if (protocolFee != 0) _sendEth(payable(feeCollector), protocolFee);
        uint256 out = msg.value - protocolFee;
        _sendEth(to, out);
        emit Withdrawn(msg.sender, ETH, to, out, 0, protocolFee);
    }

    /// @notice Path B — tokens with EIP-2612 permit. Submitted by the relayer; fully gasless for the owner.
    /// @param w            withdraw intent signed by the one-time key
    /// @param permitDeadline, v, r, s   EIP-2612 permit for (owner -> this router, w.amount)
    /// @param withdrawSig  EIP-712 signature over `w`
    function withdrawWithPermit(
        Withdraw calldata w,
        uint256 permitDeadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        bytes calldata withdrawSig
    ) external nonReentrant {
        if (msg.sender != w.relayer) revert WrongCaller();
        _verify(w, withdrawSig);
        // A permit can be front-run by anyone who saw it in the mempool. That only sets the same
        // allowance, so we accept the call if the allowance is already in place.
        try IERC20Permit(w.token).permit(w.owner, address(this), w.amount, permitDeadline, v, r, s) {}
        catch {
            if (IERC20(w.token).allowance(w.owner, address(this)) < w.amount) revert BadSignature();
        }
        _pullAndPay(w);
    }

    /// @notice Path C — any ERC-20. Called by the one-time address after a relayer gas top-up and an approve.
    /// @dev    The owner is the caller, so no separate signature is needed. `relayerFee` repays the top-up.
    function sweepToken(Withdraw calldata w) external nonReentrant {
        if (msg.sender != w.owner) revert WrongCaller();
        if (block.timestamp > w.deadline) revert Expired();
        _pullAndPay(w);
    }

    // ------------------------------------------------------------------
    // Views
    // ------------------------------------------------------------------

    /// @notice EIP-712 digest the one-time key must sign. Exposed for SDKs and tests.
    function hashWithdraw(Withdraw calldata w) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    WITHDRAW_TYPEHASH,
                    w.owner,
                    w.token,
                    w.to,
                    w.amount,
                    w.relayer,
                    w.relayerFee,
                    w.protocolFee,
                    w.nonce,
                    w.deadline
                )
            )
        );
    }

    // ------------------------------------------------------------------
    // Admin (owner is a multisig)
    // ------------------------------------------------------------------

    function setFeeCollector(address feeCollector_) external onlyOwner {
        if (feeCollector_ == address(0)) revert ZeroAddress();
        feeCollector = feeCollector_;
        emit FeeCollectorSet(feeCollector_);
    }

    function setMaxFeeBps(uint16 maxFeeBps_) external onlyOwner {
        if (maxFeeBps_ > FEE_CEILING_BPS) revert FeeTooHigh();
        maxFeeBps = maxFeeBps_;
        emit MaxFeeBpsSet(maxFeeBps_);
    }

    // ------------------------------------------------------------------
    // Internals
    // ------------------------------------------------------------------

    function _verify(Withdraw calldata w, bytes calldata sig) internal {
        if (block.timestamp > w.deadline) revert Expired();
        if (w.nonce != nonces[w.owner]) revert BadNonce();
        unchecked {
            nonces[w.owner]++;
        }
        address signer = ECDSA.recover(hashWithdraw(w), sig);
        if (signer != w.owner) revert BadSignature();
    }

    /// @dev Pulls `w.amount`, measures what actually arrived (fee-on-transfer tokens exist on Pons),
    ///      then pays relayer, fee collector and destination from what arrived.
    function _pullAndPay(Withdraw calldata w) internal {
        if (w.to == address(0)) revert ZeroAddress();
        IERC20 token = IERC20(w.token);
        uint256 before = token.balanceOf(address(this));
        token.safeTransferFrom(w.owner, address(this), w.amount);
        uint256 received = token.balanceOf(address(this)) - before;

        _checkFees(received, w.relayerFee, w.protocolFee);
        uint256 out = received - w.relayerFee - w.protocolFee;

        if (w.relayerFee != 0) token.safeTransfer(w.relayer, w.relayerFee);
        if (w.protocolFee != 0) token.safeTransfer(feeCollector, w.protocolFee);
        token.safeTransfer(w.to, out);

        emit Withdrawn(w.owner, w.token, w.to, out, w.relayerFee, w.protocolFee);
    }

    function _checkFees(uint256 amount, uint256 relayerFee, uint256 protocolFee) internal view {
        if (protocolFee * 10_000 > amount * maxFeeBps) revert FeeTooHigh();
        if (relayerFee + protocolFee > amount) revert FeesExceedAmount();
    }

    function _sendEth(address payable to, uint256 amount) internal {
        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert EthTransferFailed();
    }
}
