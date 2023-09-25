// SPDX-License-Identifier: MIT
// File: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Context.sol

// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)
import "hardhat/console.sol";

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
  function _msgSender() internal view virtual returns (address) {
    return msg.sender;
  }

  function _msgData() internal view virtual returns (bytes calldata) {
    return msg.data;
  }
}

// File: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol

// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
  address private _owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /**
   * @dev Initializes the contract setting the deployer as the initial owner.
   */
  constructor() {
    _transferOwnership(_msgSender());
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    _checkOwner();
    _;
  }

  /**
   * @dev Returns the address of the current owner.
   */
  function owner() public view virtual returns (address) {
    return _owner;
  }

  /**
   * @dev Throws if the sender is not the owner.
   */
  function _checkOwner() internal view virtual {
    require(owner() == _msgSender(), "Ownable: caller is not the owner");
  }

  /**
   * @dev Leaves the contract without owner. It will not be possible to call
   * `onlyOwner` functions. Can only be called by the current owner.
   *
   * NOTE: Renouncing ownership will leave the contract without an owner,
   * thereby disabling any functionality that is only available to the owner.
   */
  function renounceOwnership() public virtual onlyOwner {
    _transferOwnership(address(0));
  }

  /**
   * @dev Transfers ownership of the contract to a new account (`newOwner`).
   * Can only be called by the current owner.
   */
  function transferOwnership(address newOwner) public virtual onlyOwner {
    require(newOwner != address(0), "Ownable: new owner is the zero address");
    _transferOwnership(newOwner);
  }

  /**
   * @dev Transfers ownership of the contract to a new account (`newOwner`).
   * Internal function without access restriction.
   */
  function _transferOwnership(address newOwner) internal virtual {
    address oldOwner = _owner;
    _owner = newOwner;
    emit OwnershipTransferred(oldOwner, newOwner);
  }
}

// File: fiveTaxesToken/token.sol

pragma solidity ^0.8.0;

interface IERC20 {
  function balanceOf(address account) external view returns (uint256);

  function transfer(address recipient, uint256 amount) external returns (bool);

  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

  function approve(address spender, uint256 amount) external returns (bool);

  function allowance(address owner, address spender) external view returns (uint256);
}

interface IRewardDistributor {
  function reflectTokens(address sender, address recipient, uint256 tAmount, bool takeFee) external;
}

contract QRBToken is IERC20, Ownable {
  string public name = "Quantitative Reasoning for Business";
  string public symbol = "QRB";
  uint8 public decimals = 18;
  uint256 public totalSupply = 1000000 * (10 ** uint256(decimals));

  mapping(address => uint256) private _balances;
  mapping(address => mapping(address => uint256)) private _allowances;

  uint256 public launchTime;
  uint256 public antiSniperTime = 60;
  uint256 public maxTxAmount = 10000 * (10 ** uint256(decimals));

  bool public aPairIsSet;
  bool paused;

  mapping(address => bool) public isExcludedFromAntiSnipe;

  mapping(address => bool) public isPair;

  address public rewardDistributor;

  constructor() {
    _balances[msg.sender] = totalSupply;
  }

  function setRewardDistributor(address _rewardDistributor) external onlyOwner {
    rewardDistributor = _rewardDistributor;
  }

  // function testToDelete() external view returns (address) {
  //   return owner();
  // }

  function setPair(address _pair, bool _isPair) external onlyOwner {
    isPair[_pair] = _isPair;
    aPairIsSet = true;
  }

  function togglePause() external onlyOwner {
    paused = !paused;
  }

  function launch() external onlyOwner {
    launchTime = block.timestamp;
  }

  function setMaxTxAmount(uint256 _maxTxAmount) external onlyOwner {
    maxTxAmount = _maxTxAmount;
  }

  function excludeFromAntiSnipe(address _account, bool _exclude) external onlyOwner {
    isExcludedFromAntiSnipe[_account] = _exclude;
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
    require(_balances[sender] >= amount, "insufficient balance");
    require(rewardDistributor != address(0), "Reward distributor not set");
    require(launchTime > 0 || sender == owner() || recipient == owner(), "QRB not launched");

    if (((!isExcludedFromAntiSnipe[sender] && (block.timestamp < launchTime + antiSniperTime)) || amount > maxTxAmount) && sender != owner() && recipient != owner()) {
      revert("Forbidden!");
    }

    require(aPairIsSet || sender == owner(), "no pair is Set");
    require(!paused || sender == owner(), "Paused");

    _balances[sender] -= amount;
    _balances[recipient] += amount;

    if (isPair[recipient]) {
      uint256 tax = amount / 20;
      _balances[recipient] -= tax;
      _balances[rewardDistributor] += tax;
      IRewardDistributor(rewardDistributor).reflectTokens(sender, recipient, amount, true);
    } else {
      IRewardDistributor(rewardDistributor).reflectTokens(sender, recipient, amount, false);
    }
  }

  function _approve(address owner, address spender, uint256 amount) internal {
    require(owner != address(0));
    require(spender != address(0));
    _allowances[owner][spender] = amount;
  }
}
