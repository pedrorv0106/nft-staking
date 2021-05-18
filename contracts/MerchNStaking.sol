// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./NFT.sol";
import "hardhat/console.sol";

contract MerchNStaking is Ownable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    struct Stake {
        uint amount;
        uint startTime; 
        uint rewardOut;
    }

    // Info of each pool.
    struct Pool {
        uint stakingCap; // Pool staking tokens limit
        uint fixedStakingAmount; // Fixed staking amount to the pool
        uint rewardAPY; // scaled by 1e12
        uint startTime; 
        uint endTime; 
        uint stakedTotal; 
    }
    Pool[] public pools;

    mapping(uint => mapping(address => Stake)) public stakes;
    uint[] public nftIds;
    mapping(address => uint[]) public nftIdsPerAddr;
    address public stakeToken; // MRCH token
    NFT public nft; // NFT token

    uint randNonce = 0;
    address public admin;

    event Staked(uint pid, address staker, uint amount);
    event RewardOut(uint pid, address staker, address token, uint amount);

    constructor(
        address _stakeToken,
        address _nftAddress
    ) {
        admin = msg.sender;

        require(_stakeToken != address(0), "MerchNStaking: stake token address is 0");
        stakeToken = _stakeToken;
        nft = NFT(_nftAddress);
    }
    
    function addPool(uint _stakingCap, uint _fixedStakingAmount, uint _rewardAPY, uint _startTime, uint _endTime) public onlyOwner {
        require(_startTime < _endTime, "MerchNStaking: endTime > startTime");
        
        pools.push(
            Pool({
            stakingCap: _stakingCap,
            fixedStakingAmount: _fixedStakingAmount,
            rewardAPY: _rewardAPY,
            startTime: _startTime,
            endTime: _endTime,
            stakedTotal: 0
            })
        );
    }

    function stake(uint _pid, uint _amount) public returns (bool) {
        address staker = msg.sender;

        require(_amount == pools[_pid].fixedStakingAmount, "MerchNStaking: wrong amount");
        require(stakes[_pid][staker].amount == 0, "MerchNStaking: already staked");
        require(getTimeStamp() >= pools[_pid].startTime, "MerchNStaking: bad timing request");
        require(getTimeStamp() < pools[_pid].endTime, "MerchNStaking: bad timing request");

        require(pools[_pid].stakedTotal.add(_amount) <= pools[_pid].stakingCap, "MerchNStaking: Staking cap is filled");
    
        transferIn(staker, stakeToken, _amount);

        emit Staked(_pid, staker, _amount);

        // Transfer is completed
        pools[_pid].stakedTotal = pools[_pid].stakedTotal.add(_amount);
        stakes[_pid][staker].amount = stakes[_pid][staker].amount.add(_amount);
        stakes[_pid][staker].startTime = getTimeStamp();
        stakes[_pid][staker].rewardOut = 0;

        return true;
    }

    function withdraw(uint _pid) public returns (bool) {
        uint amount = stakes[_pid][msg.sender].amount;
        require(getTimeStamp() > pools[_pid].endTime, "MerchNStaking: bad timing request");
        require(amount > 0, "MerchNStaking: nothing to withdraw");
        require(claim(_pid), "MerchNStaking: claim error");

        genNFTId(msg.sender);

        return withdrawWithoutReward(_pid, amount);
    }

    function genNFTId(address _to) internal {
        uint newNFTId = rand();
        nftIds.push(newNFTId);
        nftIdsPerAddr[_to].push(newNFTId);
        nft.mint(_to, newNFTId);
    }

    function withdrawWithoutReward(uint _pid, uint _amount) public returns (bool) {
        return withdrawInternal(_pid, msg.sender, _amount);
    }

    function withdrawInternal(uint _pid, address _staker, uint _amount) internal returns (bool) {
        require(_amount > 0, "MerchNStaking: must be positive");
        require(_amount <= stakes[_pid][msg.sender].amount, "MerchNStaking: not enough balance");

        stakes[_pid][_staker].amount = stakes[_pid][_staker].amount.sub(_amount);

        transferOut(stakeToken, _staker, _amount);

        return true;
    }

    function claim(uint _pid) internal returns (bool) {
        require(getTimeStamp() > pools[_pid].endTime, "MerchNStaking: bad timing request");
        address staker = msg.sender;
        
        uint rewardAmount = currentReward(_pid, staker);
        if (rewardAmount == 0) {
            return true;
        }

        transferOut(stakeToken, staker, rewardAmount);

        stakes[_pid][staker].rewardOut = stakes[_pid][staker].rewardOut.add(rewardAmount);

        emit RewardOut(_pid, staker, stakeToken, rewardAmount);

        return true;
    }

    function currentReward(uint _pid, address _staker) public view returns (uint) {
        uint totalRewardAmount = stakes[_pid][_staker].amount.mul(pools[_pid].rewardAPY).div(1e12).div(100);
        uint totalDuration = pools[_pid].endTime - stakes[_pid][_staker].startTime;
        uint duration = (getTimeStamp() > pools[_pid].endTime ? pools[_pid].endTime : getTimeStamp()) - stakes[_pid][_staker].startTime;

        uint rewardAmount = totalRewardAmount.mul(duration).div(totalDuration);
        return rewardAmount.sub(stakes[_pid][_staker].rewardOut);
    }

    function transferOut(address _token, address _to, uint _amount) internal {
        if (_amount == 0) {
            return;
        }

        IERC20 ERC20Interface = IERC20(_token);
        ERC20Interface.safeTransfer(_to, _amount);
    }

    function transferIn(address _from, address _token, uint _amount) internal {
        IERC20 ERC20Interface = IERC20(_token);
        ERC20Interface.safeTransferFrom(_from, address(this), _amount);
    }

    function getTimeStamp() public view virtual returns (uint) {
        return block.timestamp;
    }

    function rand() internal view returns(uint) {
        return randMod(2 ** 16);
        
    }

    function randMod(uint _modulus) internal view returns(uint) {
        return uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))) % _modulus;
    }
}