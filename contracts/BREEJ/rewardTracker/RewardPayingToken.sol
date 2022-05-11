// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../library/SafeMathUint.sol";
import "../library/SafeMathInt.sol";
import "../interfaces/RewardPayingTokenInterface.sol";
import "../interfaces/RewardPayingTokenOptionalInterface.sol";


/// @title Reward-Paying Token
/// @author Roger Wu (https://github.com/roger-wu)
/// @dev A mintable ERC20 token that allows anyone to pay and distribute ether
///  to token holders as rewards and allows token holders to withdraw their rewards.
///  Reference: the source code of PoWH3D: https://etherscan.io/address/0xB3775fB83F7D12A36E0475aBdD1FCA35c091efBe#code
contract RewardPayingToken is ERC20, Ownable, RewardPayingTokenInterface, RewardPayingTokenOptionalInterface {
  using SafeMath for uint256;
  using SafeMathUint for uint256;
  using SafeMathInt for int256;

  // Mainnet
  // address public constant rewardToken = address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56); //rewardToken Binance

  // testnet

  address public rewardToken;

  // With `magnitude`, we can properly distribute rewards even if the amount of received ether is small.
  // For more discussion about choosing the value of `magnitude`,
  //  see https://github.com/ethereum/EIPs/issues/1726#issuecomment-472352728
  uint256 constant internal magnitude = 2**128;

  uint256 internal magnifiedRewardPerShare;

  // About rewardCorrection:
  // If the token balance of a `_user` is never changed, the reward of `_user` can be computed with:
  //   `rewardOf(_user) = rewardPerShare * balanceOf(_user)`.
  // When `balanceOf(_user)` is changed (via minting/burning/transferring tokens),
  //   `rewardOf(_user)` should not be changed,
  //   but the computed value of `rewardPerShare * balanceOf(_user)` is changed.
  // To keep the `rewardOf(_user)` unchanged, we add a correction term:
  //   `rewardOf(_user) = rewardPerShare * balanceOf(_user) + rewardCorrectionOf(_user)`,
  //   where `rewardCorrectionOf(_user)` is updated whenever `balanceOf(_user)` is changed:
  //   `rewardCorrectionOf(_user) = rewardPerShare * (old balanceOf(_user)) - (new balanceOf(_user))`.
  // So now `rewardOf(_user)` returns the same value before and after `balanceOf(_user)` is changed.
  mapping(address => int256) internal magnifiedRewardCorrections;
  mapping(address => uint256) internal withdrawnRewards;

  uint256 public totalRewardsDistributed;

  constructor(string memory _name, string memory _symbol,address _rewardToken) ERC20(_name, _symbol) {
     _setRewardToken(_rewardToken);
  }

  function _setRewardToken(address newToken) internal {
    rewardToken = newToken;
  }

  function distributeRewardForTokenHolders(uint256 amount) external onlyOwner{
    require(totalSupply() > 0, "Rewards: Supply is Zero");

    if (amount > 0) {
      magnifiedRewardPerShare = magnifiedRewardPerShare.add(
        (amount).mul(magnitude) / totalSupply()
      );
      emit RewardsDistributed(msg.sender, amount);

      totalRewardsDistributed = totalRewardsDistributed.add(amount);
    }
  }

  /// @notice Withdraws the ether distributed to the sender.
  /// @dev It emits a `RewardWithdrawn` event if the amount of withdrawn ether is greater than 0.
  function withdrawReward() external virtual override {
    _withdrawRewardsOfUser(msg.sender);
  }

  /// @notice Withdraws the ether distributed to the sender.
  /// @dev It emits a `RewardWithdrawn` event if the amount of withdrawn ether is greater than 0.
 function _withdrawRewardsOfUser(address user) internal returns (uint256) {
    uint256 _withdrawableReward = withdrawableRewardOf(user);
    if (_withdrawableReward > 0) {
      withdrawnRewards[user] = withdrawnRewards[user].add(_withdrawableReward);
      emit RewardWithdrawn(user, _withdrawableReward);
      bool success = IERC20(rewardToken).transfer(user, _withdrawableReward);

      if(!success) {
        withdrawnRewards[user] = withdrawnRewards[user].sub(_withdrawableReward);
        return 0;
      }

      return _withdrawableReward;
    }

    return 0;
  }


  /// @notice View the amount of reward in wei that an address can withdraw.
  /// @param _owner The address of a token holder.
  /// @return The amount of reward in wei that `_owner` can withdraw.
  function rewardOf(address _owner) external view override returns(uint256) {
    return withdrawableRewardOf(_owner);
  }

  /// @notice View the amount of reward in wei that an address can withdraw.
  /// @param _owner The address of a token holder.
  /// @return The amount of reward in wei that `_owner` can withdraw.
  function withdrawableRewardOf(address _owner) public view override returns(uint256) {
    return accumulativeRewardOf(_owner).sub(withdrawnRewards[_owner]);
  }

  /// @notice View the amount of reward in wei that an address has withdrawn.
  /// @param _owner The address of a token holder.
  /// @return The amount of reward in wei that `_owner` has withdrawn.
  function withdrawnRewardOf(address _owner) external view override returns(uint256) {
    return withdrawnRewards[_owner];
  }


  /// @notice View the amount of reward in wei that an address has earned in total.
  /// @dev accumulativeRewardOf(_owner) = withdrawableRewardOf(_owner) + withdrawnRewardOf(_owner)
  /// = (magnifiedRewardPerShare * balanceOf(_owner) + magnifiedRewardCorrections[_owner]) / magnitude
  /// @param _owner The address of a token holder.
  /// @return The amount of reward in wei that `_owner` has earned in total.
  function accumulativeRewardOf(address _owner) public view override returns(uint256) {
    return magnifiedRewardPerShare.mul(balanceOf(_owner)).toInt256Safe()
      .add(magnifiedRewardCorrections[_owner]).toUint256Safe() / magnitude;
  }

  /// @dev Internal function that mints tokens to an account.
  /// Update magnifiedRewardCorrections to keep rewards unchanged.
  /// @param account The account that will receive the created tokens.
  /// @param value The amount that will be created.
  function _mint(address account, uint256 value) internal override {
    super._mint(account, value);

    magnifiedRewardCorrections[account] = magnifiedRewardCorrections[account]
      .sub( (magnifiedRewardPerShare.mul(value)).toInt256Safe() );
  }

  /// @dev Internal function that burns an amount of the token of a given account.
  /// Update magnifiedRewardCorrections to keep rewards unchanged.
  /// @param account The account whose tokens will be burnt.
  /// @param value The amount that will be burnt.
  function _burn(address account, uint256 value) internal override {
    super._burn(account, value);

    magnifiedRewardCorrections[account] = magnifiedRewardCorrections[account]
      .add( (magnifiedRewardPerShare.mul(value)).toInt256Safe() );
  }

  function _setBalance(address account, uint256 newBalance) internal {
    uint256 currentBalance = balanceOf(account);

    if(newBalance > currentBalance) {
      uint256 mintAmount = newBalance.sub(currentBalance);
      _mint(account, mintAmount);
    } else if(newBalance < currentBalance) {
      uint256 burnAmount = currentBalance.sub(newBalance);
      _burn(account, burnAmount);
    }
  }
}