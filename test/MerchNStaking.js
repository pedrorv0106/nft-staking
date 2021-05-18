const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { time } = require('@openzeppelin/test-helpers');
const {
  isCallTrace,
} = require("hardhat/internal/hardhat-network/stack-traces/message-trace");

describe("MerchNStaking contract", function () {
  let MerchNStaking;
  let merchNStaking;
  let owner;
  let addr1;
  let addr2;
  let minter;
  let addrs;
  let ERC20Mock;
  let NFT;
  let nft;
  let stakeToken;

  beforeEach(async function () {
    MerchNStaking = await ethers.getContractFactory("MerchNStaking");
    [
      owner, 
      addr1,
      addr2,
      minter,
      ...addrs
    ] = await ethers.getSigners();
    ERC20Mock = await ethers.getContractFactory("ERC20Mock", minter)
    stakeToken = await ERC20Mock.deploy("MerchDAO", "MRCH", "10000000000")
    NFT = await ethers.getContractFactory("NFT", minter)
    nft = await NFT.deploy("MerchDAONFT", "NFT")
    merchNStaking = await MerchNStaking.deploy(stakeToken.address, nft.address);
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await merchNStaking.owner()).to.equal(owner.address);
    });
    
    it("Should set correct state variables", async function () {
      expect(await merchNStaking.stakeToken()).to.equal(stakeToken.address);
      expect(await merchNStaking.nft()).to.equal(nft.address);
    });

  });

  describe("MerchNStaking", function () {
    it("Should stake token to the pool", async function () {
      await stakeToken.transfer(merchNStaking.address, 100000000);
      expect(await stakeToken.balanceOf(merchNStaking.address)).to.equal(100000000);
      const currentTimeStamp = Math.floor(Date.now() / 1000);
      const startTime = currentTimeStamp;
      const endTime = startTime + 30 * 24 * 60 * 60; 
      await merchNStaking.addPool(100000000, 1000, 3*10**12, startTime, endTime);

      await stakeToken.transfer(addr1.address, "10000");
      await stakeToken.connect(addr1).approve(merchNStaking.address, "10000", { from: addr1.address });
      await merchNStaking.connect(addr1).stake(0, 1000);
      expect(await stakeToken.balanceOf(addr1.address)).to.equal(9000);
      await time.increase(30 * 24 * 60 * 60 + 1);
      await merchNStaking.connect(addr1).withdraw(0);
      const nftId1 = await merchNStaking.nftIdsPerAddr(addr1.address, 0);
      assert(!!nftId1, "MerchNStaking: greater than zero");
  });
  });
});



