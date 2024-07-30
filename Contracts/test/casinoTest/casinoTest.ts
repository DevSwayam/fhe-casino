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
    const [usdcContract, coinFlipContract, RockPaperScissorsContract, SlotMachineContract,MinesContract,PlinkoContract,DiceContract] = await casinoContractDeploymentFixture();
    this.contractAddress = await usdcContract.getAddress();
    this.usdc = usdcContract;
    this.coinFlip = coinFlipContract;
    this.rockPaperScissors = RockPaperScissorsContract;
    this.slotMachine = SlotMachineContract;
    this.mines = MinesContract;
    this.plinko = PlinkoContract;
    this.dice = DiceContract;
    this.instances = await createInstances(this.signers);
  });

  it("It should be able to play Dice", async function () {
    console.log("------------------------------------------------------------------");
    console.log("Testing Dice Contract...");
    
    const aliceDice = await this.dice.connect(this.signers.alice);

    console.log("Balance of Alice before initilisation is: ", await this.usdc.balanceOf(this.signers.alice.address));

    const usdcInitializationTx = await this.usdc.initialize([await aliceDice.getAddress()]);
    await usdcInitializationTx.wait();
    const transaction = await aliceDice.initialize();
    await transaction.wait();

    console.log("Balance of Alice Before Playing Game is: ", await this.usdc.balanceOf(this.signers.alice.address));

    const wagerValue = ethers.parseUnits("10", "ether");
    const playerGuess = 75;
    const isOver = true;
    // Send the transaction
    const diePlayTx = await aliceDice.DICE_PLAY(playerGuess, isOver, wagerValue, {
      gasLimit: 2000000,
    });
    await diePlayTx.wait();
    console.log("Balance of Alice Just after Play Transaction is: ", await this.usdc.balanceOf(this.signers.alice.address));

    await awaitAllDecryptionResults();
    console.log("Balance of Alice the Play Transaction resloved is : ", await this.usdc.balanceOf(this.signers.alice.address));
    
  });

  it("It should be able to play Plinko", async function () {
    console.log("------------------------------------------------------------------");
    console.log("Testing Plinko Contract...");
    
    const alicePlinko = await this.plinko.connect(this.signers.alice);

    console.log("Balance of Alice before initilisation is: ", await this.usdc.balanceOf(this.signers.alice.address));

    const usdcInitializationTx = await this.usdc.initialize([await alicePlinko.getAddress()]);
    await usdcInitializationTx.wait();
    const transaction = await alicePlinko.initialize();
    await transaction.wait();

    console.log("Balance of Alice Before Playing Game is: ", await this.usdc.balanceOf(this.signers.alice.address));

    const wagerValue = ethers.parseUnits("10", "ether");
    // Send the transaction
    const plinkoPlayTx = await alicePlinko.PLINKO_PLAY(wagerValue, {
      gasLimit: 2000000,
    });
    await plinkoPlayTx.wait();
    console.log("Balance of Alice Just after Play Transaction is: ", await this.usdc.balanceOf(this.signers.alice.address));

    await awaitAllDecryptionResults();
    console.log("Balance of Alice the Play Transaction resloved is : ", await this.usdc.balanceOf(this.signers.alice.address));
    
  });


  it("It should be able to play Mines", async function () {
    console.log("------------------------------------------------------------------");
    console.log("Testing Mines Contract...");
    
    const aliceMines = await this.mines.connect(this.signers.alice);

    console.log("Balance of Alice before initilisation is: ", await this.usdc.balanceOf(this.signers.alice.address));

    const usdcInitializationTx = await this.usdc.initialize([await aliceMines.getAddress()]);
    await usdcInitializationTx.wait();
    const transaction = await aliceMines.initialize();
    await transaction.wait();

    console.log("Balance of Alice Before Playing Game is: ", await this.usdc.balanceOf(this.signers.alice.address));

    const wagerValue = ethers.parseUnits("10", "ether");
    const minesBettingPositions = [[1,2],[0,4],[3,1]];
    const numMines = 4;
    // Send the transaction
    const minesPlayTx = await aliceMines.MINES_PLAY(minesBettingPositions,numMines,wagerValue, {
      gasLimit: 2000000,
    });
    await minesPlayTx.wait();
    console.log("Balance of Alice Just after Play Transaction is: ", await this.usdc.balanceOf(this.signers.alice.address));

    await awaitAllDecryptionResults();
    console.log("Balance of Alice the Play Transaction resloved is : ", await this.usdc.balanceOf(this.signers.alice.address));
    
  });

  it("It should be able to play Slot Machine", async function () {
    console.log("------------------------------------------------------------------");
    console.log("Testing Slot Machine Contract...");
    
    const aliceSlotMachine = await this.slotMachine.connect(this.signers.alice);

    console.log("Balance of Alice before initilisation is: ", await this.usdc.balanceOf(this.signers.alice.address));

    const usdcInitializationTx = await this.usdc.initialize([await aliceSlotMachine.getAddress()]);
    await usdcInitializationTx.wait();
    const transaction = await aliceSlotMachine.initialize();
    await transaction.wait();

    console.log("Balance of Alice Before Playing Game is: ", await this.usdc.balanceOf(this.signers.alice.address));

    const wagerValue = ethers.parseUnits("10", "ether");
    // Send the transaction
    const slotMachinePlayTx = await aliceSlotMachine.SLOTMACHINE_PLAY(wagerValue, {
      gasLimit: 2000000,
    });
    await slotMachinePlayTx.wait();
    console.log("Balance of Alice Just after Play Transaction is: ", await this.usdc.balanceOf(this.signers.alice.address));

    await awaitAllDecryptionResults();
    console.log("Balance of Alice the Play Transaction resloved is : ", await this.usdc.balanceOf(this.signers.alice.address));
    
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

    it("It should transfer from the owner", async function () {
    const bobUsdc = this.usdc.connect(this.signers.bob);
    const tx = await bobUsdc["transferFromOwner()"]();
    await tx.wait();
    const balanceHandle = await this.usdc.balanceOf(this.signers.bob.address);
    console.log(balanceHandle);
  });

  
  it("It should be able to intitialise all contracts", async function () {
    const aliceCoinFlip = await this.coinFlip.connect(this.signers.alice);
    const aliceDice = await this.dice.connect(this.signers.alice);
    const alicePlinko = await this.plinko.connect(this.signers.alice);
    const aliceMines = await this.mines.connect(this.signers.alice);
    const aliceRockPaperScissor = await this.rockPaperScissors.connect(this.signers.alice);
    const aliceSlotMachine = await this.slotMachine.connect(this.signers.alice);
    const usdcInitializationTx = await this.usdc.initialize(
      [
        await aliceCoinFlip.getAddress(),
        await aliceDice.getAddress(),
        await aliceMines.getAddress(),
        await alicePlinko.getAddress(),
        await aliceRockPaperScissor.getAddress(),
        await aliceSlotMachine.getAddress(),
      ]);
    await usdcInitializationTx.wait();
    const transaction = await aliceCoinFlip.initialize();
    await transaction.wait();
  });


  
});
