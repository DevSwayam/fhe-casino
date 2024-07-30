// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RockPaperScissors is GatewayCaller, Ownable {
    using SafeERC20 for IERC20;
    address public betTokenAddress;
    bool public isInitialised;
    error ZeroWager();

    struct RockPaperScissorsGame {
        uint256 wager;
        uint256 stopGain;
        uint256 stopLoss;
        uint64 blockNumber;
        uint32 numBets;
        uint8 action;
    }

    /**
     * @dev event emitted at the start of the game
     * @param playerAddress address of the player that made the bet
     * @param wager wagered amount
     * @param action player bet on what rock, paper or scissors
     * @param numBets number of bets the player intends to make
     * @param stopGain gain value at which the betting stop if a gain is reached
     * @param stopLoss loss value at which the betting stop if a loss is reached
     */
    event RockPaperScissors_Play_Event(
        address indexed playerAddress,
        uint256 wager,
        uint8 action,
        uint32 numBets,
        uint256 stopGain,
        uint256 stopLoss
    );

    mapping(address => RockPaperScissorsGame) rockPaperScissorsGames;
    mapping(uint256 => address) requestIdToAddress;

    constructor(address _tokenAddress) Ownable(msg.sender) {
        betTokenAddress = _tokenAddress;
    }

    function initialize() external onlyOwner {
        require(
            IERC20(betTokenAddress).transferFrom(
                msg.sender,
                address(this),
                100000 * 10 ** 18
            ),
            "Initial funding failed"
        );
        isInitialised = true;
    }

    /**
     * @dev function to get current request player is await from VRF, returns 0 if none
     * @param player address of the player to get the state
     */
    function RockPaperScissors_GetState(address player) external view returns (RockPaperScissorsGame memory) {
        return (rockPaperScissorsGames[player]);
    }

    function _transferWager(uint256 wager, address msgSender) internal {
        if (wager == 0) {
            revert ZeroWager();
        }
        IERC20(betTokenAddress).safeTransferFrom(
            msgSender,
            address(this),
            wager
        );
    }

    /**
     * @dev function to request bankroll to give payout to player
     * @param player address of the player
     * @param payout amount of payout to give
     */
    function _transferPayout(address player, uint256 payout) internal {
        IERC20(betTokenAddress).safeTransfer(player, payout);
    }

    event RockPaperScissors_Outcome_Event(
        address indexed playerAddress,
        uint256 wager,
        uint256 payout,
        address tokenAddress,
        uint256[] payouts,
        uint32[] randomNumberArray,
        uint32 numGames
    );

    error InvalidAction();
    error InvalidNumBets(uint256 maxNumBets);

    function ROCKPAPERSCISSORS_PLAY(
        uint256 wager,
        uint8 action,
        uint32 numBets,
        uint256 stopGain,
        uint256 stopLoss
    ) external {
        address msgSender = _msgSender();
        if (action >= 3) {
            revert InvalidAction();
        }
        if (!(numBets > 0 && numBets <= 100)) {
            revert InvalidNumBets(100);
        }
        _transferWager(wager * numBets, msgSender);
        rockPaperScissorsGames[msgSender] = RockPaperScissorsGame(wager, stopGain, stopLoss, uint64(block.number), numBets, action);

        emit RockPaperScissors_Play_Event(msgSender, wager, action, numBets, stopGain, stopLoss);
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
        uint32 _numBets = rockPaperScissorsGames[_playerAddress].numBets;
        getRandomNumberAndSettleBets(_numBets, _playerAddress, decryptedInput);
        return true;
    }

    function settleBet(
        address playerAddress,
        uint32[] memory randomWords
    ) internal {

        if (playerAddress == address(0)) revert();
        RockPaperScissorsGame storage game = rockPaperScissorsGames[playerAddress];
        int256 totalValue;
        uint256 payout;
        uint32 i;
        uint8[] memory randomActions = new uint8[](game.numBets);
        uint256[] memory payouts = new uint256[](game.numBets);

        for (i = 0; i < game.numBets; i++) {
            if (totalValue >= int256(game.stopGain)) {
                break;
            }
            if (totalValue <= -int256(game.stopLoss)) {
                break;
            }
            randomActions[i] = uint8(randomWords[i] % 3);
            if (randomActions[i] == game.action) {
                payout += game.wager;
                payouts[i] = game.wager;
                totalValue += int256(payouts[i]);
            } else if (
                // 0 = rock , 1 = paper , 2 = scissor
                (game.action == 0 && randomActions[i] == 2) ||
                (game.action == 1 && randomActions[i] == 0) ||
                (game.action == 2 && randomActions[i] == 1)
            ) {
                payout += game.wager * 7/4;
                payouts[i] = game.wager * 7/4;
                totalValue += int256(payouts[i]);
            } else {
                totalValue -= int256(game.wager);
            }
        }
        payout += (game.numBets - i) * game.wager;
        emit RockPaperScissors_Outcome_Event(
            playerAddress,
            game.wager,
            payout,
            betTokenAddress,
            payouts,
            randomWords,
            i
        );
        delete (rockPaperScissorsGames[playerAddress]);
        if (payout > 0) {
            _transferPayout(playerAddress, payout);
        }
    }

    //need  to figure out logic
    function getRandomNumberAndSettleBets(
        uint32 numBets,
        address playerAddress,
        uint64 _randomNumber
    ) public {
        require(numBets > 0, "Invalid number of bets");
        uint32[] memory randomNumberArray = new uint32[](numBets);
        uint32 encryptedRandomNumber = uint32(
            _randomNumber % 6
        );
        for (uint256 i = 0; i < numBets; i++) {
            if (i % 2 == 0) {
                randomNumberArray[i] =
                    ((encryptedRandomNumber + uint32(i)) % 3) +
                    uint32(block.timestamp % 5);
            } else if (i % 3 == 0) {
                randomNumberArray[i] =
                    ((encryptedRandomNumber + uint32(i)) % 7) +
                    uint32(block.timestamp % 8);
            } else {
                randomNumberArray[i] =
                    ((encryptedRandomNumber + uint32(i)) % 6) +
                    uint32(block.timestamp % 4);
            }
        }
        settleBet(
            playerAddress,
            randomNumberArray
        );
    }
}