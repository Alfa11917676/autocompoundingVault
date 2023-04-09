import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, network } from "hardhat";
import {MockCurve, MockLido, StETH, Vault} from "../typechain-types";
describe("Testing Vault Params", function (){

    let lido:MockLido, curve:MockCurve, vault:Vault, stEth:StETH, user1:any, user2:any, user3:any, treasury:any;
    before("Setting up the test-suite",async() => {
        [user1, user2, treasury] = await ethers.getSigners();

        const StETH = await ethers.getContractFactory("StETH");
        stEth = (await StETH.deploy('Curve:StETH',"CStETH")) as StETH;

        const MockLido = await ethers.getContractFactory("MockLido");
        lido = (await MockLido.deploy(stEth.address)) as MockLido;

        const MockCurve = await ethers.getContractFactory("MockCurve");
        curve = (await MockCurve.deploy(stEth.address)) as MockCurve;

        const Vault = await ethers.getContractFactory("Vault");
        vault = (await Vault.deploy(stEth.address,lido.address, curve.address, treasury.address)) as Vault;

        await stEth.mint(user1.address,ethers.utils.parseEther("10000"));
        await stEth.mint(user2.address,ethers.utils.parseEther("10000"));

        await stEth.connect(user1).approve(vault.address,ethers.utils.parseEther("2000"));
        await stEth.connect(user2).approve(vault.address,ethers.utils.parseEther("2000"));
        await stEth.connect(treasury).approve(vault.address,ethers.utils.parseEther("1000000"));
        await stEth.connect(treasury).approve(lido.address,ethers.utils.parseEther("1000000"));
        await stEth.connect(treasury).approve(curve.address,ethers.utils.parseEther("1000000"));

    })

    it("Should be able to deposit", async() => {
        await vault.connect(user1).deposit(ethers.utils.parseEther("1000"),0);
        expect(await stEth.balanceOf(lido.address)).to.equal(ethers.utils.parseEther("1000"));
        expect(await vault.getUserDepositBalance(user1.address,0)).to.equal(ethers.utils.parseEther("1000"));
        await vault.connect(user1).deposit(ethers.utils.parseEther("1000"),1);
        expect(await stEth.balanceOf(curve.address)).to.equal(ethers.utils.parseEther("1000"));
        expect(await vault.getUserDepositBalance(user1.address,1)).to.equal(ethers.utils.parseEther("1000"));
        expect(await stEth.balanceOf(user1.address)).to.equal(ethers.utils.parseEther("8000"));

        // // increasing time by 5 hours
        await network.provider.send("evm_increaseTime", [3600 * 5])
        await network.provider.send("evm_mine")

        await vault.connect(user2).deposit(ethers.utils.parseEther("1000"),0);
        expect(await stEth.balanceOf(lido.address)).to.equal(ethers.utils.parseEther("2000"));
        expect(await vault.getUserDepositBalance(user2.address,0)).to.equal(ethers.utils.parseEther("1000"));
        await vault.connect(user2).deposit(ethers.utils.parseEther("1000"),1);
        expect(await stEth.balanceOf(curve.address)).to.equal(ethers.utils.parseEther("2000"));
        expect(await vault.getUserDepositBalance(user2.address,1)).to.equal(ethers.utils.parseEther("1000"));
        expect(await stEth.balanceOf(user2.address)).to.equal(ethers.utils.parseEther("8000"));
        //
        // console.log("Rewards accumulated",await vault.lidoRewardCount());
        // console.log("Rewards accumulated",await vault.curveRewardCount());
    });

    it("Should be able to check the unclaimed rewards", async() => {
        let lidoRewards, curveRewards;
        [lidoRewards,curveRewards]= await vault.getRewardBalance(user1.address);
         console.log("Lido Rewards of user 1: ",ethers.utils.formatEther(lidoRewards));
         console.log("Curve Rewards of user 1: ",ethers.utils.formatEther(curveRewards));

         console.log("Total Lido Rewards: ",ethers.utils.formatEther(await vault.lidoRewardCount()));
         console.log("Total Curve Rewards: ",ethers.utils.formatEther(await vault.curveRewardCount()));

    });

    it("User 3 entered the pool, the auto compound should get the balances of all the previous users ready", async() => {
       await stEth.mint(user3.address,ethers.utils.parseEther("10000"));
       await stEth.connect(user3).approve(vault.address,ethers.utils.parseEther("2000"));
       await vault.connect(user3).deposit(ethers.utils.parseEther("2500"),0);
       await vault.connect(user3).deposit(ethers.utils.parseEther("5000"),1);
    });




})