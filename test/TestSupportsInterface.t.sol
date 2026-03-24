// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {rwaUSD} from "src/token/RWAUSD.sol";
import {IBurnMintERC20} from "src/interfaces/IBurnMintERC20.sol";
import {IGetCCIPAdmin} from "@chainlink/contracts/src/v0.8/shared/interfaces/IGetCCIPAdmin.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC1822Proxiable} from "@openzeppelin/contracts/interfaces/draft-IERC1822.sol";

import {RwaUsdBaseTest} from "./BaseTest.t.sol";

contract TestSupportsInterface is RwaUsdBaseTest {
    function test_SupportsInterface_IERC20() public view {
        assertTrue(s_rwausd.supportsInterface(type(IERC20).interfaceId));
    }

    function test_SupportsInterface_IBurnMintERC20() public view {
        assertTrue(s_rwausd.supportsInterface(type(IBurnMintERC20).interfaceId));
    }

    function test_SupportsInterface_IERC165() public view {
        assertTrue(s_rwausd.supportsInterface(type(IERC165).interfaceId));
    }

    function test_SupportsInterface_IAccessControl() public view {
        assertTrue(s_rwausd.supportsInterface(type(IAccessControl).interfaceId));
    }

    function test_SupportsInterface_IGetCCIPAdmin() public view {
        assertTrue(s_rwausd.supportsInterface(type(IGetCCIPAdmin).interfaceId));
    }

    function test_SupportsInterface_IERC1822Proxiable() public view {
        assertTrue(s_rwausd.supportsInterface(type(IERC1822Proxiable).interfaceId));
    }
}
