/* Orchid - WebRTC P2P VPN Market (on Ethereum)
 * Copyright (C) 2017-2019  The Orchid Authors
*/

/* GNU Affero General Public License, Version 3 {{{ */
/*
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.

 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
**/
/* }}} */


pragma solidity ^0.5.7;

import "../openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

interface IOrchidLottery {
}

contract OrchidLottery is IOrchidLottery {

    ERC20 private orchid_;

    constructor(address orchid) public {
        orchid_ = ERC20(orchid);
    }


    struct Pot {
        uint64 amount_;
        uint64 escrow_;
        uint256 unlock_;
    }

    mapping(address => Pot) pots_;

    event Update(address signer);

    // signer must be a simple account, to support signing tickets
    function fund(address signer, uint64 amount, uint64 total) public {
        require(total >= amount);
        Pot storage pot = pots_[signer];
        pot.amount_ += amount;
        pot.escrow_ += total - amount;
        emit Update(signer);
        require(orchid_.transferFrom(msg.sender, address(this), total));
    }


    mapping(bytes32 => bool) tickets_;

    function claim(uint256 secret, bytes32 hash, address payable target, uint256 nonce, uint256 ratio, uint64 amount, uint8 v, bytes32 r, bytes32 s) public {
        require(keccak256(abi.encodePacked(secret)) == hash);
        require(uint256(keccak256(abi.encodePacked(secret, nonce))) < ratio);

        bytes32 ticket = keccak256(abi.encodePacked(hash, target, nonce, ratio, amount));
        require(!tickets_[ticket]);
        tickets_[ticket] = true;

        address signer = ecrecover(ticket, v, r, s);
        Pot storage pot = pots_[signer];

        if (pot.amount_ < amount) {
            amount = pot.amount_;
            pot.escrow_ = 0;
        }

        pot.amount_ -= amount;
        emit Update(signer);
        require(orchid_.transfer(target, amount));
    }


    function unlock() public {
        Pot storage pot = pots_[msg.sender];
        pot.unlock_ = block.timestamp + 1 days;
        emit Update(msg.sender);
    }

    function take(address payable target) public {
        Pot storage pot = pots_[msg.sender];
        require(pot.unlock_ <= block.timestamp);
        uint64 amount = pot.amount_ + pot.escrow_;
        delete pots_[msg.sender];
        emit Update(msg.sender);
        require(orchid_.transfer(target, amount));
    }

}