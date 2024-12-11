// SPDX-License-Identifier: MIT

pragma solidity >=0.8.25 <0.9.0;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";
import { DummyERC20 } from "../src/DummyERC20.sol";
import { BXRNFT } from "../src/BXRNFT.sol";

contract BXRNFTTest is Test {
    BXRNFT public bxrnft;
    DummyERC20 public usdc;

    function setUp() public {
        usdc = new DummyERC20();
        bxrnft = new BXRNFT(address(usdc));
    }

    function testPublicMint() public {
        usdc.transfer(address(1), 100_000_000);

        vm.startPrank(address(1));
        usdc.approve(address(bxrnft), 100_000_000);
        bxrnft.publicMint(1_000_000);
        vm.stopPrank();
    }

    function testSetMinMintFees() public {
        bxrnft.setMinMintFees(2_000_000);
        assertEq(bxrnft.MIN_MINT_FEES(), 2_000_000);
    }

    function testWithdrawFees() public {
        usdc.transfer(address(1), 100_000_000);
        uint256 balanceBefore = usdc.balanceOf(address(this));

        vm.startPrank(address(1));
        usdc.approve(address(bxrnft), 100_000_000);
        bxrnft.publicMint(1_000_000);
        vm.stopPrank();

        bxrnft.withdrawFees(1_000_000);
        assertEq(usdc.balanceOf(address(this)), balanceBefore + 1_000_000);
    }

    function testListedNFT() public {
        usdc.transfer(address(1), 100_000_000);
        vm.startPrank(address(1));
        usdc.approve(address(bxrnft), 100_000_000);
        bxrnft.publicMint(1_000_000);

        bxrnft.approve(address(bxrnft), 1);
        bxrnft.listNFT(1, 1_000_000);
        assertEq(bxrnft.nftPrices(1), 1_000_000);
        vm.stopPrank();
    }

    function testUnlistedNFT() public {
        usdc.transfer(address(1), 100_000_000);
        vm.startPrank(address(1));
        usdc.approve(address(bxrnft), 100_000_000);
        bxrnft.publicMint(1_000_000);

        bxrnft.approve(address(bxrnft), 1);
        bxrnft.listNFT(1, 1_000_000);
        assertEq(bxrnft.nftPrices(1), 1_000_000);

        bxrnft.unlistNFT(1);
        assertEq(bxrnft.nftPrices(1), 0);
        vm.stopPrank();
    }

    function testBuyNFT() public {
        usdc.transfer(address(1), 50_000_000);
        usdc.transfer(address(2), 50_000_000);

        vm.startPrank(address(1));
        usdc.approve(address(bxrnft), 100_000_000);
        bxrnft.publicMint(1_000_000);

        bxrnft.approve(address(bxrnft), 1);
        bxrnft.listNFT(1, 2_000_000);
        assertEq(bxrnft.nftPrices(1), 2_000_000);
        vm.stopPrank();

        uint256 balanceBefore = usdc.balanceOf(address(1));

        vm.startPrank(address(2));
        usdc.approve(address(bxrnft), 10_000_000);
        // slippage 0, increase slippage by base price + (base price * max slippage)
        bxrnft.buyNFT(1, 2_000_000);
        vm.stopPrank();

        assertEq(bxrnft.nftPrices(1), 0);
        assertEq(bxrnft.ownerOf(1), address(2));
        assertEq(usdc.balanceOf(address(1)), balanceBefore + 2_000_000);
    }
}
