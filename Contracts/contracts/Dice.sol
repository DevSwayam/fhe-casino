// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Dice is GatewayCaller,Ownable {
    using SafeERC20 for IERC20;
    address public betTokenAddress;

    error ZeroWager();

    bool public isInitialised;

    address public bankRoll;

    constructor(address _tokenAddress) Ownable(msg.sender) {
        betTokenAddress = _tokenAddress;
    }

    function initialize() external onlyOwner {
        require(
            IERC20(betTokenAddress).transferFrom(msg.sender, address(this), 100000 * 10 ** 18),
            "Initial funding failed"
        );
        isInitialised = true;
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
     */
    function _transferPayout(address player, uint256 payout) internal {
        IERC20(betTokenAddress).safeTransfer(player, payout);
    }

    struct DiceGame {
        uint256 wager;
        uint8 playerGuess;
        bool isover;
    }

    mapping(address => DiceGame) diceGames;
    mapping(uint256 => address) requestIdToAddress;
    /**
     * @dev event emitted at the start of the game
     * @param playerAddress address of the player that made the bet
     * @param wager wagered amount
     * @param isOver player bet on whether the number will be bigger or shorter
     * @param playerGuess number that player is willing to bet on
     */
    event Dice_Play_Event(address indexed playerAddress, uint256 wager, bool isOver, uint8 playerGuess);

    /**
     * @dev event emitted by the VRF callback with the bet results
     * @param playerAddress address of the player that made the bet
     * @param wager wager amount
     * @param payout total payout transfered to the player
     * @param tokenAddress address of token the wager was made and payout, 0 address is considered the native coin
     */
    event Dice_Outcome_Event(
        address indexed playerAddress,
        uint256 wager,
        uint256 payout,
        address tokenAddress,
        uint8 diceValue
    );

    function DICE_PLAY(uint8 playerGuess, bool isOver, uint256 wager) public {
        require(playerGuess > 0 && playerGuess < 100, "Guess must be between 0 and 100");

        _transferWager(wager, msg.sender);
        diceGames[msg.sender] = DiceGame(wager, playerGuess, isOver);

        emit Dice_Play_Event(msg.sender, wager, isOver, playerGuess);
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
        bool _isOver = diceGames[_playerAddress].isover;
        uint8 _playerGuess = diceGames[_playerAddress].playerGuess;
        uint256 _wager = diceGames[_playerAddress].wager;
        settleBet(_playerAddress, _isOver, _playerGuess,_wager,decryptedInput);
        return true;
    }

    function settleBet(address playerAddress, bool isOver, uint8 playerGuess, uint256 wager, uint64 _randomNumber) internal {
        // Generate a random number
        uint8 randomNumber = uint8(_randomNumber % 101);

        bool playerWins = (isOver && randomNumber > playerGuess) || (!isOver && randomNumber < playerGuess);
        uint256 payout;

        if (playerWins) {
            uint256 probability = isOver ? 100 - playerGuess : playerGuess;
            payout = (((wager * 100) / probability) * (100 - 2)) / 100;
        }
        emit Dice_Outcome_Event(playerAddress, wager, payout, betTokenAddress, randomNumber);
        if (payout != 0) {
            _transferPayout(playerAddress, payout);
        }
        delete diceGames[playerAddress];
    }
}
