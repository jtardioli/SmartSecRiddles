// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "../mocks/NFT.sol";

// Interactions
// - update min and max price
// - addPriceToHistory
// - getNewAuctionPrice

contract Auction {
    uint256 public minPrice;
    uint256 public maxPrice;
    uint256 public lastPrice;
    uint256 public currPrice;
    uint256 public increment;
    address public oracle;
    bool public inProgress;
    bool public incrementStartPrice;
    address private admin;
    NFT public nft;

    constructor(address _admin, address _nft, uint256 _increment, uint256 startPrice) {
        admin = _admin;
        increment = _increment;
        nft = NFT(_nft);
        currPrice = startPrice;
        inProgress = true;
    }

    // @audit-ok - check for missing admin access
    modifier onlyAdmin() {
        require(msg.sender == admin, "you are not the admin");
        _;
    }

    // updates admin
    function setAdmin(address _admin) external onlyAdmin {
        require(_admin != address(0), "we dont want CodeHawks judges to be spamed with dumb findings");
        admin = _admin;
    }

    // @audit-ok - check for missing oracle access
    // sets oracle
    function setOracle(address _oracle) external onlyAdmin {
        require(_oracle != address(0), "we dont want CodeHawks judges to be spamed with dumb findings");
        oracle = _oracle;
    }

    // @answered - what is the increment for: the increment gets subtracted from the currPrice presumably after each auction epoch
    // changes price increment of auction
    function setIncrement(uint256 _increment) external onlyAdmin {
        increment = _increment;
    }

    // updates price if no one bids
    function setDutchAuctionPrice(uint256 _price) external payable onlyAdmin {
        currPrice -= increment;
    }

    // pulls out ether to treasury
    function pullToTreasury(address _treasury) external onlyAdmin {
        (bool success,) = _treasury.call{value: address(this).balance}("");
    }

    // updates max and min price for an auction
    function updatePriceDifferential(uint256 _minPrice, uint256 _maxPrice) external {
        require(msg.sender == oracle, "Not Oracle");
        minPrice = _minPrice;
        maxPrice = _maxPrice;
    }

    // @question - how does the price get lowered over time
    // allows user to win the auction by bidding.
    function winAuction() external payable {
        require(msg.value >= currPrice, "pay the price");
        require(inProgress, "No Auction");
        // @answered - what is the purpose of this if statement, what does incrementing the start price do
        // If the last price is less than the current price. then when we start the new auctions, we
        // will increase the price by 20%
        if (lastPrice < currPrice) {
            incrementStartPrice = true;
        }
        lastPrice = msg.value;

        nft.mint(msg.sender);
        inProgress = false;
    }

    // starts new auction
    function createNewAuction() external {
        require(!inProgress, "Auction");
        _startNewAuction();
    }

    // helper function to set new price for the auction
    function _startNewAuction() private {
        TrustyOracle(oracle).addPriceToHistory();
        currPrice = TrustyOracle(oracle).getNewAuctionPrice(lastPrice);
        // @audit-issue - I might be able to manipulate this to DoS
        require(currPrice <= maxPrice, "Price Too High");
        require(currPrice >= minPrice, "Price Too Low");
        inProgress = true;
        incrementStartPrice = false;
    }
}

contract TrustyOracle {
    // @answered - what is an epoch: it is the number of blocks that need to elapse before the min and max price are reconfigured
    uint256 constant epochLength = 20;
    address private admin;
    uint256 public previousUpdateBlock;
    uint256[] public previousPrices;
    Auction auction;

    constructor(address _admin, address _auction) {
        admin = _admin;
        auction = Auction(_auction);
        uint256 i;
        // @answered - What is the reason for this? they want to give weight to the first initial price
        // it might be because we need the array to have at least 5 spots or the code below to work
        // Note - this adds 5 items to the array
        while (i < 5) {
            previousPrices.push(auction.currPrice());
            unchecked {
                ++i;
            }
        }
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "no price manipulation allowed");
        _;
    }

    // sets new admin
    function setAdmin(address _admin) external onlyAdmin {
        require(_admin != address(0), "we dont want CodeHawks judges to be spamed with dumb findings");
        admin = _admin;
    }

    // we don't want too large of a price fluctuation based off one bad sale
    // so we need to verify that the price is within a certain range
    function setMaxDifferentialPrice() external onlyAdmin {
        require(previousUpdateBlock + epochLength >= block.number, "read the clock");
        previousUpdateBlock = block.number;

        uint256 averagePrice = _calculatePriceImpact();

        // @answered - is there any significance to these numbers here?
        // Sets min/max price to ±20% of average to limit auction price volatility
        uint256 minPrice = averagePrice * 8000 / 10000;
        uint256 maxPrice = averagePrice * 12000 / 10000;

        auction.updatePriceDifferential(minPrice, maxPrice);
    }

    // adds current price to
    function addPriceToHistory() external {
        require(msg.sender == address(auction));
        uint256 lastPrice = auction.lastPrice();
        previousPrices.push(lastPrice);
    }

    // @audit-ok - should this be callable by anyone at anytime: This is a view function
    // calculate the new auction price based off previous auction sales
    function getNewAuctionPrice(uint256 _lastPrice) external view returns (uint256) {
        uint256 averagePrice = _lastPrice;
        uint256 length = previousPrices.length;
        uint256 i;

        /* 
            @answered wtf is this doing:
            This code sums the last 4 entries in the previous prices array
        */
        // @audit-ok - what if previous prices length is less than 4: its seeded with 5 and you cant remove any
        for (i; i < 4; ++i) {
            averagePrice += previousPrices[length - i - 1];
        }
        if (auction.incrementStartPrice()) {
            averagePrice = averagePrice * 12000 / 10000;
        }
        // @audit-issue - we divide by 5 but we only summed 4
        return averagePrice / 5;
    }

    // get the average sale price from the last 5 auctions
    function _calculatePriceImpact() private view returns (uint256) {
        uint256 averagePrice;
        uint256 length = previousPrices.length;
        uint256 i;
        // @audit-ok - what the previous prices array is too long: Runs 5 times, it starts off with 5 items and theres no code to remove items
        for (i; i < 5; ++i) {
            averagePrice += previousPrices[length - i - 1];
        }
        // @audit-ok - we divide by 5 but loop runs 6 times possibly: the loop runs 5 times and we divid by 5
        return averagePrice / 5;
    }
}
