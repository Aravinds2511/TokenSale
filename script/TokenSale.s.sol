// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {TokenSale} from "../src/TokenSale.sol";
//import {ERC20Token} from "../src/ERC20Token.sol";

contract DeployTokenSale is Script {
    function run() external returns (ERC20Token, TokenSale) {
        // Load private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy ERC20Token contract
        ERC20Token token = new ERC20Token("MyToken", "MTK", 18, 100000000);

        // Deploy TokenSale contract
        TokenSale tokenSale = new TokenSale(
            address(token),
            20 ether, // Presale Cap
            1 ether,      // Presale Min Contribution
            10 ether,     // Presale Max Contribution
            10 ether, // Public Sale Cap
            0.1 ether,    // Public Sale Min Contribution
            5 ether       // Public Sale Max Contribution
        );

        token.transferOwnership(address(tokenSale));
        vm.stopBroadcast();
        return (token, tokenSale);
    }
}
