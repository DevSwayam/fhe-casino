import type { CoinFlip, USDC, RockPaperScissors, SlotMachine, Mines, Plinko, Dice } from "../../types";
import { getSigners } from "../signers";
import { ethers } from "hardhat";

export async function casinoContractDeploymentFixture(): Promise<[USDC, CoinFlip, RockPaperScissors, SlotMachine, Mines, Plinko, Dice]> {

  console.log("------------------------------------------------------------------");
  console.log("Deploying Game Contracts...");

  const signers = await getSigners();
  const usdcContractFactory = await ethers.getContractFactory("USDC");
  const usdcContract = await usdcContractFactory.connect(signers.alice).deploy();
  await usdcContract.waitForDeployment(); 
  const usdcContractAddress = await usdcContract.getAddress();

  const coinFlipFactory = await ethers.getContractFactory("CoinFlip");
  const coinFlipContract = await coinFlipFactory.connect(signers.alice).deploy(usdcContractAddress);
  await coinFlipContract.waitForDeployment();

  const rockPaperScissorFactory = await ethers.getContractFactory("RockPaperScissors");
  const RockPaperScissorsContract = await rockPaperScissorFactory.connect(signers.alice).deploy(usdcContractAddress);
  await RockPaperScissorsContract.waitForDeployment();

  const slotMachineFactory = await ethers.getContractFactory("SlotMachine");
  const SlotMachineContract = await slotMachineFactory.connect(signers.alice).deploy(usdcContractAddress);
  await SlotMachineContract.waitForDeployment();

  const minesFactory = await ethers.getContractFactory("Mines");
  const MinesContract = await minesFactory.connect(signers.alice).deploy(usdcContractAddress);
  await MinesContract.waitForDeployment();

  const plinkoFactory = await ethers.getContractFactory("Plinko");
  const PlinkoContract = await plinkoFactory.connect(signers.alice).deploy(usdcContractAddress);
  await PlinkoContract.waitForDeployment();

  const diceFactory = await ethers.getContractFactory("Dice");
  const DiceContract = await diceFactory.connect(signers.alice).deploy(usdcContractAddress);
  await DiceContract.waitForDeployment();

  console.log("USDC Contract Address is: ",usdcContractAddress);
  console.log("CoinFlip Contract Address is: ",await coinFlipContract.getAddress());
  console.log("RockPaperScissors Contract Address is: ",await RockPaperScissorsContract.getAddress());
  console.log("Slot Machine Contract Address is: ",await SlotMachineContract.getAddress());
  console.log("Mines Contract Address is: ",await MinesContract.getAddress());
  console.log("Plinko Contract Address is: ",await PlinkoContract.getAddress());
  console.log("Dice Contract Address is: ",await DiceContract.getAddress());
  console.log("All Game Contracts have been deployed");
  return [usdcContract, coinFlipContract, RockPaperScissorsContract,SlotMachineContract,MinesContract,PlinkoContract, DiceContract]; // Return as a tuple.
}
