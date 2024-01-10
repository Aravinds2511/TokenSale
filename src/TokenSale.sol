// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./ERC20Token.sol";

contract TokenSale {
    address public owner;
    ERC20Token public token;

    uint256 public presaleCap;
    uint256 public presaleMinContribution;
    uint256 public presaleMaxContribution;

    uint256 public publicSaleCap;
    uint256 public publicSaleMinContribution;
    uint256 public publicSaleMaxContribution;

    mapping(address => uint256) public presaleContributions;
    mapping(address => uint256) public publicSaleContributions;
    mapping(address => uint256) public claimedTokens;

    enum SalePhase {
        Presale,
        PublicSale
    }

    SalePhase public currentSalePhase;

    event TokensPurchased(address buyer, uint256 amount);
    event RefundClaimed(address recipient, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function");
        _;
    }

    constructor(
        address _tokenAddress,
        uint256 _presaleCap,
        uint256 _presaleMinContribution,
        uint256 _presaleMaxContribution,
        uint256 _publicSaleCap,
        uint256 _publicSaleMinContribution,
        uint256 _publicSaleMaxContribution
    ) {
        owner = msg.sender;
        token = ERC20Token(_tokenAddress); // Use the ERC20Token contract interface
        presaleCap = _presaleCap;
        presaleMinContribution = _presaleMinContribution;
        presaleMaxContribution = _presaleMaxContribution;
        publicSaleCap = _publicSaleCap;
        publicSaleMinContribution = _publicSaleMinContribution;
        publicSaleMaxContribution = _publicSaleMaxContribution;
        currentSalePhase = SalePhase.Presale;
    }

    function contribute() external payable {
        require(msg.value > 0, "Contribution amount must be greater than zero");

        if (currentSalePhase == SalePhase.Presale) {
            require(
                presaleContributions[msg.sender] + msg.value <= presaleMaxContribution, "Exceeds maximum contribution"
            );
            require(address(this).balance + msg.value <= presaleCap, "Presale cap reached");
            presaleContributions[msg.sender] += msg.value;
        } else {
            require(
                publicSaleContributions[msg.sender] + msg.value <= publicSaleMaxContribution,
                "Exceeds maximum contribution"
            );
            require(address(this).balance + msg.value <= publicSaleCap, "Public sale cap reached");
            publicSaleContributions[msg.sender] += msg.value;
        }

        uint256 tokensToTransfer = msg.value; // For simplicity, 1 Ether = 1 token
        require(token.balanceOf(address(this)) >= tokensToTransfer, "Not enough tokens in the contract");
        require(token.transfer(msg.sender, tokensToTransfer), "Token transfer failed");

        claimedTokens[msg.sender] += tokensToTransfer;

        emit TokensPurchased(msg.sender, tokensToTransfer);
    }

    function claimRefund() external {
        uint256 refundAmount;

        if (currentSalePhase == SalePhase.Presale) {
            require(presaleContributions[msg.sender] > 0, "No presale contribution found");
            require(address(this).balance < presaleCap, "Presale cap reached");
            refundAmount = presaleContributions[msg.sender];
            presaleContributions[msg.sender] = 0;
        } else {
            require(publicSaleContributions[msg.sender] > 0, "No public sale contribution found");
            require(address(this).balance < publicSaleCap, "Public sale cap reached");
            refundAmount = publicSaleContributions[msg.sender];
            publicSaleContributions[msg.sender] = 0;
        }

        require(refundAmount > 0, "No funds to refund");
        payable(msg.sender).transfer(refundAmount);

        emit RefundClaimed(msg.sender, refundAmount);
    }

    function setCurrentSalePhase(SalePhase phase) external onlyOwner {
        currentSalePhase = phase;
    }

    function distributeTokens(address recipient, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
        require(token.balanceOf(address(this)) >= amount, "Not enough tokens in the contract");
        require(token.transfer(recipient, amount), "Token transfer failed");
    }
}
