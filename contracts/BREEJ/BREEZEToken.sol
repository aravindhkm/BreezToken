// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "./rewardTracker/RewardTracker.sol";

contract BREEZEToken is ERC20, ERC20Burnable, Ownable {
    using SafeMath for uint256;

    uint256 public gasForProcessing = 300000;
    address public deadWallet = 0x000000000000000000000000000000000000dEaD;	
    address public rewardToken;

    RewardTracker public TMAC_RewardTracker;

    event UpdateRewardTracker(address indexed newAddress, address indexed oldAddress);
    event GasForProcessingUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    event ProcessedRewardTracker(
    	uint256 iterations,
    	uint256 claims,
        uint256 lastProcessedIndex,
    	bool indexed automatic,
    	uint256 gas,
    	address indexed processor
    );

    constructor(address _rewardToken) ERC20("BREEZE", "BREEJ") {
        rewardToken = _rewardToken;
    	TMAC_RewardTracker = new RewardTracker(_rewardToken);

        TMAC_RewardTracker.excludeFromRewards(address(TMAC_RewardTracker));
        TMAC_RewardTracker.excludeFromRewards(address(this));
        TMAC_RewardTracker.excludeFromRewards(owner());
        TMAC_RewardTracker.excludeFromRewards(deadWallet);

        _mint(owner(), 5000000 * (10**18));
    }

    receive() external payable {}

    function distributeRewards(uint256 tokens) external onlyOwner{
        TMAC_RewardTracker.distributeRewardForTokenHolders(tokens);
    }

    function updateRewardTracker(address newAddress) public onlyOwner {
        require(newAddress != address(TMAC_RewardTracker), "BREEJ: The reward tracker already has that address");

        RewardTracker newRewardTracker = RewardTracker(payable(newAddress));

        require(newRewardTracker.owner() == address(this), "BREEJ: The new reward tracker must be owned by the BREEJ token contract");

        newRewardTracker.excludeFromRewards(address(newRewardTracker));
        newRewardTracker.excludeFromRewards(address(this));
        newRewardTracker.excludeFromRewards(owner());

        emit UpdateRewardTracker(newAddress, address(newRewardTracker));

        TMAC_RewardTracker = newRewardTracker;
    }

    function updateGasForProcessing(uint256 newValue) public onlyOwner {
        require(newValue != gasForProcessing, "BREEJ: Cannot update gasForProcessing to same value");
        emit GasForProcessingUpdated(newValue, gasForProcessing);
        gasForProcessing = newValue;
    }

    function updateClaimWait(uint256 claimWait) external onlyOwner {
        TMAC_RewardTracker.updateClaimWait(claimWait);
    }

    function getClaimWait() external view returns(uint256) {
        return TMAC_RewardTracker.claimWait();
    }

    function getTotalRewardsDistributed() external view returns (uint256) {
        return TMAC_RewardTracker.totalRewardsDistributed();
    }

    function getWithdrawableRewardOf(address account) public view returns(uint256) {
    	return TMAC_RewardTracker.withdrawableRewardOf(account);
  	}

	function rewardTokenBalanceOf(address account) public view returns (uint256) {
		return TMAC_RewardTracker.balanceOf(account);
	}

	function excludeFromRewards(address account) external onlyOwner{
	    TMAC_RewardTracker.excludeFromRewards(account);
	}

    function getAccountRewardsInfo(address account)
        external view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
        return TMAC_RewardTracker.getAccount(account);
    }

	function getAccountRewardsInfoAtIndex(uint256 index)
        external view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
    	return TMAC_RewardTracker.getAccountAtIndex(index);
    }

	function autoDistribute() external {
        uint256 gas = gasForProcessing;
		(uint256 iterations, uint256 claims, uint256 lastProcessedIndex) = TMAC_RewardTracker.process(gas);
		emit ProcessedRewardTracker(iterations, claims, lastProcessedIndex, false, gas, tx.origin);
    }

    function claim() external {
		TMAC_RewardTracker.processAccount(msg.sender, false);
    }

    function getLastProcessedIndex() external view returns(uint256) {
    	return TMAC_RewardTracker.getLastProcessedIndex();
    }

    function getNumberOfRewardTokenHolders() external view returns(uint256) {
        return TMAC_RewardTracker.getNumberOfTokenHolders();
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal 
      override(ERC20) {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
		
        super._transfer(from, to, amount);

        try TMAC_RewardTracker.setBalance(from, balanceOf(from)) {} catch {}
        try TMAC_RewardTracker.setBalance(to, balanceOf(to)) {} catch {}     
    }

    function setRewardToken(address newRewardToken) external onlyOwner {
        rewardToken = newRewardToken;
        TMAC_RewardTracker.setRewardToken(newRewardToken);
    }

    function recoverLeftOverBNB(uint256 amount) external onlyOwner {
        payable(owner()).transfer(amount);
    }

    function recoverLeftOverToken(address token,uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(),amount);
    }

    function recoverRewardTracketLeftOverBNB(uint256 amount) external onlyOwner {
        TMAC_RewardTracker.recoverLeftOverBNB(owner(),amount);
    }

    function recoverRewardTracketLeftOverToken(address token,uint256 amount) external onlyOwner {
        TMAC_RewardTracker.recoverLeftOverToken(token,owner(),amount);
    }
}







