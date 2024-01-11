// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {TokenSale} from "../src/TokenSale.sol";
//import {ERC20Token} from "../src/ERC20Token.sol";
import {DeployTokenSale} from "../script/TokenSale.s.sol";

contract TokenSaleTest is Test {
    TokenSale tokenSale;
    ERC20Token erc20Token;

    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;

    function setUp() public {
        DeployTokenSale deployTokenSale = new DeployTokenSale();
        (erc20Token, tokenSale) = deployTokenSale.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    ///////////constructor Args//////////

    function testPresaleCap() public {
        assertEq(tokenSale.presaleCap(), 20 ether);
    }

    function testPresaleMinContribution() public {
        assertEq(tokenSale.presaleMinContribution(), 1 ether);
    }

    function testPresaleMaxContribution() public {
        assertEq(tokenSale.presaleMaxContribution(), 10 ether);
    }

    function testPublicSaleCap() public {
        assertEq(tokenSale.publicSaleCap(), 10 ether);
    }

    function testPublicSaleMinContribution() public {
        assertEq(tokenSale.publicSaleMinContribution(), 0.1 ether);
    }

    function testPublicSaleMaxContribution() public {
        assertEq(tokenSale.publicSaleMaxContribution(), 5 ether);
    }

    function testContributeFunction() public {
        vm.startPrank(USER);
        tokenSale.contribute{value: SEND_VALUE}();
        assertEq(erc20Token.balanceOf(USER), 1 ether);
        vm.stopPrank();
    }
}
