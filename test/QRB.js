const { expect } = require("chai");
const { ethers, waffle } = require("hardhat");
const PancakeRouterAddress = "0x10ED43C718714eb63d5aA57B78B54704E256024E";

async function addDelayInMins(mins) {
  const tenMinutes = mins * 60;
  await network.provider.send("evm_increaseTime", [tenMinutes]);
  await network.provider.send("evm_mine");
}

describe("QRBToken and RewardDistributor Test", function () {
  let QRBToken, RewardDistributor, qrb, distributor, owner, addr1, addr2, pair, addr3;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3, pair] = await ethers.getSigners();

    QRBToken = await ethers.getContractFactory("QRBToken");
    RewardDistributor = await ethers.getContractFactory("RewardDistributor");

    qrb = await QRBToken.deploy();
    console.log("owner address", owner.address);

    console.log("QRBToken Deployed at:", qrb.address);

    distributor = await RewardDistributor.deploy(qrb.address, PancakeRouterAddress);

    console.log("RewardDistributor Deployed at:", distributor.address);

    await qrb.setRewardDistributor(distributor.address);
  });

  it("Should deploy QRBToken and RewardDistributor", async function () {
    expect(await qrb.totalSupply()).to.equal(ethers.utils.parseEther("1000000"));
    expect(await distributor.QRBToken()).to.equal(qrb.address);
  });

  it("Owner should transfer correct amount", async function () {
    const amount = ethers.utils.parseEther("1000");
    await qrb.transfer(addr1.address, amount);
    expect(await qrb.balanceOf(addr1.address)).to.equal(amount);
  });

  it("upon receiving QRB, user should have reflection parallel balance", async function () {
    const amount = ethers.utils.parseEther("1000");
    await qrb.transfer(addr1.address, amount);
    expect(await distributor.balanceOf(addr1.address)).to.equal(amount);
  });

  it("virtual reflection balance should follow QRB balance", async function () {
    const amount = ethers.utils.parseEther("1000");
    await qrb.transfer(addr1.address, amount);
    await qrb.launch();
    await addDelayInMins(10); // to bypass the antisnipe
    await qrb.connect(owner).setPair(pair.address, true);
    await qrb.connect(addr1).transfer(addr2.address, ethers.utils.parseEther("10"));
    expect(await distributor.balanceOf(addr1.address)).to.equal("990000000000000000000");
    expect(await distributor.balanceOf(addr2.address)).to.equal("10000000000000000000");
  });

  it("5% should be deducted on QRB sell", async function () {
    const amount = ethers.utils.parseEther("1000");
    await qrb.transfer(addr1.address, amount);
    await qrb.launch();
    await addDelayInMins(10); // to bypass the antisnipe
    await qrb.connect(owner).setPair(pair.address, true);
    await qrb.connect(addr1).transfer(pair.address, ethers.utils.parseEther("100"));
    expect(await qrb.balanceOf(pair.address)).to.equal("95000000000000000000");
  });

  it("should increase virtual balance for holders using reflection when someone is selling", async function () {
    const amount = ethers.utils.parseEther("1000");
    await qrb.transfer(addr1.address, amount);
    await qrb.transfer(addr3.address, ethers.utils.parseEther("100"));
    await qrb.launch();
    await addDelayInMins(10); // to bypass the antisnipe
    await qrb.connect(owner).setPair(pair.address, true);
    await qrb.connect(addr1).transfer(pair.address, ethers.utils.parseEther("100"));
    console.log("await distributor.balanceOf(addr3.address)", await distributor.balanceOf(addr3.address));
    expect(await distributor.balanceOf(addr3.address)).to.gt(ethers.utils.parseEther("100"));
  });
});
