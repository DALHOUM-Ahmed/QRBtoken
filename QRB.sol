// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
  function balanceOf(address account) external view returns (uint256);

  function transfer(address recipient, uint256 amount) external returns (bool);

  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

  function approve(address spender, uint256 amount) external returns (bool);

  function allowance(address owner, address spender) external view returns (uint256);
}

interface IRewardDistributor {
  function reflectTokens(address from, address to, uint256 amount) external;
}

contract QRBToken is IERC20 {
  string public name = "Quantitative Reasoning for Business";
  string public symbol = "QRB";
  uint8 public decimals = 18;
  uint256 public totalSupply = 1000000 * (10 ** uint256(decimals));

  mapping(address => uint256) private _balances;
  mapping(address => mapping(address => uint256)) private _allowances;

  address public rewardDistributor;

  constructor(address _rewardDistributor) {
    rewardDistributor = _rewardDistributor;
    _balances[msg.sender] = totalSupply;
  }

  function balanceOf(address account) external view override returns (uint256) {
    return _balances[account];
  }

  function transfer(address recipient, uint256 amount) external override returns (bool) {
    _transfer(msg.sender, recipient, amount);
    return true;
  }

  function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
    _transfer(sender, recipient, amount);
    _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
    return true;
  }

  function approve(address spender, uint256 amount) external override returns (bool) {
    _approve(msg.sender, spender, amount);
    return true;
  }

  function allowance(address owner, address spender) external view override returns (uint256) {
    return _allowances[owner][spender];
  }

  function _transfer(address sender, address recipient, uint256 amount) internal {
    require(sender != address(0));
    require(recipient != address(0));
    require(_balances[sender] >= amount);

    _balances[sender] -= amount;
    _balances[recipient] += amount;

    if (recipient == address(this) || recipient == address(0)) {
      uint256 tax = amount / 20;
      _balances[recipient] -= tax;
      _balances[rewardDistributor] += tax;
    }

    IRewardDistributor(rewardDistributor).reflectTokens(sender, recipient, amount);
  }

  function _approve(address owner, address spender, uint256 amount) internal {
    require(owner != address(0));
    require(spender != address(0));
    _allowances[owner][spender] = amount;
  }
}
