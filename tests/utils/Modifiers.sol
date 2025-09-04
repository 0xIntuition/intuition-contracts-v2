// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { Users, Protocol } from "tests/utils/Types.sol";
import { Utils } from "tests/utils/Utils.sol";

abstract contract Modifiers is Utils {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Users internal users;
    Protocol internal protocol;

    function setVariables(Users memory _users, Protocol memory _protocol) public {
        users = _users;
        protocol = _protocol;
    }

    modifier onlyAdmin() {
        require(msg.sender == users.admin, "Not admin");
        _;
    }

    modifier onlyController() {
        require(msg.sender == users.controller, "Not controller");
        _;
    }

    modifier onlyUser() {
        require(msg.sender == users.alice || msg.sender == users.bob || msg.sender == users.charlie, "Not a user");
        _;
    }
}
