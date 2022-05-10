// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BASE_TOKEN is ERC20Permit, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    constructor() ERC20("BASE_TOKEN", "BASE_TOKEN") ERC20Permit("BASE_TOKEN")
    {
      _mint(msg.sender, 1000e18);
    }

    address public boardroom;
    address public usdc_base_lp;
    address public usdc;

    function mint(address _to, uint256 _amount) internal {
        _mint(_to, _amount);
    }

    bool public addresses_set = false;

    function set_minter_and_friends(address _boardroom, address _usdc_base_lp, address _usdc) public onlyOwner{
        if(addresses_set == false){
          boardroom = _boardroom;
          usdc_base_lp = _usdc_base_lp;
          usdc = _usdc;
        }
        addresses_set = true;
    }

    uint256 public epoch_boardroom;

    function kick_printer(uint256 _epoch, uint256 _inflation) public{
        require(msg.sender == boardroom);
        require(epoch_boardroom <= _epoch); //can only "kick printer" is epoch has advanced
        require(_inflation <= 1000); //two decimals. 1000 = 10.00%
        //require(ERC20(usdc).balanceOf(usdc_base_lp) > ERC20(address(this)).balanceOf(usdc_base_lp)); //token needs to be above peg
        uint256 total_supply;
        uint256 to_print;
        total_supply = ERC20(address(this)).totalSupply();
        to_print = _inflation*total_supply.div(10000);
        epoch_boardroom = _epoch;
        mint(boardroom, to_print);
    }
}
