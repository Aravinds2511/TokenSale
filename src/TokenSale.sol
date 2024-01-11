// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable {
    constructor() ERC20("MyToken", "MTK") {
        _mint(msg.sender, 1000000000000000000000000000); // 1 billion tokens with 18 decimals
    }
}

contract TokenSale is Ownable {
    MyToken public token;

    uint256 public presaleCap;
    uint256 public publicSaleCap;

    uint256 public presaleMinContribution;
    uint256 public presaleMaxContribution;

    uint256 public publicSaleMinContribution;
    uint256 public publicSaleMaxContribution;

    uint256 public presaleEndTime;
    uint256 public publicSaleStartTime;

    mapping(address => uint256) public presaleContributions;
    mapping(address => uint256) public publicSaleContributions;

    event PresaleContribution(address indexed contributor, uint256 amount);
    event PublicSaleContribution(address indexed contributor, uint256 amount);
    event TokenDistribution(address indexed receiver, uint256 amount);

    constructor(
        MyToken _token,
        uint256 _presaleCap,
        uint256 _publicSaleCap,
        uint256 _presaleMinContribution,
        uint256 _presaleMaxContribution,
        uint256 _publicSaleMinContribution,
        uint256 _publicSaleMaxContribution,
        uint256 _presaleEndTime,
        uint256 _publicSaleStartTime
    ) {
        token = _token;
        presaleCap = _presaleCap;
        publicSaleCap = _publicSaleCap;
        presaleMinContribution = _presaleMinContribution;
        presaleMaxContribution = _presaleMaxContribution;
        publicSaleMinContribution = _publicSaleMinContribution;
        publicSaleMaxContribution = _publicSaleMaxContribution;
        presaleEndTime = _presaleEndTime;
        publicSaleStartTime = _publicSaleStartTime;
    }

    modifier duringPresale() {
        require(block.timestamp < presaleEndTime, "Presale has ended");
        _;
    }

    modifier duringPublicSale() {
        require(block.timestamp >= publicSaleStartTime && block.timestamp < presaleEndTime, "Public sale is not active");
        _;
    }

    function contributeToPresale() external payable duringPresale {
        require(
            presaleContributions[msg.sender] + (msg.value) >= presaleMinContribution,
            "Contribution is below the minimum limit"
        );
        require(
            presaleContributions[msg.sender] + (msg.value) <= presaleMaxContribution,
            "Contribution is above the maximum limit"
        );
        require(address(this).balance + (msg.value) <= presaleCap, "Presale cap reached");

        presaleContributions[msg.sender] = presaleContributions[msg.sender] + (msg.value);
        emit PresaleContribution(msg.sender, msg.value);

        distributeTokens(msg.sender, 2 * msg.value); //// 2 times the eth as incentive
    }

    function contributeToPublicSale() external payable duringPublicSale {
        require(
            publicSaleContributions[msg.sender] + (msg.value) >= publicSaleMinContribution,
            "Contribution is below the minimum limit"
        );
        require(
            publicSaleContributions[msg.sender] + (msg.value) <= publicSaleMaxContribution,
            "Contribution is above the maximum limit"
        );
        require(address(this).balance + (msg.value) <= publicSaleCap, "Public sale cap reached");

        publicSaleContributions[msg.sender] = publicSaleContributions[msg.sender] + (msg.value);
        emit PublicSaleContribution(msg.sender, msg.value);

        distributeTokens(msg.sender, msg.value);
    }

    function distributeTokens(address _receiver, uint256 _contribution) internal {
        uint256 tokenAmount = _contribution; // Assuming 1 ETH = 1 Token for simplicity
        token.transfer(_receiver, tokenAmount);
        emit TokenDistribution(_receiver, tokenAmount);
    }

    function distributeTokensTo(address _receiver, uint256 _amount) external onlyOwner {
        token.transfer(_receiver, _amount);
        emit TokenDistribution(_receiver, _amount);
    }

    function claimRefund() external {
        require(block.timestamp >= presaleEndTime, "Presale is still active");
        require(
            address(this).balance < presaleCap || address(this).balance < publicSaleCap,
            "Funds raised are above the minimum cap"
        );

        uint256 presaleContribution = presaleContributions[msg.sender];
        uint256 publicSaleContribution = publicSaleContributions[msg.sender];

        require(presaleContribution > 0 || publicSaleContribution > 0, "No contributions");

        if (presaleContribution > 0) {
            presaleContributions[msg.sender] = 0;
            payable(msg.sender).transfer(presaleContribution);
        }

        if (publicSaleContribution > 0) {
            publicSaleContributions[msg.sender] = 0;
            payable(msg.sender).transfer(publicSaleContribution);
        }
    }

    receive() external payable {
        revert("Fallback function not allowed");
    }
}
