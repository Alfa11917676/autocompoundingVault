// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ICurve {
    
    function deposit(uint256 amount, address from) external;
    
    function getUnclaimedRewards(address user) external view returns (uint256);
    
    function withdraw(uint256 amount, address from) external payable;
    
    function claimRewards(address to) external returns (uint256);
}
