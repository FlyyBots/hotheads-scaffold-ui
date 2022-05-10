// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SHARE.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Farms is Ownable, SHARE{

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct harvesting_stakers {
        uint256 entry_epoch;
        uint256 amount_staked;
    }

    mapping (address => harvesting_stakers) public ftm_token_staked;
    mapping (address => harvesting_stakers) public ftm_share_staked;
    mapping (address => harvesting_stakers) public share_token_staked;

    address public ftm_address;
    address public share_address;
    address public base_token;
    address public ftm_token_lp;
    address public ftm_share_lp;
    address public share_token_lp;

    function set_addresses(address _ftm_address, address _share_address, address _base_token, address _ftm_token_lp, address _ftm_share_lp, address _share_token_lp) public onlyOwner {
        ftm_address = _ftm_address;
        share_address = _share_address;
        base_token = _base_token;
        ftm_token_lp = _ftm_token_lp; //equivalent of FTM-TOMB LP
        ftm_share_lp = _ftm_share_lp; //equivalent of FTM-TSHARE LP
        share_token_lp = _share_token_lp; //equivalent of TSHARE-TOMB LP
    }

    uint256 public epoch;
    uint256 public deposited_ftm_token;
    uint256 public deposited_ftm_share;
    uint256 public deposited_share_token;
    uint256[] public alloc_emissions_to_farms;
    //mapping (uint256 => uint256) public alloc_emissions_to_farms;

    //function set_emissions(uint256[] memory _amount) public{
      //alloc_emissions_to_farms = _amount; //must define before re-running tests
    function set_emissions() public onlyOwner{
      alloc_emissions_to_farms.push(30);
      alloc_emissions_to_farms.push(30);
      alloc_emissions_to_farms.push(40);
    }

    //function check_array() public view returns (uint256[] memory){
      //uint256[] storage array=alloc_emissions_to_farms;
      //return array;
    //}

    //Staking functions
    function staking_ftm_token_lp(uint256 amount) public {
        require(ERC20(ftm_token_lp).balanceOf(msg.sender)>=0);
        uint256 user_balance;
        user_balance = ERC20(ftm_token_lp).balanceOf(msg.sender);
        if (user_balance>=amount){
            ERC20(ftm_token_lp).transferFrom(msg.sender, address(this), amount);
            ftm_token_staked[msg.sender].amount_staked += amount;
            ftm_token_staked[msg.sender].entry_epoch = epoch;
            deposited_ftm_token += amount; //we keep track of the sum of all staked lps
        }
    }

    function staking_ftm_share_lp(uint256 amount) public {
        require(ERC20(ftm_share_lp).balanceOf(msg.sender)>=0);
        uint256 user_balance;
        user_balance = ERC20(ftm_share_lp).balanceOf(msg.sender);
        if (user_balance>=amount){
            ERC20(ftm_share_lp).transferFrom(msg.sender, address(this), amount);
            ftm_share_staked[msg.sender].amount_staked += amount;
            ftm_share_staked[msg.sender].entry_epoch = epoch;
            deposited_ftm_share += amount; //we keep track of the sum of all staked lps
        }
    }

    function staking_share_token_lp(uint256 amount) public {
        require(ERC20(share_token_lp).balanceOf(msg.sender)>=0);
        uint256 user_balance;
        user_balance = ERC20(share_token_lp).balanceOf(msg.sender);
        if (user_balance>=amount){
            ERC20(share_token_lp).transferFrom(msg.sender, address(this), amount);
            share_token_staked[msg.sender].amount_staked += amount;
            share_token_staked[msg.sender].entry_epoch = epoch;
            deposited_share_token += amount; //we keep track of the sum of all staked lps
        }
    }

    //Unstaking functions: usually on tomb (and forks) unstake is always in full, so here we unstake all
    function unstaking_ftm_token_lp() public {
        uint256 amount_to_unstake;
        amount_to_unstake = ftm_token_staked[msg.sender].amount_staked;
        if (amount_to_unstake>0){
            deposited_ftm_token -= ftm_token_staked[msg.sender].amount_staked ;
            ftm_token_staked[msg.sender].amount_staked = 0;
            ftm_token_staked[msg.sender].entry_epoch = epoch;
            ERC20(ftm_token_lp).transfer(msg.sender, amount_to_unstake);
        }
    }

    function unstaking_ftm_share_staked() public {
        uint256 amount_to_unstake;
        amount_to_unstake = ftm_share_staked[msg.sender].amount_staked;
        if (amount_to_unstake>0){
            ftm_share_staked[msg.sender].amount_staked = 0;
            ftm_share_staked[msg.sender].entry_epoch = epoch;
            ERC20(ftm_share_lp).transfer(msg.sender, amount_to_unstake);
        }
    }

    function unstaking_share_token_staked() public {
        uint256 amount_to_unstake;
        amount_to_unstake = share_token_staked[msg.sender].amount_staked;
        if (amount_to_unstake>0){
            share_token_staked[msg.sender].amount_staked = 0;
            share_token_staked[msg.sender].entry_epoch = epoch;
            ERC20(share_token_lp).transfer(msg.sender, amount_to_unstake);
        }
    }

    uint256 public epoch_duration;
    uint256 public genesis;

    function kickstart_epoch(uint256 epoch_length) public onlyOwner{
        if(epoch == 0){
          epoch_duration = epoch_length;
          genesis = block.timestamp;
          epoch = 1;
        }
    }

    uint256 public last_epoch_timestamp;

    function see_time_now() public view returns (uint256 time){
      return block.timestamp;
    }

    function new_epoch() public {
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

    uint256[] public vested_ftm_token;
    uint256[] public vested_ftm_share;
    uint256[] public vested_share_token;
    bool public never_vested_tokens = true;
    uint256 public last_vested_tokens;
    uint256 public last_supply;

    //vesting tokens, based on the supply expansion from last vesting
    function compute_vest_tokens() public{
        uint256 time_now;
        uint256 reward_per_token_ftm_token;
        uint256 reward_per_token_ftm_share;
        uint256 reward_per_token_share_token;
        uint256 deposited_ftm_token_total;
        uint256 deposited_ftm_share_total;
        uint256 deposited_share_token_total;
        uint256 supply_expansion;

        time_now = block.timestamp;

        deposited_ftm_token_total = ERC20(address(ftm_token_lp)).balanceOf(address(this));
        deposited_ftm_share_total = ERC20(address(ftm_share_lp)).balanceOf(address(this));
        deposited_share_token_total = ERC20(address(share_token_lp)).balanceOf(address(this));

        if (never_vested_tokens == true) {
            last_vested_tokens = time_now;
            never_vested_tokens = false;
            vested_ftm_token.push(0);
            vested_ftm_share.push(0);
            vested_share_token.push(0);
        }

        if ((never_vested_tokens == false) && (time_now > (last_vested_tokens + epoch_duration))) {
            SHARE(share_address).execute_vesting; //called from the base token contract
            supply_expansion = ERC20(share_address).totalSupply() - last_supply;
            last_supply = ERC20(share_address).totalSupply();
            //Important: this assumes that ALL the shares minted come to this contract.

            if(deposited_ftm_token_total>0){
              reward_per_token_ftm_token = (alloc_emissions_to_farms[0]*supply_expansion*1000000000000000000).div(deposited_ftm_token_total*100);
            }else{
              reward_per_token_ftm_token = 0;
            }
            if(reward_per_token_ftm_share>0){
              reward_per_token_ftm_share = (alloc_emissions_to_farms[1]*supply_expansion*1000000000000000000).div(deposited_ftm_share_total*100);
            }else{
              reward_per_token_ftm_share = 0;
            }
            if(reward_per_token_share_token>0){
              reward_per_token_share_token = (alloc_emissions_to_farms[2]*supply_expansion*1000000000000000000).div(deposited_share_token_total*100);
            }else{
              reward_per_token_share_token = 0;
            }

            vested_ftm_token.push(reward_per_token_ftm_token);
            vested_ftm_share.push(reward_per_token_ftm_share);
            vested_share_token.push(reward_per_token_share_token);

            last_vested_tokens = time_now;
        }
    }

    //harvesting from ftm-native pool
    function harvest_rewards_ftm_token() public{
        uint256 ftm_token_deposited;
        uint256 amount_vested;
        uint i;

        new_epoch();
        compute_vest_tokens();
        ftm_token_deposited = ftm_token_staked[msg.sender].amount_staked;
        if(ftm_token_staked[msg.sender].entry_epoch < epoch){
            for(i=ftm_token_staked[msg.sender].entry_epoch;i<epoch;i++){
                amount_vested += (vested_ftm_token[i]*ftm_token_deposited).div(1000000000000000000);
            }
            ftm_token_staked[msg.sender].entry_epoch = epoch;
            ERC20(share_address).transfer(msg.sender, uint256(amount_vested));
        }
    }

    //harvesting from ftm-share pool
    function harvest_rewards_ftm_share() public{
        uint256 ftm_share_deposited;
        uint256 amount_vested;
        uint256 i;

        new_epoch();
        compute_vest_tokens();
        ftm_share_deposited = ftm_share_staked[msg.sender].amount_staked;
        if(ftm_share_staked[msg.sender].entry_epoch < epoch){
            for(i=ftm_share_staked[msg.sender].entry_epoch;i<epoch;i++){
                amount_vested += (vested_ftm_share[i]*ftm_share_deposited).div(1000000000000000000);
            }
            ftm_share_staked[msg.sender].entry_epoch = epoch;
            ERC20(share_address).transfer(msg.sender, uint256(amount_vested));
        }
    }

    //harvesting from share-token pool
    function harvest_rewards_share_token() public{
        uint256 share_token_deposited;
        uint256 amount_vested;
        uint256 i;

        new_epoch();
        compute_vest_tokens();
        share_token_deposited = share_token_staked[msg.sender].amount_staked;

        if(share_token_staked[msg.sender].entry_epoch < epoch){
            for(i=share_token_staked[msg.sender].entry_epoch;i<epoch;i++){
                amount_vested += (vested_share_token[i]*share_token_deposited).div(1000000000000000000);
            }
            share_token_staked[msg.sender].entry_epoch = epoch;
            ERC20(share_address).transfer(msg.sender, uint256(amount_vested));
        }
    }
}
