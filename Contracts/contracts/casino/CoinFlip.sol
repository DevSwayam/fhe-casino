// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CoinFlip is GatewayCaller, Ownable {
    using SafeERC20 for IERC20;
    address public betTokenAddress;
    uint32[] public array;
    uint256 public constant startingBalance = 100000 * 10 ** 18;
    error ZeroWager();
    using SafeERC20 for IERC20;
    bool public isInitialised;

    modifier onlyWhenInitialised() {
        if (isInitialised == false) {
            revert();
        }
        _;
    }

    constructor(address _tokenAddress) Ownable(msg.sender) {
        betTokenAddress = _tokenAddress;
    }

    function initialize() external onlyOwner {
        require(
            IERC20(betTokenAddress).transferFrom(msg.sender, address(this), startingBalance),
            "Initial funding failed"
        );
        isInitialised = true;
    }

    struct CoinFlipGame {
        uint256 wager;
        uint256 stopGain;
        uint256 stopLoss;
        uint64 blockNumber;
        uint32 numBets;
        bool isHeads;
    }

    mapping(address => CoinFlipGame) coinFlipGames;
    mapping(uint256 => address) requestIdToAddress;
    /**
     * @dev event emitted at the start of the game
     * @param playerAddress address of the player that made the bet
     * @param wager wagered amount
     * @param isHeads player bet on which side the coin will land  1-> Heads, 0 ->Tails
     * @param numBets number of bets the player intends to make
     * @param stopGain gain value at which the betting stop if a gain is reached
     * @param stopLoss loss value at which the betting stop if a loss is reached
     */
    event CoinFlip_Play_Event(
        address indexed playerAddress,
        uint256 wager,
        bool isHeads,
        uint32 numBets,
        uint256 stopGain,
        uint256 stopLoss
    );
    /**
     * @dev event emitted by the VRF callback with the bet results
     * @param playerAddress address of the player that made the bet
     * @param wager wager amount
     * @param payout total payout transfered to the player
     * @param tokenAddress address of token the wager was made and payout, 0 address is considered the native coin
     * @param coinOutcomes results of coinFlip, 1-> Heads, 0 ->Tails
     * @param payouts individual payouts for each bet
     * @param numGames number of games performed
     */
    event CoinFlip_Outcome_Event(
        address indexed playerAddress,
        uint256 wager,
        uint256 payout,
        address tokenAddress,
        uint8[] coinOutcomes,
        uint256[] payouts,
        uint32 numGames
    );

    error InvalidNumBets(uint256 maxNumBets);

    /**
     * @dev function to get current request player is await from VRF, returns 0 if none
     * @param player address of the player to get the state
     */
    function CoinFlip_GetState(address player) external view returns (CoinFlipGame memory) {
        return (coinFlipGames[player]);
    }

    /**
     * @dev Function to play Coin Flip, takes the user wager saves bet parameters and makes a request to the VRF
     * @param wager wager amount
     * @param numBets number of bets to make, and amount of random numbers to request
     * @param stopGain treshold value at which the bets stop if a certain profit is obtained
     * @param stopLoss treshold value at which the bets stop if a certain loss is obtained
     * @param isHeads if bet selected heads or Tails
     */
    function COINFLIP_PLAY(
        uint256 wager,
        bool isHeads,
        uint32 numBets,
        uint256 stopGain,
        uint256 stopLoss
    ) external onlyWhenInitialised {
        address msgSender = msg.sender;
        if (!(numBets > 0 && numBets <= 100)) {
            revert InvalidNumBets(100);
        }
        _transferWager(wager * numBets, msgSender);

        coinFlipGames[msgSender] = CoinFlipGame(wager, stopGain, stopLoss, uint64(block.number), numBets, isHeads);

        emit CoinFlip_Play_Event(msgSender, wager, isHeads, numBets, stopGain, stopLoss);
        euint64 r64 = TFHE.randEuint64();
        TFHE.allow(r64, address(this));
        uint256[] memory cts = new uint256[](1);
        cts[0] = Gateway.toUint256(r64);
        uint256 requestID = Gateway.requestDecryption(
            cts,
            this.randonNumberCallBackResolver.selector,
            0,
            block.timestamp + 100,
            false
        );
        requestIdToAddress[requestID] = msg.sender;
    }

    function randonNumberCallBackResolver(uint256 requestID, uint64 decryptedInput) public onlyGateway returns (bool) {
        address _playerAddress = requestIdToAddress[requestID];
        uint32 _numBets = coinFlipGames[_playerAddress].numBets;
        getRandomNumberAndSettleBets(_numBets, _playerAddress, decryptedInput);
        return true;
    }

    function settleBet(uint32[] memory randomWords, address playerAddress) internal {
        if (playerAddress == address(0)) revert();
        CoinFlipGame storage game = coinFlipGames[playerAddress];
        int256 totalValue;
        uint256 payout;
        uint32 i;
        uint8[] memory coinFlip = new uint8[](game.numBets);
        uint256[] memory payouts = new uint256[](game.numBets);

        address tokenAddress = betTokenAddress;

        for (i = 0; i < game.numBets; i++) {
            if (totalValue >= int256(game.stopGain)) {
                break;
            }
            if (totalValue <= -int256(game.stopLoss) && game.stopLoss != 0) {
                break;
            }

            coinFlip[i] = uint8(randomWords[i] % 2);

            if (coinFlip[i] == 1 && game.isHeads == true) {
                totalValue += int256((game.wager * 9800) / 10000);
                payout += (game.wager * 19800) / 10000;
                payouts[i] = (game.wager * 19800) / 10000;
                continue;
            }
            if (coinFlip[i] == 0 && game.isHeads == false) {
                totalValue += int256((game.wager * 9800) / 10000);
                payout += (game.wager * 19800) / 10000;
                payouts[i] = (game.wager * 19800) / 10000;
                continue;
            }

            totalValue -= int256(game.wager);
        }

        payout += (game.numBets - i) * game.wager;

        emit CoinFlip_Outcome_Event(playerAddress, game.wager, payout, tokenAddress, coinFlip, payouts, i);
        delete (coinFlipGames[playerAddress]);
        if (payout != 0) {
            _transferPayout(playerAddress, payout, tokenAddress);
        }
    }

    function getRandomNumberAndSettleBets(uint32 numBets, address playerAddress, uint64 _randomNumber) public {
        require(numBets > 0, "Invalid number of bets");

        uint32[] memory randomNumberArray = new uint32[](numBets);
        uint32 encryptedRandomNumber = uint32(_randomNumber % 6);
        for (uint256 i = 0; i < numBets; i++) {
            if (i % 2 == 0) {
                randomNumberArray[i] = ((encryptedRandomNumber + uint32(i)) % 3) + uint32(block.timestamp % 5);
            } else if (i % 3 == 0) {
                randomNumberArray[i] = ((encryptedRandomNumber + uint32(i)) % 7) + uint32(block.number % 8);
            } else if (i == 1) {
                randomNumberArray[i] = encryptedRandomNumber + uint32(i);
            } else if (i % 5 == 0) {
                randomNumberArray[i] = encryptedRandomNumber + uint32(block.number % i);
            } else {
                randomNumberArray[i] = encryptedRandomNumber;
            }
        }

        // Call settleBet with the generated random numbers
        settleBet(randomNumberArray, playerAddress);

        array = randomNumberArray;
    }

    function _transferWager(uint256 wager, address msgSender) internal {
        if (wager == 0) {
            revert ZeroWager();
        }
        IERC20(betTokenAddress).safeTransferFrom(msgSender, address(this), wager);
    }

    /**
     * @dev function to request bankroll to give payout to player
     * @param player address of the player
     * @param payout amount of payout to give
     * @param tokenAddress address of the token in which to give the payout
     */
    function _transferPayout(address player, uint256 payout, address tokenAddress) internal {
        IERC20(tokenAddress).safeTransfer(player, payout);
    }
}
