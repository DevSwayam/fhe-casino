// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Mines is GatewayCaller,Ownable {
    using SafeERC20 for IERC20;

    address public betTokenAddress;
    bool public isInitialised;
    uint256 public houseBalance;
    uint256 counter;

    mapping(address => MinesGame) minesGames;
    mapping(uint256 => address) requestIdToAddress;

    struct MinesGame {
        uint8[2][] points;
        uint8 numMines;
        uint256 wager;
    }

    /**
     * @dev event emitted at the start of the game
     * @param playerAddress address of the player that made the bet
     * @param wager wagered amount
     * @param numMines number of selected tiles
     * @param points player bets on the index of tiles
     */
    event Mines_Play_Event(
        address indexed playerAddress,
        uint256 wager,
        uint8 numMines,
        uint8[2][] points
    );

    modifier onlyWhenInitialised() {
        require(isInitialised, "Contract is not initialized");
        _;
    }

    constructor(address _tokenAddress) Ownable(msg.sender) {
        betTokenAddress = _tokenAddress;
    }

    function initialize() external onlyOwner {
        require(
            IERC20(betTokenAddress).transferFrom(
                msg.sender,
                address(this),
                100000 * 10**18
            ),
            "Initial funding failed"
        );
        isInitialised = true;
        houseBalance = 100000 * 10**18;
    }

    event MinesGameOutcome(
        address indexed playerAddress,
        uint256 wager,
        uint256 payout,
        address tokenAddress,
        uint8[2][] selectedPoints,
        uint8[2][] minePositions
    );

    function MINES_PLAY(
        uint8[2][] memory points,
        uint8 numMines,
        uint256 wager
    ) external onlyWhenInitialised {
        require(wager > 0, "Wager must be greater than zero");
        require(numMines > 0 && numMines <= 5, "Invalid number of mines");
        require(points.length <= 10, "Cannot select more than 10 points");

        for (uint8 i = 0; i < points.length; i++) {
            require(
                points[i][0] < 5 && points[i][1] < 5,
                "Invalid point coordinates"
            );
        }

        _transferWager(wager, msg.sender);


        minesGames[msg.sender] = MinesGame(points,numMines,wager);

        emit Mines_Play_Event(msg.sender, wager, numMines,points);
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
        uint8[2][] memory _points = minesGames[_playerAddress].points;      
        uint8 _numMines = minesGames[_playerAddress].numMines;    
        uint256 _wager =  minesGames[_playerAddress].wager;
        settleBet(_points, _numMines, _wager, _playerAddress,decryptedInput);
        return true;
    }

    function settleBet(
        uint8[2][] memory points,
        uint8 numMines,
        uint256 wager,
        address playerAddress,
        uint64 _randomNumber
    ) internal {
        require(playerAddress != address(0), "Invalid player address");

        uint8[2][] memory minePositions = new uint8[2][](numMines);

        for (uint8 i = 0; i < numMines; i++) {
            uint8 randValue1 = uint8(((_randomNumber >> (i * 5)) & 0x3F) % 5); // Extract 6 bits and take modulo 5
            uint8 randValue2 = uint8(((_randomNumber >> ((i * 5) + 3)) & 0x3F) % 5); // Extract the next 6 bits and take modulo 5
            minePositions[i] = [randValue1, randValue2];
        }

        bool hitMine = false;
        for (uint8 i = 0; i < points.length; i++) {
            for (uint8 j = 0; j < minePositions.length; j++) {
                if (
                    points[i][0] == minePositions[j][0] &&
                    points[i][1] == minePositions[j][1]
                ) {
                    hitMine = true;
                    break;
                }
            }
            if (hitMine) break;
        }

        uint256 payout = 0;
        if (!hitMine) {
            payout = calculatePayout(uint8(points.length), numMines, wager);
        }

        houseBalance += wager;
        if (payout != 0) {
            houseBalance -= payout;
            _transferPayout(playerAddress, payout, betTokenAddress);
        }

        delete (minesGames[playerAddress]);
        emit MinesGameOutcome(
            playerAddress,
            wager,
            payout,
            betTokenAddress,
            points,
            minePositions
        );
    }

    function calculatePayout(
        uint8 numPoints,
        uint8 numMines,
        uint256 wager
    ) internal pure returns (uint256) {
        uint256 difficultyFactor = numPoints * numMines;
        return wager * difficultyFactor; // Adjust the payout logic as needed
    }

    function _transferWager(uint256 wager, address msgSender) internal {
        require(wager >= 1, "Wager must be at least 1");
        IERC20(betTokenAddress).safeTransferFrom(
            msgSender,
            address(this),
            wager
        );
    }

    function _transferPayout(
        address player,
        uint256 payout,
        address tokenAddress
    ) internal {
        IERC20(tokenAddress).safeTransfer(player, payout);
    }
}