// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SHARE.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}

contract Genesis is Ownable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  AggregatorV3Interface internal priceFeedFTM = AggregatorV3Interface(0xe04676B9A9A2973BCb0D1478b5E1E9098BBB7f3D);
  AggregatorV3Interface internal priceFeedETH = AggregatorV3Interface(0xB8C458C957a6e6ca7Cc53eD95bEA548c52AFaA24);

  function getLatestPriceFTM() public view returns (int) {
      (
          uint80 roundID,
          int price,
          uint startedAt,
          uint timeStamp,
          uint80 answeredInRound
      ) = priceFeedFTM.latestRoundData();
      return price;
  }

  function getLatestPriceETH() public view returns (int) {
      (
          uint80 roundID,
          int price,
          uint startedAt,
          uint timeStamp,
          uint80 answeredInRound
      ) = priceFeedETH.latestRoundData();
      return price;
  }

  //kickstart_epoch and define duration of it
  uint256 public epoch;
  uint256 public epoch_duration;
  uint256 public genesis;
  uint256[] public vested_ftm;
  uint256[] public vested_eth;
  uint256[] public vested_usdc;
  uint256 public tokens_per_epoch = 800e18;

  function kickstart_epoch(uint256 epoch_length) public onlyOwner{
      if(epoch==0){
        epoch_duration = epoch_length;
        genesis = block.timestamp;
        epoch = 1;
        vested_ftm.push(0);
        vested_eth.push(0);
        vested_usdc.push(0);
      }
  }

  uint256 public last_epoch_timestamp;

  function see_time_now() public view returns (uint256 time){
    return block.timestamp;
  }

  function new_epoch() public {
      uint256 time_now;
      uint256 ftm_balance;
      uint256 eth_balance;
      uint256 usdc_balance;
      uint256 vested_ftm_now;
      uint256 vested_eth_now;
      uint256 vested_usdc_now;
      time_now = block.timestamp;
      if ((epoch == 1)&&((time_now - genesis)>=epoch_duration)){
          epoch = 2;
          last_epoch_timestamp = genesis + epoch_duration;

          ftm_balance = ERC20(ftm).balanceOf(address(this));
          eth_balance = ERC20(eth).balanceOf(address(this));
          usdc_balance = ERC20(usdc).balanceOf(address(this));
          vested_ftm_now = (40*tokens_per_epoch).div(100*ftm_balance);
          vested_eth_now = (40*tokens_per_epoch).div(100*eth_balance);
          vested_usdc_now = (30*tokens_per_epoch).div(100*1e12*usdc_balance);
          vested_ftm.push(vested_ftm_now);
          vested_eth.push(vested_eth_now);
          vested_usdc.push(vested_usdc_now);
      }

      if (epoch >= 2){
          if((time_now - last_epoch_timestamp)>epoch_duration){
              epoch += 1;
              last_epoch_timestamp = last_epoch_timestamp + epoch_duration;

              ftm_balance = ERC20(ftm).balanceOf(address(this));
              eth_balance = ERC20(eth).balanceOf(address(this));
              usdc_balance = ERC20(usdc).balanceOf(address(this));
              vested_ftm_now = (40*tokens_per_epoch).div(100*ftm_balance);
              vested_eth_now = (40*tokens_per_epoch).div(100*eth_balance);
              vested_usdc_now = (30*tokens_per_epoch).div(100*1e12*usdc_balance);
              vested_ftm.push(vested_ftm_now);
              vested_eth.push(vested_eth_now);
              vested_usdc.push(vested_usdc_now);
          }
      }
  }

  //set_address of stakable assets and pegged token and the LP and bonding discount, set_allocation to each pool
  address public usdc;
  address public eth;
  address public ftm;
  uint256 public usdc_alloc;
  uint256 public eth_alloc;
  uint256 public ftm_alloc;
  address public base_token;
  address public usdc_token_lp;
  uint256 public bonding_discount;
  address public treasury;
  address[] public car_owners;

  function set_params(address _usdc, address _eth, address _ftm, address _base_token, address _usdc_token_lp, uint256 _bonding_discount, uint256 _eth_alloc, uint256 _ftm_alloc, uint256 _usdc_alloc, address _treasury) public onlyOwner {
      usdc = _usdc;
      eth = _eth;
      ftm = _ftm;
      base_token = _base_token;
      usdc_token_lp = _usdc_token_lp;
      bonding_discount = _bonding_discount; //1 decimal. 100 = 10.0%
      eth_alloc = _eth_alloc;
      usdc_alloc = _usdc_alloc;
      ftm_alloc = _ftm_alloc;
      treasury = _treasury;
  }

  struct stakers {
      uint256 entry_epoch;
      uint256 timestamp;
      uint256 amount_staked;
      address asset_staked;
      bool has_car;
  }

  mapping (address => stakers) public genesis_staking;
  uint256 public deposited_eth;
  uint256 public deposited_usdc;
  uint256 public deposited_ftm;

  function staking(uint256 amount, address token) public {
      require(ERC20(token).balanceOf(msg.sender)>=amount);
      require(token == eth || token == usdc || token == ftm);
      require(block.timestamp <= genesis + 3*24*3600); //after 3 days it closes
      uint256 user_balance;
      user_balance = ERC20(token).balanceOf(msg.sender);

      ERC20(token).transferFrom(msg.sender, address(this), amount);
      genesis_staking[msg.sender].amount_staked += amount;
      genesis_staking[msg.sender].entry_epoch = epoch;
      genesis_staking[msg.sender].timestamp = block.timestamp;
      genesis_staking[msg.sender].asset_staked = token;
      genesis_staking[msg.sender].has_car = false;

      if(token == eth){
        deposited_eth += amount;
      }
      if(token == ftm){
        deposited_ftm += amount;
      }
      if(token == usdc){
        deposited_usdc += amount;
      }
  }

  function unstaking(address token) public {
      require(token == eth || token == usdc || token == ftm);
      uint256 to_return;
      uint256 time_now;
      uint256 time_staked;

      time_now = block.timestamp;

      to_return = genesis_staking[msg.sender].amount_staked;
      time_staked = genesis_staking[msg.sender].timestamp;

      genesis_staking[msg.sender].amount_staked = 0;
      genesis_staking[msg.sender].entry_epoch = epoch;
      genesis_staking[msg.sender].timestamp = block.timestamp;
      genesis_staking[msg.sender].asset_staked = token;

      if (time_now < time_staked + 24*3600){
        to_return = (80*to_return).div(100); //20% fee
        ERC20(token).transfer(treasury, (20*to_return).div(100));
      }

      if ((time_now < time_staked + 2*24*3600) && (time_now >= time_staked + 24*3600)){
        to_return = (90*to_return).div(100); //10% fee
        ERC20(token).transfer(treasury, (10*to_return).div(100));
      }

      if(token == eth){
        deposited_eth -= to_return;
        ERC20(token).transfer(msg.sender, to_return);
      }
      if(token == ftm){
        deposited_ftm -= to_return;
        ERC20(token).transfer(msg.sender, to_return);
      }
      if(token == usdc){
        deposited_usdc -= to_return;
        ERC20(token).transfer(msg.sender, to_return);
      }
  }

  function claim_bonding(address token) public{
    //no partial bonding: must bond all or nothing
    require(block.timestamp >= genesis_staking[msg.sender].timestamp + 7*24*3600);
    require(token == eth || token == usdc || token == ftm);

    uint256 token_num;
    uint256 token_den;
    uint256 token_price;
    uint256 discount;
    uint256 to_give;
    uint256 to_give_bonus;

    token_num = ERC20(usdc).balanceOf(usdc_token_lp);
    token_den = ERC20(base_token).balanceOf(usdc_token_lp);
    token_price = (1e12*token_num).div(token_den); //to adjust for usdc 6 decimals

    if(token == eth){
      to_give = (ERC20(token).balanceOf(msg.sender))*uint256(getLatestPriceETH());
    }

    if(token == ftm){
      to_give = (ERC20(token).balanceOf(msg.sender))*uint256(getLatestPriceFTM());
    }

    if(token == usdc){
      to_give = ERC20(token).balanceOf(msg.sender);
    }

    to_give_bonus = (150*to_give).div(100*1e8*token_price);
    ERC20(token).transfer(treasury, genesis_staking[msg.sender].amount_staked);
    ERC20(base_token).transfer(msg.sender, to_give_bonus);
    genesis_staking[msg.sender].has_car = true;
    car_owners.push(msg.sender);
  }

  //mint 9,600 pegged tokens to this contract (800 vested per epoch) + additional for the bonding
  //harvesting: advances epoch, vests, sends tokens

  function vest_and_harvest(address token) public{
      require(token == eth || token == usdc || token == ftm);
      uint256 amount_vested;
      uint256 tokens_deposited;

      new_epoch();
      tokens_deposited = genesis_staking[msg.sender].amount_staked;

      if(genesis_staking[msg.sender].entry_epoch < epoch){
          for(uint256 i=genesis_staking[msg.sender].entry_epoch;i<epoch;i++){
              if(token == ftm){
                amount_vested += (vested_ftm[i]*tokens_deposited).div(1000000000000000000);
              }
              if(token == eth){
                amount_vested += (vested_eth[i]*tokens_deposited).div(1000000000000000000);
              }
              if(token == usdc){
                amount_vested += (vested_usdc[i]*tokens_deposited).div(1000000000000000000);
              }
          }
          genesis_staking[msg.sender].entry_epoch = epoch;
          ERC20(base_token).transfer(msg.sender, uint256(amount_vested));
      }
  }
}
