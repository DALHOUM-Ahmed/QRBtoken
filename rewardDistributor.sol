pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IQRBToken {
  function balanceOf(address account) external view returns (uint256);

  function totalSupply() external view returns (uint256);

  function approve(address spender, uint256 amount) external returns (bool);

  function transfer(address recipient, uint256 amount) external returns (bool);
}

interface IPancakeRouter {
  function getAmountsOut(uint256 amountIn, address[] memory path) external view returns (uint[] memory amounts);

  function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external returns (uint[] memory amounts);
}

contract RewardDistributor {
  using SafeMath for uint256;

  IQRBToken public QRBToken;
  IPancakeRouter public router;
  address[5] public rewardTokens;
  address public owner;

  uint256 private constant MAX = ~uint256(0);

  uint256 private _rTotal = 10 ** 30;
  uint256 private _tTotal;
  mapping(address => uint256) private _rOwned;
  mapping(address => uint256) private _tOwned;

  constructor(address _QRBToken, address _router) {
    QRBToken = IQRBToken(_QRBToken);
    router = IPancakeRouter(_router);
    rewardTokens[0] = _QRBToken;
    owner = msg.sender;
    _tTotal = QRBToken.totalSupply();
    _rTotal = (MAX - (MAX % _tTotal));
  }

  function _reflectFee(uint256 rFee, uint256 tFee) private {
    _rTotal = _rTotal.sub(rFee);
    _tTotal = _tTotal.add(tFee);
  }

  function reflectTokens(address sender, address recipient, uint256 tAmount) external {
    (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee) = _getValues(tAmount);

    _rOwned[sender] = _rOwned[sender].sub(rAmount);
    _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);

    _reflectFee(rFee, tFee);
    // emit Transfer(sender, recipient, tTransferAmount);
  }

  function claimReward(uint8 tokenIndex) external {
    require(tokenIndex < 5, "Invalid token index");

    uint256 tBalance = QRBToken.balanceOf(msg.sender);
    uint256 rBalance = tBalance.mul(_getRate());
    uint256 reward = rBalance.sub(_rOwned[msg.sender]);

    if (tokenIndex != 0) {
      address[] memory path = new address[](2);
      path[0] = address(QRBToken);
      path[1] = rewardTokens[tokenIndex];

      QRBToken.approve(address(router), reward);
      uint[] memory amounts = router.getAmountsOut(reward, path);
      router.swapExactTokensForTokens(reward, amounts[1], path, msg.sender, block.timestamp + 60);
    } else {
      QRBToken.transfer(msg.sender, reward);
    }

    _rOwned[msg.sender] = rBalance;
  }

  function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256) {
    // 100000000000
    (uint256 tTransferAmount, uint256 tFee) = _getTValues(tAmount); // (90000000000 , 5000000000 , 5000000000 )
    (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, _getRate());
    //(9.26336713898529563388567880069503262826159877325124512×10⁶³ , 5.7896044618658097711785492504343953926634992332820282×10⁶² , 5.7896044618658097711785492504343953926634992332820282×10⁶²)
    return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee);
  }

  function _getTValues(uint256 tAmount) private pure returns (uint256, uint256) {
    // 100000000000
    uint256 tFee = tAmount.mul(5).div(100);
    uint256 tTransferAmount = tAmount.sub(tFee);
    return (tTransferAmount, tFee);
  }

  function _getRValues(uint256 tAmount, uint256 tFee, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
    uint256 rAmount = tAmount.mul(currentRate);
    uint256 rFee = tFee.mul(currentRate);
    uint256 rTransferAmount = rAmount.sub(rFee);
    return (rAmount, rTransferAmount, rFee);
  }

  function _getRate() private view returns (uint256) {
    return _rTotal.div(_tTotal);
  }
}
