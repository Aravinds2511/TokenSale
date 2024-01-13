// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "ds-test/test.sol";
import {TokenA} from "../src/TokenA.sol";
import {TokenSale} from "../src/TokenSale.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";

contract TokenSaleTest is DSTest {
    TokenSale tokenSale;
    TokenA token;
    address owner;
    Vm vm = Vm(HEVM_ADDRESS);

    uint256 presaleHardCap = 30 ether;
    uint256 presaleMinContribution = 0.1 ether;
    uint256 presaleMaxContribution = 10 ether;
    uint256 publicSaleHardCap = 30 ether;
    uint256 publicSaleMinContribution = 0.1 ether;
    uint256 publicSaleMaxContribution = 20 ether;
    uint256 presaleStartTime = block.timestamp; //start immediately for testing
    uint256 presaleEndTime = presaleStartTime + 1 days;
    uint256 publicSaleStartTime = presaleEndTime; //public sale starts right after presale
    uint256 publicSaleEndTime = publicSaleStartTime + 5 days;

    //setup function
    function setUp() public {
        owner = address(this);
        token = new TokenA(10000 * 1e18);

        //initialize TokenSale contract
        tokenSale = new TokenSale(
            address(token),
            presaleHardCap,
            presaleMinContribution,
            presaleMaxContribution,
            publicSaleHardCap,
            publicSaleMinContribution,
            publicSaleMaxContribution,
            presaleStartTime,
            presaleEndTime,
            publicSaleStartTime,
            publicSaleEndTime
        );
        token.transfer(address(tokenSale), 10000 * 1e18);
    }

    //testing contribute function (presale)

    function testSuccessfulContributionPresale() public {
        uint256 contributionAmount = 1 ether;
        uint256 expectedTokenAmount = contributionAmount; //assuming 1 Ether = 1 token

        //user sending Ether to contribute
        address user = address(1);
        vm.deal(user, contributionAmount);
        vm.startPrank(user);
        tokenSale.contribute{value: contributionAmount}();
        vm.stopPrank();

        //validate contribution is recorded correctly
        uint256 userTokenBalance = token.balanceOf(user);
        assertEq(userTokenBalance, expectedTokenAmount, "User should receive correct amount of tokens");
        uint256 recordedContribution = tokenSale.presaleContributions(user);
        assertEq(recordedContribution, contributionAmount, "Contribution should be recorded correctly");
    }

    function testContributionBelowMinimumLimit() public {
        uint256 lowContributionAmount = 0.05 ether;

        //user sending Ether to contribute
        address user = address(1);
        vm.deal(user, lowContributionAmount);
        vm.startPrank(user);
        //contribution amount below minimum limit
        vm.expectRevert(abi.encodeWithSelector(TokenSale.ContributionBelowMinimum.selector));
        tokenSale.contribute{value: lowContributionAmount}();
        vm.stopPrank();
    }

    function testContributionAboveMaximumLimit() public {
        uint256 highContributionAmount = 15 ether;

        //user sending Ether to contribute
        address user = address(1);
        vm.deal(user, highContributionAmount);
        vm.startPrank(user);
        //contribution amount above maximum limit
        vm.expectRevert(abi.encodeWithSelector(TokenSale.MaxContributionExceeded.selector));
        tokenSale.contribute{value: highContributionAmount}();
        vm.stopPrank();
    }

    function testContributionAfterPresaleEnds() public {
        uint256 contributionAmount = 1 ether;

        //user sending Ether to contribute
        address user = address(1);
        vm.deal(user, contributionAmount);
        vm.startPrank(user);
        //block timestamp changes to a point after the presale ends
        vm.warp(presaleEndTime + 1);
        //contribute after the presale end time
        vm.expectRevert(abi.encodeWithSelector(TokenSale.PresaleEnded.selector));
        tokenSale.contribute{value: contributionAmount}();
        vm.stopPrank();
    }

    function testContributionBeforePresaleStarts() public {
        uint256 contributionAmount = 1 ether;

        //user sending Ether to contribute
        address user = address(1);
        vm.deal(user, contributionAmount);
        vm.startPrank(user);
        //block timestamp changes to a point before the presale ends
        vm.warp(presaleStartTime - 1);
        //contribute before the presale start time
        vm.expectRevert(abi.encodeWithSelector(TokenSale.PresaleNotStarted.selector));
        tokenSale.contribute{value: contributionAmount}();
        vm.stopPrank();
    }

    function testHardCapEnforcementPresale() public {
        uint256 contributionAmount = 10 ether;
        uint256 ExtraAmount = 4 ether;

        //a user sending Ether to reach the hard cap
        address user1 = address(1);
        vm.deal(user1, contributionAmount);
        vm.startPrank(user1);
        tokenSale.contribute{value: contributionAmount}();
        vm.stopPrank();

        address user2 = address(2);
        vm.deal(user2, contributionAmount);
        vm.startPrank(user2);
        tokenSale.contribute{value: contributionAmount}();
        vm.stopPrank();

        address user3 = address(3);
        vm.deal(user3, 8 ether);
        vm.startPrank(user3);
        tokenSale.contribute{value: 8 ether}();
        vm.stopPrank();

        //another user trying to contribute after the hard cap is reached
        address user4 = address(4);
        vm.deal(user4, ExtraAmount);
        vm.startPrank(user4);
        //reverts since hard cap being reached
        vm.expectRevert(abi.encodeWithSelector(TokenSale.PresaleHardCapReached.selector));
        tokenSale.contribute{value: ExtraAmount}();
        vm.stopPrank();
    }

    //testing contribute function (pubicsale)

    function testSuccessfulContributionPublicSale() public {
        uint256 contributionAmount = 1 ether;
        uint256 expectedTokenAmount = contributionAmount; //assuming 1 Ether = 1 token
        //warp to public sale start time
        vm.warp(publicSaleStartTime + 1);
        tokenSale.changeCurrentPhasetoPublicSale();

        //a user sending Ether to contribute
        address user = address(1);
        vm.deal(user, contributionAmount);
        vm.startPrank(user);
        tokenSale.contribute{value: contributionAmount}();
        vm.stopPrank();

        //validate contribution is recorded correctly
        uint256 userTokenBalance = token.balanceOf(user);
        assertEq(userTokenBalance, expectedTokenAmount, "User should receive correct amount of tokens");
        uint256 recordedContribution = tokenSale.publicSaleContributions(user);
        assertEq(recordedContribution, contributionAmount, "Contribution should be recorded correctly");
    }

    function testContributionAfterPublicSaleEnds() public {
        uint256 contributionAmount = 1 ether;
        //warp to public sale start time
        vm.warp(publicSaleStartTime + 1);
        tokenSale.changeCurrentPhasetoPublicSale();

        //a user sending Ether to contribute
        address user = address(1);
        vm.deal(user, contributionAmount);
        vm.startPrank(user);
        //block timestamp changes to a point after the publicsale ends
        vm.warp(publicSaleEndTime + 1);
        //contribute after the public sale end time
        vm.expectRevert(abi.encodeWithSelector(TokenSale.PublicSaleEnded.selector));
        tokenSale.contribute{value: contributionAmount}();
        vm.stopPrank();
    }

    //testing insufficient tokens in contract

    function testInsufficientTokenCase() public {
        address user = address(1);
        tokenSale.distributeTokens(user, 10000 * 1e18);
        uint256 contributionAmount = 1 ether;

        //a user sending Ether to contribute
        vm.deal(user, contributionAmount);
        vm.startPrank(user);
        //contribute when token is insufficient
        vm.expectRevert(abi.encodeWithSelector(TokenSale.InsufficientContractBalance.selector));
        tokenSale.contribute{value: contributionAmount}();
        vm.stopPrank();
    }

    //testing distributeTokens function

    function testDistributeTokens() public {
        uint256 distributeAmount = 10 ether;
        address recipient = address(1);
        uint256 initialRecipientBalance = token.balanceOf(recipient);

        //only owner should be able to distribute tokens
        vm.startPrank(owner);
        tokenSale.distributeTokens(recipient, distributeAmount);
        vm.stopPrank();
        //final recipient balance
        uint256 finalRecipientBalance = token.balanceOf(recipient);
        assertEq(
            finalRecipientBalance,
            initialRecipientBalance + distributeAmount,
            "Recipient should receive the correct amount of tokens"
        );

        //attempt distribution by a non-owner, expecting a revert
        vm.startPrank(address(2));
        vm.expectRevert(abi.encodeWithSelector(TokenSale.OnlyOwner.selector));
        tokenSale.distributeTokens(recipient, distributeAmount);
        vm.stopPrank();
    }

    function testChangeCurrentPhaseToPublicSale() public {
        //warp to a time after the presale has ended
        vm.warp(presaleEndTime + 1);
        //check initial sale phase
        assertEq(
            uint256(tokenSale.currentSalePhase()),
            uint256(TokenSale.SalePhase.Presale),
            "Initial phase should be Presale"
        );

        //only owner should be able to change the phase
        vm.startPrank(owner);
        tokenSale.changeCurrentPhasetoPublicSale();
        vm.stopPrank();
        //check that the sale phase changed to public sale
        assertEq(
            uint256(tokenSale.currentSalePhase()),
            uint256(TokenSale.SalePhase.PublicSale),
            "Phase should be changed to PublicSale"
        );

        //phase change by a non-owner
        vm.startPrank(address(2));
        vm.expectRevert(abi.encodeWithSelector(TokenSale.OnlyOwner.selector));
        tokenSale.changeCurrentPhasetoPublicSale();
        vm.stopPrank();

        //change phase when not in Presale
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(TokenSale.NotPresalePhase.selector));
        tokenSale.changeCurrentPhasetoPublicSale();
        vm.stopPrank();
    }

    //testing claimRefund function (presale)

    function testClaimRefundPresaleConditionsMet() public {
        //assume presale contribution was made by a user
        address user = address(2);
        uint256 userContribution = 1 ether;
        vm.deal(user, userContribution);

        //presale contribution by the user
        vm.startPrank(user);
        tokenSale.contribute{value: userContribution}();
        vm.stopPrank();
        //warp to after presale end time, hardcap not reached
        vm.warp(presaleEndTime + 1);

        //user claims refund
        uint256 initialBalance = user.balance;
        vm.prank(user);
        tokenSale.claimRefund();
        //check user balance increased by contribution
        uint256 finalBalance = user.balance;
        assertEq(finalBalance, initialBalance + userContribution, "User should receive refund");
    }

    function testClaimRefundPresaleConditionsNotMet() public {
        uint256 contributionAmount = 10 ether;

        //users sending Ether to reach the hard cap
        address user1 = address(1);
        vm.deal(user1, contributionAmount);
        vm.startPrank(user1);
        tokenSale.contribute{value: contributionAmount}();
        vm.stopPrank();

        address user2 = address(2);
        vm.deal(user2, contributionAmount);
        vm.startPrank(user2);
        tokenSale.contribute{value: contributionAmount}();
        vm.stopPrank();

        address user3 = address(3);
        vm.deal(user3, contributionAmount);
        vm.startPrank(user3);
        tokenSale.contribute{value: contributionAmount}();
        vm.stopPrank();

        //warp to after presale end time, hardcap reached
        vm.warp(presaleEndTime + 1);
        //user claims refund
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(TokenSale.PresaleHardCapReached.selector));
        tokenSale.claimRefund();
    }

    function testClaimRefundinOngoingPresale() public {
        //assume presale contribution was made by a user
        address user = address(1);
        uint256 userContribution = 1 ether;
        vm.deal(user, userContribution);

        //simulate presale contribution
        vm.startPrank(user);
        tokenSale.contribute{value: userContribution}();
        vm.stopPrank();

        //user claims refund
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(TokenSale.PresaleNotEnded.selector));
        tokenSale.claimRefund();
    }

    function testClaimRefundWhenNoContribution() public {
        address user = address(1);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(TokenSale.NoPresaleContributionFound.selector));
        tokenSale.claimRefund();
    }

    // testing claimRefund function (publicsale)
    function testClaimRefundPublicSaleConditionsMet() public {
        //wrap to public sale time
        vm.warp(presaleEndTime + 1);
        tokenSale.changeCurrentPhasetoPublicSale();

        uint256 contributionAmount = 1 ether;
        //a user sending Ether to reach the hard cap
        address user1 = address(2);
        vm.deal(user1, contributionAmount);
        vm.startPrank(user1);
        tokenSale.contribute{value: contributionAmount}();
        vm.stopPrank();
        //wrap time after publicsale ends
        vm.warp(publicSaleEndTime + 1);

        //user claims refund
        uint256 initialBalance = user1.balance;
        vm.prank(user1);
        tokenSale.claimRefund();
        uint256 finalBalance = user1.balance;
        assertEq(finalBalance, (initialBalance + contributionAmount), "User should receive refund");
    }

    function testClaimRefundPublicSaleConditionsNotMet() public {
        //wrap to public sale time
        vm.warp(presaleEndTime + 1);
        tokenSale.changeCurrentPhasetoPublicSale();

        uint256 contributionAmount = 10 ether;

        //a user sending Ether to reach the hard cap
        address user1 = address(1);
        vm.deal(user1, contributionAmount);
        vm.startPrank(user1);
        tokenSale.contribute{value: contributionAmount}();
        vm.stopPrank();

        address user2 = address(2);
        vm.deal(user2, contributionAmount);
        vm.startPrank(user2);
        tokenSale.contribute{value: contributionAmount}();
        vm.stopPrank();

        address user3 = address(3);
        vm.deal(user3, contributionAmount);
        vm.startPrank(user3);
        tokenSale.contribute{value: contributionAmount}();
        vm.stopPrank();

        //wrap time after publicsale ends
        vm.warp(publicSaleEndTime + 1);
        //user claims refund
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(TokenSale.PublicSaleHardCapReached.selector));
        tokenSale.claimRefund();
    }

    function testClaimRefundinOngoingPublicSale() public {
        //wrap time to public sale
        vm.warp(presaleEndTime + 1);
        tokenSale.changeCurrentPhasetoPublicSale();

        //assume presale contribution was made by a user
        address user = address(2);
        uint256 userContribution = 1 ether;
        vm.deal(user, userContribution);
        vm.startPrank(user);
        tokenSale.contribute{value: userContribution}();
        vm.stopPrank();

        //user claims refund
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(TokenSale.PublicSaleNotEnded.selector));
        tokenSale.claimRefund();
    }

    function testClaimRefundWhenNoPublicSaleContribution() public {
        //wrap time to public sale
        vm.warp(presaleEndTime + 1);
        tokenSale.changeCurrentPhasetoPublicSale();
        //user claims refund
        address user = address(2);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(TokenSale.NoPublicSaleContributionFound.selector));
        tokenSale.claimRefund();
    }
}
