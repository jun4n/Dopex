// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// Contracts
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

interface ILegacyPriceOracle {
    function updatePrice(uint256 price) external returns (uint256);

    function transferOwnership(address newOwner) external;
}

contract RdpxPriceOracle is AccessControl {
    /*==== PUBLIC VARS ====*/

    /// @dev Keeper Role
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

    /// @dev Last price of rDPX in USD
    uint256 public lastPrice;

    /// @dev Block timestamp of when last the price of rDPX (in USD) was updated
    uint256 public lastUpdated;

    /// @dev Heartbeat of the updates. If heartbeat is not fulfilled then price getter fucntion should revert
    uint256 public heartbeat = 60 minutes;

    struct PriceObj {
        /// @dev rDPX Price in USD
        uint256 price;
        /// @dev Block timestamp of when price was update
        uint256 updatedAt;
    }

    /// @dev Price Updates
    mapping(uint256 => PriceObj) public priceUpdates;

    /// @dev Length of Price Updates
    uint256 public priceUpdatesLength;

    /*==== EVENTS ====*/

    /// @notice Emitted on a price update
    /// @param price rDPX Price in USD
    /// @param updatedAt Block timestamp of when price was update
    event PriceUpdate(uint256 price, uint256 updatedAt);

    /// @notice Emitted on setting of heartbeat
    /// @param heartbeat Heartbeat
    event SetHeartbeat(uint256 heartbeat);

    /*==== ERRORS ====*/

    /// @notice Emitted if the heartbeat of the price is not met
    error HeartbeatNotFulfilled();

    /*==== CONSTRUCTOR ====*/

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /*==== ADMIN FUNCTIONS ====*/

    /// @dev Set the heartbeat of the oracles
    /// @param _heartbeat Heartbeat of the oracle
    function setHeartbeat(
        uint256 _heartbeat
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        heartbeat = _heartbeat;

        emit SetHeartbeat(_heartbeat);
    }

    /// @dev Transfers the ownership of the legacy oracle to a newOwner
    /// @param _newOwner newOwner address
    function transferLegacyOracleOwnership(
        address _newOwner
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ILegacyPriceOracle(0xC0cdD1176aA1624b89B7476142b41C04414afaa0)
            .transferOwnership(_newOwner);
    }

    /*==== KEEPER FUNCTIONS ====*/

    /// @notice Updates the last price of the token
    /// @param _price price
    /// @return priceUpdatesLength length of the priceUpdates
    function updatePrice(
        uint256 _price
    ) external onlyRole(KEEPER_ROLE) returns (uint256) {
        // Update in legacy contract
        ILegacyPriceOracle(0xC0cdD1176aA1624b89B7476142b41C04414afaa0)
            .updatePrice(_price);

        uint256 blockTimestamp = block.timestamp;

        priceUpdates[priceUpdatesLength] = PriceObj({
            price: _price,
            updatedAt: blockTimestamp
        });

        priceUpdatesLength += 1;

        lastPrice = _price;

        lastUpdated = blockTimestamp;

        emit PriceUpdate(_price, blockTimestamp);

        return priceUpdatesLength;
    }

    /*==== VIEWS ====*/

    /// @notice Gets the price rDPX in USD
    /// @return price
    function getPriceInUSD() external view returns (uint256) {
        require(lastPrice != 0, "Last price == 0");

        if (block.timestamp > lastUpdated + heartbeat) {
            revert HeartbeatNotFulfilled();
        }

        return lastPrice;
    }

    /// @notice Gets the price updates from a start index to an end index
    /// @param _startIndex starting index
    /// @param _endIndex ending index
    /// @return result priceUpdates
    function getPriceUpdates(
        uint256 _startIndex,
        uint256 _endIndex
    ) external view returns (PriceObj[] memory result) {
        result = new PriceObj[](_endIndex - _startIndex);

        for (uint256 i; i < _endIndex; ) {
            result[i] = priceUpdates[_startIndex + i];

            unchecked {
                ++i;
            }
        }
    }
}