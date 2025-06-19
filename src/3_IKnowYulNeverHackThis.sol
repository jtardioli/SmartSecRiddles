// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* 
- Why would you need a winners array if there is only 1 winner?
    A: The team wins not an individual so we need the array to keep  track of all the winning players on the team

- Whats the difference between external and public functions?
    A: Exteranl functions do not copy the variables to memory because they come from the call data
       This makes them slightly more efficient, but unlick public functions they cannot be used internally
- What if someone tries to join both teams
  A: They will be blocked because of the isPlaying mapping
 */

contract IKnowYulNeverHackThis {
    address[] public redTeam;
    address[] public blueTeam;
    bool locked;
    uint256 constant minAmountOfPlayers = 10;
    /* 
        ?
        Its strange that they would keep track of the total number of players in a variable
        and not just use the length of the arrays. This might be were something goes wrong
     */
    uint256 public playersCount;
    /* 
        ?
        Why do we need a mapping of is Playing, are players in the array
        not automatically playing
        A: This is a more efficient way to check if the player is already playing to avoid duplicates
     */
    mapping(address => bool) public isPlaying;

    enum Team {
        Red,
        Blue
    }

    function joinRedTeam() external payable {
        require(msg.value == 1 ether, "This game ain't free");
        require(!isPlaying[msg.sender], "Start playing already!");

        redTeam.push(msg.sender);

        isPlaying[msg.sender] = true;
        playersCount++;
    }

    function joinBlueTeam() external payable {
        require(msg.value == 1 ether, "This game ain't free");
        require(!isPlaying[msg.sender], "Start playing already!");

        blueTeam.push(msg.sender);

        isPlaying[msg.sender] = true;
        playersCount++;
    }

    /* 
        ?
        Is the winner just woever calls the define winners function first
        A: It seems like it
     */

    function defineWinners(bool _isBlueTeam) external {
        require(locked == false, "This isn't a reentrancey challenge");
        require(playersCount >= minAmountOfPlayers, "Game isn't over yet");

        locked = true;

        address[] memory winners = new address[](1);

        if (_isBlueTeam) {
            for (uint256 j; j < blueTeam.length; ++j) {
                address winner = blueTeam[j];
                assembly {
                    let location := winners

                    let length := mload(winners)

                    let nextMemoryLocation := add(location, mul(length, 0x20))
                    let freeMem := mload(0x40)

                    let newMsize := add(freeMem, 0x20)

                    if iszero(eq(freeMem, nextMemoryLocation)) {
                        let currVal
                        let prevVal

                        for { let i := nextMemoryLocation } lt(i, newMsize) { i := add(i, 0x20) } {
                            currVal := mload(i)
                            mstore(i, prevVal)
                            prevVal := currVal
                        }
                    }

                    mstore(nextMemoryLocation, winner)

                    length := add(length, 1)

                    mstore(location, length)

                    mstore(0x40, newMsize)
                }
            }
        } else {
            for (uint256 j; j < redTeam.length; ++j) {
                address winner = redTeam[j];
                assembly {
                    let location := winners

                    let length := mload(winners)

                    let nextMemoryLocation := add(location, mul(length, 0x20))
                    let freeMem := mload(0x40)

                    let newMsize := add(freeMem, 0x20)

                    if iszero(eq(freeMem, nextMemoryLocation)) {
                        let currVal
                        let prevVal

                        // make room for newVal by shifting other memory variables forward
                        for { let i := nextMemoryLocation } lt(i, newMsize) { i := add(i, 0x20) } {
                            currVal := mload(i)
                            mstore(i, prevVal)
                            prevVal := currVal
                        }
                    }

                    mstore(nextMemoryLocation, winner)

                    length := add(length, 1)

                    // @audit the new array size is not being updated so the length of the array will always be 1
                    mstore(0x40, newMsize)
                }
            }
        }

        uint256 shareOfPrize = address(this).balance / winners.length;

        uint256 i;
        uint256 winnersLength = winners.length;

        /* 
            @audit If red team is the winner, the array length will always be 1, and because the array 
            is expanded be pushing all the other values forward, the last person to join the red team will be
            at the first position in the winners array. meaning they can steal all of the prize money 
        */
        for (i; i < winners.length; ++i) {
            (bool sent, bytes memory data) = winners[i].call{value: shareOfPrize}("");
        }

        locked = false;
    }
}
