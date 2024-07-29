import { ethers } from "ethers";

import { createInstances, decrypt64 } from "../instance";
import { getSigners, initSigners } from "../signers";
import { casinoContractDeploymentFixture } from "./casinoDeploymentFixture.fixture";
import { awaitAllDecryptionResults } from "../asyncDecrypt";


describe("Casino Tests", function () {
  before(async function () {
    await initSigners();
    this.signers = await getSigners();
  });

  beforeEach(async function () {
    const [usdcContract, coinFlipContract, RockPaperScissorsContract] = await casinoContractDeploymentFixture();
    this.contractAddress = await usdcContract.getAddress();
    this.usdc = usdcContract;
    this.coinFlip = coinFlipContract;
    this.rockPaperScissors = RockPaperScissorsContract;
    this.instances = await createInstances(this.signers);
  });


  it("It should be able to play RockPaperScissors", async function () {
    console.log("------------------------------------------------------------------");
    console.log("Testing RockPaperScissors Contract...");
    
    const aliceRockPaperScissor = await this.rockPaperScissors.connect(this.signers.alice);

    console.log("Balance of Alice before initilisation is: ", await this.usdc.balanceOf(this.signers.alice.address));

    const usdcInitializationTx = await this.usdc.initialize([await aliceRockPaperScissor.getAddress()]);
    await usdcInitializationTx.wait();
    const transaction = await aliceRockPaperScissor.initialize();
    await transaction.wait();

    console.log("Balance of Alice Before Playing Game is: ", await this.usdc.balanceOf(this.signers.alice.address));

    const wagerValue = ethers.parseUnits("10", "ether");
    const stopGainValue = ethers.parseUnits("1000", "ether");
    const stopLossValue = ethers.parseUnits("0", "ether");
    const numBets = 10;
    // Send the transaction
    const rockPaperScissorPlayTx = await aliceRockPaperScissor.ROCKPAPERSCISSORS_PLAY(wagerValue, 1, numBets, stopGainValue, stopLossValue, {
      gasLimit: 2000000,
    });
    await rockPaperScissorPlayTx.wait();
    console.log("Balance of Alice Just after Play Transaction is: ", await this.usdc.balanceOf(this.signers.alice.address));

    await awaitAllDecryptionResults();
    console.log("Balance of Alice the Play Transaction resloved is : ", await this.usdc.balanceOf(this.signers.alice.address));
    
  });


  it("It should be able to play CoinFlip", async function () {
    console.log("------------------------------------------------------------------");
    console.log("Testing CoinFlip Contract...");

    const aliceCoinFlip = await this.coinFlip.connect(this.signers.alice);

    console.log("Balance of Alice before initilisation is: ", await this.usdc.balanceOf(this.signers.alice.address));

    const usdcInitializationTx = await this.usdc.initialize([await aliceCoinFlip.getAddress()]);
    await usdcInitializationTx.wait();
    const transaction = await aliceCoinFlip.initialize();
    await transaction.wait();

    console.log("Balance of Alice Before Playing Game is: ", await this.usdc.balanceOf(this.signers.alice.address));

    const wagerValue = ethers.parseUnits("10", "ether");
    const stopGainValue = ethers.parseUnits("1000", "ether");
    const stopLossValue = ethers.parseUnits("0", "ether");
    const numBets = 10;
    // Send the transaction
    const playCoinFlipTx = await aliceCoinFlip.COINFLIP_PLAY(wagerValue, true, numBets, stopGainValue, stopLossValue, {
      gasLimit: 2000000,
    });
    await playCoinFlipTx.wait();
    console.log("Balance of Alice Just after Play Transaction is: ", await this.usdc.balanceOf(this.signers.alice.address));

    await awaitAllDecryptionResults();
    console.log("Balance of Alice the Play Transaction resloved is : ", await this.usdc.balanceOf(this.signers.alice.address));
  });

  
  /*
  it("It should be able to intitialise contract", async function () {
    const aliceCoinFlip = await this.coinFlip.connect(this.signers.alice);
    const usdcInitializationTx = await this.usdc.initialize([await aliceCoinFlip.getAddress()]);
    await usdcInitializationTx.wait();
    const transaction = await aliceCoinFlip.initialize();
    await transaction.wait();
  });

  it("It should transfer from the owner", async function () {
    const bobUsdc = this.usdc.connect(this.signers.bob);
    const tx = await bobUsdc["transferFromOwner()"]();
    await tx.wait();
    const balanceHandle = await this.usdc.balanceOf(this.signers.bob.address);
    console.log(balanceHandle);
  });
  */
});
