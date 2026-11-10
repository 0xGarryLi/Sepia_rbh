// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SepiaRouter} from "../src/SepiaRouter.sol";
import {FeeCollector} from "../src/FeeCollector.sol";
import {ERC5564Announcer} from "../src/ERC5564Announcer.sol";
import {IERC5564Announcer} from "../src/interfaces/IERC5564Announcer.sol";
import {IWETH} from "../src/interfaces/IWETH.sol";

/// forge script script/Deploy.s.sol --rpc-url robinhood --broadcast --verify
contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address owner = vm.envAddress("OWNER_MULTISIG");
        address announcerAddr = vm.envOr("ANNOUNCER", address(0));

        vm.startBroadcast(pk);

        // Use the canonical announcer only if code actually exists at that address on this chain.
        if (announcerAddr == address(0) || announcerAddr.code.length == 0) {
            announcerAddr = address(new ERC5564Announcer());
            console2.log("Deployed ERC5564Announcer", announcerAddr);
        }

        FeeCollector collector = new FeeCollector(
            IERC20(vm.envAddress("SEPIA_TOKEN")),
            IWETH(vm.envAddress("WETH")),
            vm.envAddress("OPS_WALLET"),
            uint16(vm.envUint("OPS_SHARE_BPS")),
            owner
        );
        SepiaRouter router =
            new SepiaRouter(IERC5564Announcer(announcerAddr), address(collector), uint16(vm.envUint("MAX_FEE_BPS")), owner);

        vm.stopBroadcast();

        console2.log("FeeCollector", address(collector));
        console2.log("SepiaRouter ", address(router));
    }
}
