// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interface/ILido.sol";
import "./interface/ICurve.sol";
import "hardhat/console.sol";

contract Vault {
    
    error UpkeepNotNeeded();
    error RewardTooLow();
    error InsufficientBalance();
    
    enum StakingPlatform { Lido, Curve }
    StakingPlatform public constant Lido = StakingPlatform.Lido;
    StakingPlatform public constant Curve = StakingPlatform.Curve;
    
    
    IERC20 public stETH;
    ILido public lido;
    ICurve public curve;
    
    uint32 public minimumTimeBetweenRewards = 3600;
    uint32 public lastRewardTimestamp;
    uint32 public lastClaimTimestamp;
    uint256 public PRECISION = 10e8;
    uint256 public lidoRewardCount;
    uint256 public curveRewardCount;
    uint256 public totalDepositInLidoBalance;
    uint256 public totalDepositInCurveBalance;
    address public treasury;
    uint256 public minimumRewardAmount = 0.001 ether;
    uint256 public lastLidoRewardAmount;
    uint256 public lastCurveRewardAmount;
    mapping (address => uint256) public userLastClaimTimestamp;
    mapping (bytes => uint256) public userDepositBalances;
    mapping (bytes => uint256) public totalRewardReceivedByUser;
    
    
	constructor(address stETHAddress, address lidoAddress, address curveAddress, address treasuryAddress) {
        stETH = IERC20(stETHAddress);
        lido = ILido(lidoAddress);
        curve = ICurve(curveAddress);
        treasury = treasuryAddress;
        lastRewardTimestamp = uint32(block.timestamp);
    }
    
    // user deposits stETH into the vault
    function deposit(uint256 amount, StakingPlatform platform) external {
        reBalanceReward();
        stETH.transferFrom(msg.sender, treasury, amount);
        if (platform == Lido) {
            userDepositBalances[abi.encodePacked(msg.sender,Lido)] += amount;
            totalDepositInLidoBalance += amount;
            lido.deposit(amount, treasury);
        } else if (platform == Curve) {
            userDepositBalances[abi.encodePacked(msg.sender,Curve)] += amount;
            totalDepositInCurveBalance += amount;
            curve.deposit(amount, treasury);
        }
    }
    
    // user withdraws stETH from the vault
    function withdraw(uint256 amount, StakingPlatform platform) external {
        reBalanceReward();
        if (platform == Lido) {
            if (userDepositBalances[abi.encodePacked(msg.sender,Lido)] < amount ) {
                revert InsufficientBalance();
            }
            userDepositBalances[abi.encodePacked(msg.sender,Lido)] -= amount;
            totalDepositInLidoBalance -= amount;
            lido.withdraw(amount, treasury);
        } else if (platform == Curve) {
            if (userDepositBalances[abi.encodePacked(msg.sender,Curve)] < amount ) {
                revert InsufficientBalance();
            }
            userDepositBalances[abi.encodePacked(msg.sender,Curve)] -= amount;
            totalDepositInCurveBalance -= amount;
            curve.withdraw(amount, treasury);
        }
        stETH.transferFrom(treasury,msg.sender, amount);
    }
    
    // user claims rewards from the vault
    function claimRewards() external {
        require(block.timestamp - userLastClaimTimestamp[msg.sender] > minimumTimeBetweenRewards, "Upkeep not needed");
        reBalanceReward();
        (uint256 lidoReward, uint256 curveReward) = getRewardBalance(msg.sender);
        lido.withdraw(lidoReward, treasury);
        curve.withdraw(curveReward, treasury);
        lastClaimTimestamp = uint32(block.timestamp);
        lastRewardAmount = lidoReward;
        lastCurveRewardAmount = curveReward;
        lidoRewardCount -= lidoReward;
        curveRewardCount -= curveReward;
        totalRewardReceivedByUser[abi.encodePacked(msg.sender, curveReward)] += curveReward;
        totalRewardReceivedByUser[abi.encodePacked(msg.sender, lidoReward)] += lidoReward;
        unchecked{stETH.transfer(msg.sender, (lidoReward + curveReward));}
    }
    
    function getRewardBalance(address user) public view returns (uint256 lidoReward, uint256 curveReward){
        
        unchecked
        {
            uint256 userLidoDepositWeight = userDepositBalances[abi.encodePacked(user, Lido)] * PRECISION /
            totalDepositInLidoBalance;
            userLidoDepositWeight / 100;
            
        
            uint256 userCurveDepositWeight = userDepositBalances[abi.encodePacked(user, Curve)] * PRECISION /
            totalDepositInCurveBalance;
            userCurveDepositWeight / 100;
            
            if (lastCurveRewardAmount == 0 && lastLidoRewardAmount == 0) {
                lidoReward = (userLidoDepositWeight * lidoRewardCount) / PRECISION;
                curveReward = (userCurveDepositWeight * curveRewardCount) / PRECISION;
            }
            else {
                lidoReward = (userLidoDepositWeight * (lastLidoRewardAmount - lidoRewardCount)) / PRECISION;
                curveReward = (userCurveDepositWeight * (lastCurveRewardAmount - curveRewardCount)) / PRECISION;
            }
        
        }
        if (lidoReward + curveReward < 0) {
            revert RewardTooLow();
        }
    }
    
    // update user reward balance
    function reBalanceReward() internal{

        if ( block.timestamp - lastRewardTimestamp > minimumTimeBetweenRewards  ) {
            uint256 pendingRewards = lido.getUnclaimedRewards(treasury) + curve.getUnclaimedRewards(treasury);
            if (pendingRewards >= minimumRewardAmount) {
                uint256 nonCompoundedLidoReward = lido.claimRewards(treasury);
                uint256 nonCompoundedCurveReward = curve.claimRewards(treasury);
                lidoRewardCount += nonCompoundedLidoReward;
                curveRewardCount += nonCompoundedCurveReward;
                lido.deposit(nonCompoundedLidoReward, treasury);
                curve.deposit(nonCompoundedCurveReward, treasury);
                lastRewardTimestamp = uint32(block.timestamp);
            }
        }
    }
    
    function getUserDepositBalance(address user, StakingPlatform platform) external view returns (uint256) {
        return userDepositBalances[abi.encodePacked(user, platform)];
    }
    
    function getTotalRewardReceivedByUser(address user) external view returns (uint256) {
        return totalRewardReceivedByUser[abi.encodePacked(user, Lido)] +
        totalRewardReceivedByUser[abi.encodePacked(user, Curve)];
    }
}
