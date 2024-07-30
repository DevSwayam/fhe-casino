// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Plinko is GatewayCaller, Ownable {
    using SafeERC20 for IERC20;
    address public betTokenAddress;
    bool public isInitialised;
    uint256 counter;

    error ZeroWager();

    mapping(address => PlinkoGame) plinkoGames;
    mapping(uint256 => address) requestIdToAddress;

    struct PlinkoGame {
        uint256 wager;
    }

    /**
     * @dev event emitted at the start of the game
     * @param playerAddress address of the player that made the bet
     * @param wager wagered amount
     */
    event Plinko_Play_Event(address indexed playerAddress, uint256 wager);

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

    event Plinko_Outcome_Event(
        address indexed playerAddress,
        uint256 wager,
        uint256 payout,
        address tokenAddress,
        uint8[8] randomBits,
        uint256 spinPayout
    );

    function PLINKO_PLAY(uint256 wager) external {
        address msgSender = msg.sender;
        _transferWager(wager, msgSender);

        plinkoGames[msg.sender] = PlinkoGame(wager);

        emit Plinko_Play_Event(msg.sender, wager);
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
        uint256 _wager = plinkoGames[_playerAddress].wager;
        settleBet(_wager, _playerAddress, decryptedInput);
        return true;
    }

    function settleBet(uint256 wager, address playerAddress, uint64 _randomNumber) internal {
        require(playerAddress != address(0), "Invalid player address");
        address tokenAddress = betTokenAddress;
        uint8[8] memory randomBits = generate8RandomBits(_randomNumber);
        uint256 spinPayout = calculatePlinkoPayout(wager, randomBits);

        emit Plinko_Outcome_Event(playerAddress, wager, spinPayout, tokenAddress, randomBits, spinPayout);
        delete plinkoGames[playerAddress];
        if (spinPayout != 0) {
            _transferPayout(playerAddress, spinPayout);
        }
    }

    function generate8RandomBits(uint64 _randomNumber) internal pure returns (uint8[8] memory) {
        uint8 randomNumber = uint8(_randomNumber % 128);
        uint8[8] memory randomBits;

        for (uint8 i = 0; i < 8; i++) {
            randomBits[i] = (randomNumber >> i) & 1;
        }
        return randomBits;
    }

    function calculatePlinkoPayout(uint256 wager, uint8[8] memory directions) internal returns (uint256) {
        int8 position = 0;

        // Calculate final position based on directions
        for (uint8 i = 0; i < 8; i++) {
            if (directions[i] == 1) {
                position += 1;
            } else {
                position -= 1;
            }
        }
        counter++;
        if (position == -8 || position == 8) {
            return wager * 16;
        } else if (position == -7 || position == 7) {
            return wager * 8;
        } else if (position == -6 || position == 6) {
            return wager * 4;
        } else if (position == -5 || position == 5) {
            return wager * 2;
        } else if (position == -4 || position == 4) {
            return (wager * 1);
        } else if (position == -3 || position == 3) {
            return (wager * 1) / 2;
        } else if (position == -2 || position == 2) {
            return (wager * 1) / 4;
        } else if (position == -1 || position == 1) {
            return (wager * 1) / 8;
        } else {
            return (wager * 1) / 16;
        }
    }
}
