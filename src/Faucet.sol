// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IFaucet} from "./IFaucet.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {FaucetEvents} from "./FaucetEvents.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract Faucet is IFaucet, Ownable, FaucetEvents, ReentrancyGuard {
    address public whitelistNFTAddress;

    uint256 public claimAmount;
    uint256 public cooldownDuration; // in seconds
    mapping(address => uint256) private lastClaimTimes;

    constructor(
        address _whitelistNFTAddress,
        uint256 _claimAmount,
        uint256 _cooldownDuration
    ) Ownable(msg.sender) {
        whitelistNFTAddress = _whitelistNFTAddress;
        claimAmount = _claimAmount;
        cooldownDuration = _cooldownDuration;
    }

    /**
     * @dev Returns the current balance of the faucet.
     */
    function balance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Returns the block time at which eth was claimed by `account`.
     */
    function lastClaimed(address account) external view returns (uint256) {
        return lastClaimTimes[account];
    }

    /**
     * @dev Moves tokens from the faucet account to `to`.
     *
     * It makes a call to the `balanceOf` method of the Whitelist NFT collection, to make sure that address `to` holds a whitelist NFT.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Claim} event.
     */
    function claim(address payable to) external nonReentrant returns (bool) {
        require(
            IERC721(whitelistNFTAddress).balanceOf(to) > 0,
            "WhitelistNFT: Account is not whitelisted"
        );

        require((lastClaimTimes[to] == 0) || (block.timestamp >= (lastClaimTimes[to] + cooldownDuration)), "Faucet: Claim too soon.");

        // Update the last claim time first to guard against reentrancy
        lastClaimTimes[to] = block.timestamp;
        
        (bool isSuccess, ) = to.call{value: claimAmount}("");
        require(isSuccess, "Failed to send Ether");

        emit Claim(to, claimAmount, block.timestamp);

        return isSuccess;
    }

    /**
     *  @dev allows anyone to deposit to the faucet
     *
     * Emits a {Funded} event.
     */
    function fundFaucet() external payable returns (uint256) {
        emit Funded(msg.sender, msg.value, block.timestamp);

        return address(this).balance;
    }

    /**
     * @dev changes the current being funded per address to `amount`.
     *
     * This function should only be callable by the contract owner
     *
     * Emits a {AmountChanged} event.
     */
    function setAmount(uint256 amount) external onlyOwner returns (bool) {
        claimAmount = amount;

        emit AmountChanged(msg.sender, amount, block.timestamp);

        return true;
    }

    /**
     * @dev changes the current time interval between two claims to `duration`,
     * which is measured in block timestamps
     *
     * This function should only be callable by the contract owner
     *
     * Emits a {DurationChanged} event.
     */
    function setDuration(uint256 duration) external onlyOwner returns (bool) {
        cooldownDuration = duration;

        emit DurationChanged(msg.sender, duration, block.timestamp);

        return true;
    }


    /**
     * @dev changes the nft collection address that is checked for whitelist access
     *
     * This function should only be callable by the contract owner
     */
     function setNFTAddress(address newAddress) external onlyOwner returns (bool) {
        whitelistNFTAddress = newAddress;

        emit NFTChanged(msg.sender, newAddress, block.timestamp);
        return true;
     }
}
