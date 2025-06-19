// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "../mocks/marqToken.sol";

contract BeProductive {
    struct ProgressTracker {
        uint256 saved;
        uint256 target;
    }

    MarqToken token;
    mapping(address => ProgressTracker) public goalTracker;
    // Note - seems like this is used to check if a user has set a goal already
    mapping(address => bool) public isMotivated;

    constructor(address _token) {
        // Note - Seems like this token contract can be safely ignored
        token = MarqToken(_token);
    }

    // start saving by creating a goal for yourself
    // your funds will be locked until you reach your savings goal
    function createGoal(uint256 _startAmount, uint256 _goal) external {
        require(!isMotivated[msg.sender], "Dont quit on your previous dream");
        require(_goal > 50 ether, "shoot for the stars");
        // @answered - why is the error for this "no free money". A: Its so people dont make super small goals just to get the reward money
        require(_startAmount < _goal - 20 ether, "no free money");
        // Note - This is transfering MarqToken
        token.transferFrom(msg.sender, address(this), _startAmount);
        // @here
        goalTracker[msg.sender] = ProgressTracker(_startAmount, _goal);
        isMotivated[msg.sender] = true;
    }

    // once you saved enough to reach your goal, you can call me to recieve your funds + rewards for saving
    function completeGoal() external {
        ProgressTracker memory tracker = goalTracker[msg.sender];
        require(tracker.target <= tracker.saved);
        require(isMotivated[msg.sender], "Set a goal first");

        // @here
        goalTracker[msg.sender] = ProgressTracker(0, 0);
        isMotivated[msg.sender] = false;

        // @answered - does this get minted to the contract? A: yes
        token.mint(100 ether);
        // Last step
        token.transfer(msg.sender, tracker.saved + 100 ether);
    }

    // add funds to your goal
    function save(uint256 _amount) external {
        // @audit-issue - did they already reach their goal?
        require(isMotivated[msg.sender], "Set a goal first");
        // @audit-ok - does this fail siliently? A: it reverts
        token.transferFrom(msg.sender, address(this), _amount);
        ProgressTracker memory tracker = goalTracker[msg.sender];
        // @here
        tracker.saved += _amount;
        goalTracker[msg.sender] = tracker;
    }

    // allows user to see how far they are from their goal.
    // Additionally, adds 0.1 ether to their account for caring about their goal
    // NOTE - Do not just repeatedly call `plan` until you have enough tokens. Realistically, you will waste way more in gas costs than you would end up stealing.
    // @answered - Why does this function take an amount as an input. A: It is because it allows the user to plan ahead and see how much they will save by calling `plan`
    function plan(uint256 _amount) external returns (int256) {
        require(isMotivated[msg.sender], "Set a goal first");
        ProgressTracker memory currTracker = goalTracker[msg.sender];
        /* 
            @answered - Why is the envisionedTracker needed here? seems like you could just use the current tracker : A envisionedTracker is used because we sum _amount with it but not with the current tracker
         */
        ProgressTracker memory envisionedTracker = currTracker;

        // mint .1 token for user as a reward for planning ahead
        // @answered - does this get minted to the contract? A: yes
        token.mint(0.1 ether);
        // @here
        currTracker.saved += 0.1 ether;

        envisionedTracker.saved += _amount;

        goalTracker[msg.sender] = currTracker;

        // @audit-issue - What if the target saved amount is greater than the target
        return int256(envisionedTracker.target) - int256(envisionedTracker.saved);
    }
}
