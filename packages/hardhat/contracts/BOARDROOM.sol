// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./BASE_TOKEN.sol";

interface IBASE_TOKEN {
    function kick_printer(uint256 _epoch, uint256 _inflation) external;
  }

contract BOARDROOM is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint pool_id;
    address small_share;
    address big_share;
    address large_share;
    address base_token;

    struct boardroom_stakers {
        uint256 entry_epoch;
        uint256 amount_staked;
    }

    mapping (address => boardroom_stakers) public small_shares_staked;
    mapping (address => boardroom_stakers) public big_shares_staked;
    mapping (address => boardroom_stakers) public large_shares_staked;

    function set_addresses(address _small_share, address _big_share, address _large_share, address _base_token) public onlyOwner{
      small_share = _small_share;
      big_share = _big_share;
      large_share = _large_share;
      base_token = _base_token;
    }

    function staking(uint256 amount, address token) public{
      require(ERC20(token).balanceOf(msg.sender) >= amount);
      ERC20(token).transferFrom(msg.sender, address(this), amount);
      if(token == small_share){
        small_shares_staked[msg.sender].amount_staked = amount;
        small_shares_staked[msg.sender].entry_epoch = epoch;
      }

      if(token == big_share){
        big_shares_staked[msg.sender].amount_staked = amount;
        big_shares_staked[msg.sender].entry_epoch = epoch;
      }

      if(token == large_share){
        large_shares_staked[msg.sender].amount_staked = amount;
        large_shares_staked[msg.sender].entry_epoch = epoch;
      }
    }

    function unstaking(address token) public{
      uint256 amount;
      if(token == small_share){
        amount = small_shares_staked[msg.sender].amount_staked;
        small_shares_staked[msg.sender].amount_staked = 0;
        small_shares_staked[msg.sender].entry_epoch = epoch;
        ERC20(token).transfer(msg.sender, amount);
      }

      if(token == big_share){
        amount = big_shares_staked[msg.sender].amount_staked;
        big_shares_staked[msg.sender].amount_staked = 0;
        big_shares_staked[msg.sender].entry_epoch = epoch;
        ERC20(token).transfer(msg.sender, amount);
      }

      if(token == large_share){
        amount = large_shares_staked[msg.sender].amount_staked;
        large_shares_staked[msg.sender].amount_staked = 0;
        large_shares_staked[msg.sender].entry_epoch = epoch;
        ERC20(token).transfer(msg.sender, amount);
      }
    }

    uint256 epoch_duration;
    uint256 epoch;
    uint256 inflation;
    uint256 last_epoch_timestamp;
    uint256 genesis;

    function see_epoch() public view returns(uint256){
      return epoch;
    }

    function see_inflation() public view returns(uint256){
      return inflation;
    }

    function set_inflation(uint256 _inflation) public onlyOwner{
        inflation = _inflation; //2 decimals. Max = 1000 (10.00%);
    }

    function kickstart_epoch(uint256 epoch_length) public onlyOwner{
        if(epoch == 0){
          epoch_duration = epoch_length;
          genesis = block.timestamp;
          epoch = 1;
        }
    }

    function new_epoch() private{
        uint256 time_now;
        time_now = block.timestamp;
        if ((epoch == 1)&&((time_now - genesis)>=epoch_duration)){
            epoch = 2;
            last_epoch_timestamp = genesis + epoch_duration;
        }

        if (epoch >= 2){
            if((time_now - last_epoch_timestamp)>epoch_duration){
                epoch += 1;
                last_epoch_timestamp = last_epoch_timestamp + epoch_duration;
            }
        }
    }

    uint256[] public alloc_emissions;
    //function set_boardroom_alloc(uint256[] memory _amount) public{
      //alloc_emissions = _amount;
    function set_boardroom_alloc() public onlyOwner{
      alloc_emissions.push(60);
      alloc_emissions.push(30);
      alloc_emissions.push(10);
    }

    uint256[] public vested_small_share;
    uint256[] public vested_big_share;
    uint256[] public vested_large_share;
    bool public never_vested_tokens = true;
    uint256 public last_vested_tokens;
    uint256 public last_supply;
    uint256 public last_supply_bigroom;
    uint256 public last_supply_largeroom;

    function vest_base_token() private{
      uint256 time_now;
      uint256 reward_per_small_share;
      uint256 reward_per_big_share;
      uint256 reward_per_large_share;
      uint256 deposited_small_share;
      uint256 deposited_big_share;
      uint256 deposited_large_share;
      uint256 supply_expansion;

      time_now = block.timestamp;

      deposited_small_share = ERC20(small_share).balanceOf(address(this));
      deposited_big_share = ERC20(big_share).balanceOf(address(this));
      deposited_large_share = ERC20(large_share).balanceOf(address(this));

      if (never_vested_tokens == true) {
          IBASE_TOKEN(base_token).kick_printer(epoch, inflation);
          last_vested_tokens = time_now;
          never_vested_tokens = false;
          vested_small_share.push(0);
          vested_big_share.push(0);
          vested_large_share.push(0);
          last_supply = ERC20(base_token).totalSupply();
          last_supply_bigroom = ERC20(base_token).totalSupply();
          last_supply_largeroom = ERC20(base_token).totalSupply();
      }

      if ((never_vested_tokens == false) && (time_now > (last_vested_tokens + epoch_duration))) {
          IBASE_TOKEN(base_token).kick_printer(epoch, inflation);
          //Important: this assumes that ALL the shares minted come to this contract.

          if(deposited_small_share>0){
            supply_expansion = ERC20(base_token).totalSupply() - last_supply;
            last_supply = ERC20(base_token).totalSupply();
            reward_per_small_share = (alloc_emissions[0]*supply_expansion*1000000000000000000).div(deposited_small_share*100);
          }else{
            reward_per_small_share = 0;
          }
          if(deposited_big_share>0){
            supply_expansion = ERC20(base_token).totalSupply() - last_supply_bigroom;
            last_supply_bigroom = ERC20(base_token).totalSupply();
            reward_per_big_share = (alloc_emissions[1]*supply_expansion*1000000000000000000).div(deposited_big_share*100);
          }else{
            reward_per_big_share = 0;
          }
          if(deposited_large_share>0){
            supply_expansion = ERC20(base_token).totalSupply() - last_supply_largeroom;
            last_supply_largeroom = ERC20(base_token).totalSupply();
            reward_per_large_share = (alloc_emissions[2]*supply_expansion*1000000000000000000).div(deposited_large_share*100);
          }else{
            reward_per_large_share = 0;
          }

          vested_small_share.push(reward_per_small_share);
          vested_big_share.push(reward_per_big_share);
          vested_large_share.push(reward_per_large_share);

          last_vested_tokens = time_now;
      }

    }

    function claim() public{
      new_epoch();
      vest_base_token();
      uint256 amount_vested = 0;
      uint i;
      uint256 deposited_small_share;
      uint256 deposited_big_share;
      uint256 deposited_large_share;

      if(small_shares_staked[msg.sender].amount_staked > 0 && small_shares_staked[msg.sender].entry_epoch < epoch){
          deposited_small_share = small_shares_staked[msg.sender].amount_staked;
          for(i=small_shares_staked[msg.sender].entry_epoch;i<epoch;i++){
              amount_vested += (vested_small_share[i-1]*deposited_small_share).div(1000000000000000000);
          }
          small_shares_staked[msg.sender].entry_epoch = epoch;
          ERC20(small_share).transfer(msg.sender, uint256(amount_vested));
          amount_vested = 0;
      }

      if(big_shares_staked[msg.sender].amount_staked > 0){
        deposited_big_share = big_shares_staked[msg.sender].amount_staked;
        for(i=big_shares_staked[msg.sender].entry_epoch;i<epoch;i++){
            amount_vested += (vested_big_share[i-1]*deposited_big_share).div(1000000000000000000);
        }
        big_shares_staked[msg.sender].entry_epoch = epoch;
        ERC20(big_share).transfer(msg.sender, uint256(amount_vested));
        amount_vested = 0;
      }

      if(large_shares_staked[msg.sender].amount_staked > 0){
        deposited_large_share = large_shares_staked[msg.sender].amount_staked;
        for(i=large_shares_staked[msg.sender].entry_epoch;i<epoch;i++){
            amount_vested += (vested_large_share[i-1]*deposited_large_share).div(1000000000000000000);
        }
        large_shares_staked[msg.sender].entry_epoch = epoch;
        ERC20(large_share).transfer(msg.sender, uint256(amount_vested));
        amount_vested = 0;
      }
    }
}
