// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.7.0;

contract DAO {
    event memberAdded(address newMember);

    address creator;
    mapping(address => bool) private members;

    constructor() {
        creator = msg.sender;
    }

    function add_member(address newMember) {
        members[newMember] = true;
        memberAdded(newMember);
    }

    modifier onlyMembers() {
        require(members[msg.sender] == true, "Transaction origin is not a member");
        _;
    }
}