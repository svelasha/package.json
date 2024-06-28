// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IPoolAddressesProvider} from "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import {BammArbitrage} from "../src/BammArbitrage.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract BammArbitrageTest is Test {
    using SafeMath for uint256;
    BammArbitrage private bammArbitrage;

    function setUp() public {
        // We use block 16501423 because we are sure that the B.Protocol as some fund to sell + Aave V3 is on mainnet
        vm.createSelectFork(vm.envString("FOUNDRY_ETH_RPC_URL"), 16501423);
        bammArbitrage = new BammArbitrage();
    }

    /**
    * @notice Test the initial value of the contract
    */
    function testInitValue() public {
        assertEq(address(bammArbitrage.swapRouter()), address(0xE592427A0AEce92De3Edee1F18E0157C05861564));
        assertEq(address(bammArbitrage.bamm()), address(0x896d8a30C32eAd64f2e1195C2C8E0932Be7Dc20B));
        assertEq(address(bammArbitrage.iWETH9()), address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
        assertEq(bammArbitrage.WETH(), address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
        assertEq(bammArbitrage.LUSD(), address(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0));
        assertEq(bammArbitrage.USDC(), address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48));
        assertEq(bammArbitrage.poolFee(), 500);
        assertEq(bammArbitrage.MIN_SQRT_RATIO(), 4295128739);
        assertEq(bammArbitrage.isAuthorized(address(this)), true);
    }

    /**
    * @notice This test the modifier onlyAuthorizedAddress
    */
    function testOnlyAuthorizedAddress() public {
        vm.expectRevert("BammArbitrage: not authorized");
        vm.startPrank(address(0xd3ad));
        bammArbitrage.requestFlashLoan();
        vm.stopPrank();

        vm.expectRevert("BammArbitrage: not authorized");
        vm.startPrank(address(0xd3ad));
        bammArbitrage.changeAuthorization(address(0xd3ad));
        vm.stopPrank();

        bammArbitrage.changeAuthorization(address(0xd3ad));

        vm.startPrank(address(0xd3ad));
        bammArbitrage.requestFlashLoan();
        vm.stopPrank();

        vm.startPrank(address(0xd3ad));
        bammArbitrage.requestFlashLoan();
        vm.stopPrank();
    }

    /**
    * @notice This test the changeAuthorization function
    */
    function testChangeAuthorization() public {
        assertEq(bammArbitrage.isAuthorized(address(0xd3ad)), false);
        bammArbitrage.changeAuthorization(address(0xd3ad));
        assertEq(bammArbitrage.isAuthorized(address(0xd3ad)), true);
    }

    /**
    * @notice This test the FlashLoan function
    */
    function testFlashLoan() public {
        uint256 startBalance = address(this).balance;
        console2.log("balance before flashloan: ", startBalance);
        (, ,uint _amountInLusdStart) =  bammArbitrage.bamm().getLUSDValue();
        console2.log("amount of ETH in LUSD to buy at start: ", _amountInLusdStart);
        bammArbitrage.requestFlashLoan();
        uint256 endBalance = address(this).balance;
        assertGe(endBalance, startBalance);
        (, ,uint _amountInLusdEnd) =  bammArbitrage.bamm().getLUSDValue();
        assertGe(_amountInLusdStart, _amountInLusdEnd);
        console2.log("amount of ETH in LUSD to buy at end: ", _amountInLusdEnd);
        console2.log("balance after flashloan: ", endBalance);
        console2.log("profit made : ", endBalance.sub(startBalance));
    }

    receive() external payable {}
}
