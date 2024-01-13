// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/*
GITHUB REPO LINK: https://github.com/Aravinds2511/TokenSale

DESIGN OF THE CONTRACT:

Handling Contributions: Users can contribute Ether to the contract during either the 
                        Presale or Public Sale phase, subject to certain conditions like minimum and 
                        maximum contribution limits, and phase-specific start and end times.

Token Distribution: The contract allows for the distribution of ERC20 tokens to contributors. 
                    The amount of tokens distributed corresponds to the Ether contributed, 
                    assuming a 1:1 Ether-to-token ratio.

Refund Mechanism: Contributors can claim refunds under certain conditions, depending on 
                  the sale phase and the total contributions relative to the hard cap.

Phase Management: The contract can transition from the Presale phase to the Public Sale phase, 
                  controlled by the contract owner.

Security Measures: It employs reentrancy protection and custom error handling to ensure 
                   secure and efficient contract operations.

Ownership Controls: Certain functions, like token distribution and phase transitions, 
                    are restricted to the contract owner.
*/

// ERC20 contract interface
interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenSale is ReentrancyGuard {
    ////////Error////////

    error OnlyOwner();
    error ContributionZero();
    error PresaleNotStarted();
    error PresaleEnded();
    error ContributionBelowMinimum();
    error PresaleHardCapReached();
    error MaxContributionExceeded();
    error PublicSaleNotStarted();
    error PublicSaleEnded();
    error PublicSaleHardCapReached();
    error InsufficientContractBalance();
    error TokenTransferFailed();
    error AmountZero();
    error NoPresaleContributionFound();
    error PresaleNotEnded();
    error NoPublicSaleContributionFound();
    error PublicSaleNotEnded();
    error NotPresalePhase();
    error PresaleStillActive();

    //////Events/////////

    event TokensPurchased(address buyer, uint256 amount);
    event RefundClaimed(address recipient, uint256 amount);
    event TokensDistribution(address recipient, uint256 amount);

    ///////State Variables//////////

    address public owner;
    IERC20 public token;

    uint256 public presaleHardCap;
    uint256 public presaleMinContribution;
    uint256 public presaleMaxContribution;
    uint256 public presaleStartTime;
    uint256 public presaleEndTime;

    uint256 public publicSaleHardCap;
    uint256 public publicSaleMinContribution;
    uint256 public publicSaleMaxContribution;
    uint256 public publicSaleStartTime;
    uint256 public publicSaleEndTime;

    uint256 public totalPresaleContributions;
    uint256 public totalPublicSaleContributions;
    uint256 public totalTokensSold;
    uint256 public totalpreSaleAmountRefunded;
    uint256 public totalpublicSaleAmountRefunded;

    mapping(address => uint256) public presaleContributions;
    mapping(address => uint256) public publicSaleContributions;
    mapping(address => uint256) public claimedTokens;

    enum SalePhase {
        Presale,
        PublicSale
    }

    SalePhase public currentSalePhase;

    ////////Modifiers///////

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    //////////Constructor/////////

    constructor(
        address _tokenAddress,
        uint256 _presaleHardCap,
        uint256 _presaleMinContribution,
        uint256 _presaleMaxContribution,
        uint256 _publicSaleHardCap,
        uint256 _publicSaleMinContribution,
        uint256 _publicSaleMaxContribution,
        uint256 _presaleStartTime,
        uint256 _presaleEndTime,
        uint256 _publicSaleStartTime,
        uint256 _publicSaleEndTime
    ) {
        owner = msg.sender;
        token = IERC20(_tokenAddress);
        presaleHardCap = _presaleHardCap;
        presaleMinContribution = _presaleMinContribution;
        presaleMaxContribution = _presaleMaxContribution;
        publicSaleHardCap = _publicSaleHardCap;
        publicSaleMinContribution = _publicSaleMinContribution;
        publicSaleMaxContribution = _publicSaleMaxContribution;
        currentSalePhase = SalePhase.Presale;
        presaleStartTime = _presaleStartTime;
        presaleEndTime = _presaleEndTime;
        publicSaleStartTime = _publicSaleStartTime;
        publicSaleEndTime = _publicSaleEndTime;
    }

    ////////////Functions//////////

    function contribute() external payable nonReentrant {
        if (msg.value == 0) revert ContributionZero();

        if (currentSalePhase == SalePhase.Presale) {
            if (block.timestamp < presaleStartTime) revert PresaleNotStarted();
            if (block.timestamp > presaleEndTime) revert PresaleEnded();
            if (msg.value < presaleMinContribution) revert ContributionBelowMinimum();
            if (address(this).balance > presaleHardCap) revert PresaleHardCapReached();
            if (presaleContributions[msg.sender] + msg.value > presaleMaxContribution) {
                revert MaxContributionExceeded();
            }
            presaleContributions[msg.sender] += msg.value;
            totalPresaleContributions += msg.value;
            totalTokensSold += msg.value;
        } else {
            if (block.timestamp < publicSaleStartTime) revert PublicSaleNotStarted();
            if (block.timestamp > publicSaleEndTime) revert PublicSaleEnded();
            if (msg.value < publicSaleMinContribution) revert ContributionBelowMinimum();
            if (address(this).balance > publicSaleHardCap) revert PublicSaleHardCapReached();
            if (publicSaleContributions[msg.sender] + msg.value > publicSaleMaxContribution) {
                revert MaxContributionExceeded();
            }
            publicSaleContributions[msg.sender] += msg.value;
            totalPublicSaleContributions += msg.value;
            totalTokensSold += msg.value;
        }

        uint256 tokensToTransfer = msg.value; //assuming 1 Ether == 1 token
        if (token.balanceOf(address(this)) < tokensToTransfer) revert InsufficientContractBalance();
        if (!token.transfer(msg.sender, tokensToTransfer)) revert TokenTransferFailed();

        claimedTokens[msg.sender] += tokensToTransfer;

        emit TokensPurchased(msg.sender, tokensToTransfer);
    }

    function distributeTokens(address recipient, uint256 amount) external onlyOwner nonReentrant {
        if (amount == 0) revert AmountZero();
        if (token.balanceOf(address(this)) < amount) revert InsufficientContractBalance();
        if (!token.transfer(recipient, amount)) revert TokenTransferFailed();
        emit TokensDistribution(recipient, amount);
    }

    function claimRefund() external nonReentrant {
        uint256 refundAmount;
        if (currentSalePhase == SalePhase.Presale) {
            if (presaleContributions[msg.sender] == 0) revert NoPresaleContributionFound();
            if (block.timestamp <= presaleEndTime) revert PresaleNotEnded();
            if (totalPresaleContributions >= presaleHardCap) revert PresaleHardCapReached();
            refundAmount = presaleContributions[msg.sender];
            presaleContributions[msg.sender] = 0;
            totalpreSaleAmountRefunded += refundAmount;
        } else {
            if (publicSaleContributions[msg.sender] == 0) revert NoPublicSaleContributionFound();
            if (block.timestamp <= publicSaleEndTime) revert PublicSaleNotEnded();
            if (totalPublicSaleContributions >= publicSaleHardCap) revert PublicSaleHardCapReached();
            refundAmount = publicSaleContributions[msg.sender];
            publicSaleContributions[msg.sender] = 0;
            totalpublicSaleAmountRefunded += refundAmount;
        }

        if (refundAmount == 0) revert ContributionZero();
        payable(msg.sender).transfer(refundAmount);

        emit RefundClaimed(msg.sender, refundAmount);
    }

    function changeCurrentPhasetoPublicSale() external onlyOwner {
        if (currentSalePhase != SalePhase.Presale) revert NotPresalePhase();
        if (block.timestamp <= presaleEndTime) revert PresaleStillActive();
        currentSalePhase = SalePhase.PublicSale;
    }
}
