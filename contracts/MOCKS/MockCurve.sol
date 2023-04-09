// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";
contract MockCurve {
	
	IERC20 public stETH;
	mapping (address => uint256[]) public userDepositTimestamp;
	mapping (uint256 => uint256) public userDepositBalances;
	mapping (uint256 => uint256) public lastClaimPerTimestamp;
	uint256 public minimumTime = 3600;
	uint256 public rewardPerMinimumTime = 0.02 ether;
	constructor(address _stETH){
		stETH = IERC20(_stETH);
	}
	
	function deposit(uint256 amount, address from) external {
		stETH.transferFrom(from, address(this), amount);
		userDepositTimestamp[from].push(block.timestamp);
		userDepositBalances[block.timestamp] += amount;
	}
	
	function getUnclaimedRewards(address _user) public view returns (uint256 finalBalance) {
		uint256 totalDeposit = userDepositTimestamp[_user].length;
		for (uint256 i =0; i < totalDeposit; i++) {
			uint256 depositTime =  userDepositTimestamp[_user][i];
			uint256 totalTimeSpent;
			if (lastClaimPerTimestamp[depositTime] == 0) {
				totalTimeSpent = block.timestamp - depositTime;
			} else {
				totalTimeSpent = block.timestamp -  lastClaimPerTimestamp[depositTime];
			}
			totalTimeSpent /= minimumTime;
			finalBalance +=  (totalTimeSpent * rewardPerMinimumTime);
		}
		return finalBalance;
	}
	
	function withdraw(uint256 amount, address to) external {
		uint256 totalDeposit = userDepositTimestamp[to].length;
		for (uint256 i =0; i< totalDeposit; i++) {
			uint256 depositTime =  userDepositTimestamp[to][i];
			if (userDepositBalances[depositTime] > amount) {
				userDepositBalances[depositTime] -= amount;
			} else {
				amount -= userDepositBalances[depositTime];
				userDepositBalances[depositTime] = 0;
			}
		}
		stETH.transfer(to, amount);
	}
	
	function claimRewards(address to) external returns (uint256) {
		uint256 reward = getUnclaimedRewards(to);
		uint256 totalDeposit = userDepositTimestamp[to].length;
		for (uint256 i =0; i< totalDeposit; i++) {
			uint256 depositTime =  userDepositTimestamp[to][i];
			lastClaimPerTimestamp[depositTime] = block.timestamp;
		}
		stETH.transfer(to,reward);
		return reward;
	}
	
}
