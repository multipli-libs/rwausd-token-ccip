// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {BurnMintERC20Upgradeable} from "../upgradeable/BurnMintERC20Upgradeable.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title RwaUsd
 * @author RwaUsd Team
 * @notice An upgradeable ERC-20 token representing a USD-pegged real-world asset on CCIP-enabled chains
 * @dev Extends BurnMintERC20 with UUPS upgradeability and ERC-7201 namespaced storage.
 *
 * The contract inherits mint, burn, and CCIP admin functionality from BurnMintERC20
 *
 * Storage follows the ERC-7201 namespaced pattern to prevent layout collisions with inherited
 * contracts across upgrades. Upgrade authority is gated by DEFAULT_ADMIN_ROLE via the UUPS pattern.
 *
 * @custom:security-contact security@multipli.com
 */
contract RwaUsd is BurnMintERC20Upgradeable, UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the proxy with an admin address
     * @dev Called exactly once after proxy deployment; replaces the constructor for upgradeable contracts
     * @param admin_ Address granted DEFAULT_ADMIN_ROLE and set as the CCIP admin
     * @custom:security Protected by the initializer modifier — cannot be called again after first invocation
     */
    function initialize(address admin_) public initializer {
        if (admin_ == address(0)) revert InvalidRecipient(address(0));
        __RwaUsd_init(admin_);
    }

    function __RwaUsd_init(address admin_) internal onlyInitializing {
        __BurnMintERC20_init("RWA USD", "rwaUSD", 18, 0, 0, admin_);
        __RwaUsd_init_unchained(admin_);
    }

    /// @custom:oz-upgrades-unsafe-allow missing-initializer-call
    function __RwaUsd_init_unchained(address admin_) internal onlyInitializing {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        if (msg.sender != admin_) _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Authorizes a contract upgrade (UUPS pattern)
     * @dev Called internally by upgradeTo() and upgradeToAndCall()
     * @param newImplementation The new implementation contract address
     * @custom:security Restricted to DEFAULT_ADMIN_ROLE — prevents unauthorized upgrades
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
