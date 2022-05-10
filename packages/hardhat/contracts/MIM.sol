// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MIM is ERC20Permit, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    constructor() ERC20("MIM", "MIM") ERC20Permit("MIM")
    {
    }

    uint256 constant public _maxTotalSupply = 50000000e18; // 1,000,000,000 MAX
    uint256 constant public emission_period = 180; //days till share issuance halts
    address[] public vested_addresses;
    uint256[] public alloc_emissions;
    uint256 public last_vesting_time;

    function mint(address _to, uint256 _amount) public onlyOwner {
        require(totalSupply() + _amount <= _maxTotalSupply, "ERC20: minting more then MaxTotalSupply");
        _mint(_to, _amount);
    }

    // Returns maximum total supply of the token
    function getMaxTotalSupply() external pure returns (uint256) {
        return _maxTotalSupply;
    }

    function set_vest(address[] memory _vested_addresses, uint256[] memory _alloc_emission) public onlyOwner {
        vested_addresses = _vested_addresses;
        alloc_emissions = _alloc_emission; //should add up to 100
        last_vesting_time = block.timestamp;
    }

    function execute_vesting() external {
        //mint tokens to vested entities (dev, vaults, farms)
        //based on last block.number, alloc emission, and blocks elapsed
        uint256 amount_to_mint;
        uint256 time_elapsed;
        time_elapsed = block.number - last_vesting_time;

        for(uint i=0;i<vested_addresses.length;i++){
            amount_to_mint = (alloc_emissions[i]*time_elapsed).div(100*3600*24*emission_period);
            _mint(vested_addresses[i], amount_to_mint);
        }
        last_vesting_time = block.timestamp;
    }
}
