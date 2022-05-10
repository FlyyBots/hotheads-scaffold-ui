// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BIGSHARE is ERC20Permit, Ownable {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    constructor() ERC20("BIGSHARE", "BIGSHARE") ERC20Permit("BIGSHARE")
    {
    }

    uint256 constant private _maxTotalSupply = 100e18;
    address public share;

    function mint(address _to, uint256 _amount) public onlyOwner {
        require(totalSupply() + _amount <= _maxTotalSupply, "ERC20: minting more then MaxTotalSupply");
        _mint(_to, _amount);
    }

    // Returns maximum total supply of the token
    function getMaxTotalSupply() external pure returns (uint256) {
        return _maxTotalSupply;
    }

    function set_address(address _share) public onlyOwner{
        share = _share;
    }

    function wrap(uint256 amount) public{
        require(ERC20(share).balanceOf(msg.sender)>=amount);
        require(ERC20(share).balanceOf(msg.sender)>=500e18);
        ERC20(share).transferFrom(msg.sender, address(this), amount);
        ERC20(address(this)).transfer(msg.sender, amount.div(500));
    }

    function unwrap(uint256 amount) public{
        require(ERC20(address(this)).balanceOf(msg.sender)>=amount);
        ERC20(address(this)).transferFrom(msg.sender, address(this), amount);
        ERC20(share).transfer(msg.sender, 450*amount);
    }
}
