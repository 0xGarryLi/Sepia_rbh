// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {SepiaRouter} from "../src/SepiaRouter.sol";
import {ERC5564Announcer} from "../src/ERC5564Announcer.sol";
import {IERC5564Announcer} from "../src/interfaces/IERC5564Announcer.sol";

contract MockUSDC is ERC20, ERC20Permit {
    constructor() ERC20("USD Coin", "USDC") ERC20Permit("USD Coin") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @dev A plain ERC-20 without permit, like most tokens launched on Pons.
contract MockMeme is ERC20 {
    constructor() ERC20("Meme", "MEME") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract SepiaRouterTest is Test {
    event Announcement(
        uint256 indexed schemeId,
        address indexed stealthAddress,
        address indexed caller,
        bytes ephemeralPubKey,
        bytes metadata
    );

    bytes32 constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    ERC5564Announcer announcer;
    SepiaRouter router;
    MockUSDC usdc;
    MockMeme meme;

    address owner = makeAddr("owner");
    address collector = makeAddr("collector");
    address relayer = makeAddr("relayer");
    address alice = makeAddr("alice");
    address dest = makeAddr("dest");

    uint256 stealthPk = 0xA11CE5;
    address stealth;

    bytes ephPub = hex"02c9a1f1e1c8e0d4b3a2918273645546372819fedcba9876543210fedcba987654";
    bytes metaEth = hex"7aeeeeeeee";

    function setUp() public {
        stealth = vm.addr(stealthPk);
        announcer = new ERC5564Announcer();
        router = new SepiaRouter(IERC5564Announcer(address(announcer)), collector, 50, owner); // 0.5% cap
        usdc = new MockUSDC();
        meme = new MockMeme();
    }

    // ---------------- sending ----------------

    function test_sendETH_forwardsFundsAndAnnounces() public {
        vm.deal(alice, 1 ether);
        vm.expectEmit(true, true, true, true, address(announcer));
        emit Announcement(1, stealth, address(router), ephPub, metaEth);
        vm.prank(alice);
        router.sendETH{value: 1 ether}(payable(stealth), ephPub, metaEth);
        assertEq(stealth.balance, 1 ether);
        assertEq(address(router).balance, 0, "router keeps nothing");
    }

    function test_sendToken_goesStraightToStealth() public {
        usdc.mint(alice, 500e6);
        vm.startPrank(alice);
        usdc.approve(address(router), 500e6);
        router.sendToken(usdc, 500e6, stealth, ephPub, hex"7aa9059cbb");
        vm.stopPrank();
        assertEq(usdc.balanceOf(stealth), 500e6);
        assertEq(usdc.balanceOf(address(router)), 0, "router keeps nothing");
    }

    // ---------------- path A: ETH ----------------

    function test_sweepETH_paysFeeAndDestination() public {
        vm.deal(stealth, 1 ether);
        vm.prank(stealth);
        router.sweepETH{value: 1 ether}(payable(dest), 0.005 ether);
        assertEq(collector.balance, 0.005 ether);
        assertEq(dest.balance, 0.995 ether);
    }

    function test_sweepETH_rejectsFeeAboveCap() public {
        vm.deal(stealth, 1 ether);
        vm.prank(stealth);
        vm.expectRevert(SepiaRouter.FeeTooHigh.selector);
        router.sweepETH{value: 1 ether}(payable(dest), 0.006 ether);
    }

    // ---------------- path B: permit ----------------

    function _intent(address token, uint256 amount, uint256 relayerFee, uint256 protocolFee)
        internal
        view
        returns (SepiaRouter.Withdraw memory w)
    {
        w = SepiaRouter.Withdraw({
            owner: stealth,
            token: token,
            to: dest,
            amount: amount,
            relayer: relayer,
            relayerFee: relayerFee,
            protocolFee: protocolFee,
            nonce: router.nonces(stealth),
            deadline: block.timestamp + 1 hours
        });
    }

    function _signIntent(SepiaRouter.Withdraw memory w) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(stealthPk, router.hashWithdraw(w));
        return abi.encodePacked(r, s, v);
    }

    function _signPermit(uint256 amount, uint256 deadline) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 structHash =
            keccak256(abi.encode(PERMIT_TYPEHASH, stealth, address(router), amount, usdc.nonces(stealth), deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", usdc.DOMAIN_SEPARATOR(), structHash));
        (v, r, s) = vm.sign(stealthPk, digest);
    }

    function test_withdrawWithPermit_isGaslessForOwner() public {
        usdc.mint(stealth, 1_000e6);
        SepiaRouter.Withdraw memory w = _intent(address(usdc), 1_000e6, 2e6, 5e6);
        bytes memory sig = _signIntent(w);
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(w.amount, w.deadline);

        vm.prank(relayer);
        router.withdrawWithPermit(w, w.deadline, v, r, s, sig);

        assertEq(usdc.balanceOf(dest), 993e6);
        assertEq(usdc.balanceOf(relayer), 2e6);
        assertEq(usdc.balanceOf(collector), 5e6);
        assertEq(usdc.balanceOf(stealth), 0);
        assertEq(stealth.balance, 0, "one-time address never needed ETH");
    }

    function test_withdrawWithPermit_relayerCannotRedirect() public {
        usdc.mint(stealth, 1_000e6);
        SepiaRouter.Withdraw memory w = _intent(address(usdc), 1_000e6, 2e6, 5e6);
        bytes memory sig = _signIntent(w);
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(w.amount, w.deadline);

        w.to = relayer; // tamper
        vm.prank(relayer);
        vm.expectRevert(SepiaRouter.BadSignature.selector);
        router.withdrawWithPermit(w, w.deadline, v, r, s, sig);
    }

    function test_withdrawWithPermit_onlyNamedRelayer() public {
        usdc.mint(stealth, 1_000e6);
        SepiaRouter.Withdraw memory w = _intent(address(usdc), 1_000e6, 2e6, 5e6);
        bytes memory sig = _signIntent(w);
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(w.amount, w.deadline);

        vm.prank(alice);
        vm.expectRevert(SepiaRouter.WrongCaller.selector);
        router.withdrawWithPermit(w, w.deadline, v, r, s, sig);
    }

    function test_withdrawWithPermit_noReplay() public {
        usdc.mint(stealth, 2_000e6);
        SepiaRouter.Withdraw memory w = _intent(address(usdc), 1_000e6, 2e6, 5e6);
        bytes memory sig = _signIntent(w);
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(w.amount, w.deadline);
        vm.prank(relayer);
        router.withdrawWithPermit(w, w.deadline, v, r, s, sig);

        vm.prank(relayer);
        vm.expectRevert(SepiaRouter.BadNonce.selector);
        router.withdrawWithPermit(w, w.deadline, v, r, s, sig);
    }

    function test_withdrawWithPermit_expired() public {
        usdc.mint(stealth, 1_000e6);
        SepiaRouter.Withdraw memory w = _intent(address(usdc), 1_000e6, 2e6, 5e6);
        bytes memory sig = _signIntent(w);
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(w.amount, w.deadline);
        vm.warp(w.deadline + 1);
        vm.prank(relayer);
        vm.expectRevert(SepiaRouter.Expired.selector);
        router.withdrawWithPermit(w, w.deadline, v, r, s, sig);
    }

    // ---------------- path C: top-up + sweep ----------------

    function test_sweepToken_plainErc20() public {
        meme.mint(stealth, 1_000e18);
        vm.deal(stealth, 0.0002 ether); // relayer top-up
        SepiaRouter.Withdraw memory w = _intent(address(meme), 1_000e18, 10e18, 5e18);

        vm.startPrank(stealth);
        meme.approve(address(router), w.amount);
        router.sweepToken(w);
        vm.stopPrank();

        assertEq(meme.balanceOf(dest), 985e18);
        assertEq(meme.balanceOf(relayer), 10e18, "top-up repaid in the token");
        assertEq(meme.balanceOf(collector), 5e18);
    }

    function test_sweepToken_onlyOwnerCalls() public {
        SepiaRouter.Withdraw memory w = _intent(address(meme), 1e18, 0, 0);
        vm.prank(relayer);
        vm.expectRevert(SepiaRouter.WrongCaller.selector);
        router.sweepToken(w);
    }

    // ---------------- admin ----------------

    function test_feeCeilingCannotBeRaised() public {
        vm.prank(owner);
        vm.expectRevert(SepiaRouter.FeeTooHigh.selector);
        router.setMaxFeeBps(101);
    }
}
