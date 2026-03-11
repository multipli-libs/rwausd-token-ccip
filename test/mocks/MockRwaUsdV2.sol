// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {BurnMintERC20Upgradeable} from "src/upgradeable/BurnMintERC20Upgradeable.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title RwaUsd
 * @author RwaUsd Team
 * @notice An upgradeable ERC-20 token representing a USD-pegged real-world asset on CCIP-enabled chains
 * @dev Extends BurnMintERC20 with UUPS upgradeability and ERC-7201 namespaced storage.
 *
 * The contract inherits mint, burn, and CCIP admin functionality from BurnMintERC20, and layers
 * on two compliance primitives: a global transfer pause and a per-address blocklist. Both are
 * enforced in _beforeTokenTransfer, covering all transfers, mints, and burns.
 *
 * Storage follows the ERC-7201 namespaced pattern to prevent layout collisions with inherited
 * contracts across upgrades. Upgrade authority is gated by DEFAULT_ADMIN_ROLE via the UUPS pattern.
 *
 * @custom:security-contact security@multipli.com
 */

/// @custom:oz-upgrades-from src/token/RwaUsd.sol:RwaUsd
contract MockRwaUsdV2 is BurnMintERC20Upgradeable, UUPSUpgradeable {
    // ================================================================
    // │                     ERC-7201 Storage                         │
    // ================================================================

    struct RwaUsdStorage {
        bool transfersPaused;
        mapping(address => bool) blocklist;
    }

    /// @dev Slot: keccak256(abi.encode(uint256(keccak256("rwausd.storage.RwaUsdStorage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant RWA_USD_STORAGE_SLOT = 0x9264fe7f4f92e40390c360fa31a80a7837e11c0e8ccd79757fc49cde8d3aff00;

    // ================================================================
    // │                       Events & Errors                        │
    // ================================================================

    event TransfersPaused(address indexed by);
    event TransfersUnpaused(address indexed by);
    event AddressBlocklisted(address indexed account, address indexed by);
    event AddressUnblocklisted(address indexed account, address indexed by);

    error TransfersArePaused();
    error AddressIsBlocklisted(address account);

    // ================================================================
    // │                     Constructor & Init                       │
    // ================================================================

    /**
     * @notice Deploys the implementation contract and locks it against initialization
     * @dev Passes dummy values to BurnMintERC20; real state is set in initialize()
     * @custom:security _disableInitializers prevents direct initialization of the implementation
     */
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
        s_ccipAdmin = admin_;
    }

    // ================================================================
    // │                    Pause & Blocklist                         │
    // ================================================================

    /**
     * @notice Returns whether token transfers are currently paused
     * @return True if transfers are paused, false otherwise
     */
    function transfersPaused() external view returns (bool) {
        return _getRwaUsdStorage().transfersPaused;
    }

    /**
     * @notice Pauses all token transfers
     * @dev Affects transfers, mints, and burns via _beforeTokenTransfer
     * @custom:security Restricted to DEFAULT_ADMIN_ROLE
     */
    function pauseTransfers() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _getRwaUsdStorage().transfersPaused = true;
        emit TransfersPaused(msg.sender);
    }

    /**
     * @notice Unpauses all token transfers
     * @custom:security Restricted to DEFAULT_ADMIN_ROLE
     */
    function unpauseTransfers() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _getRwaUsdStorage().transfersPaused = false;
        emit TransfersUnpaused(msg.sender);
    }

    /**
     * @notice Returns whether an address is blocklisted
     * @param account The address to check
     * @return True if the address is blocklisted, false otherwise
     */
    function isBlocklisted(address account) external view returns (bool) {
        return _getRwaUsdStorage().blocklist[account];
    }

    /**
     * @notice Adds an address to the blocklist, preventing it from sending or receiving tokens
     * @param account The address to blocklist
     * @custom:security Restricted to DEFAULT_ADMIN_ROLE
     */
    function addToBlocklist(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _getRwaUsdStorage().blocklist[account] = true;
        emit AddressBlocklisted(account, msg.sender);
    }

    /**
     * @notice Removes an address from the blocklist
     * @param account The address to remove
     * @custom:security Restricted to DEFAULT_ADMIN_ROLE
     */
    function removeFromBlocklist(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _getRwaUsdStorage().blocklist[account] = false;
        emit AddressUnblocklisted(account, msg.sender);
    }

    // ================================================================
    // │                     Transfer Hook                            │
    // ================================================================

    /**
     * @notice Enforces pause and blocklist checks before every transfer, mint, and burn
     * @dev address(0) is the mint/burn sentinel and is exempt from blocklist checks
     * @param from The sender address
     * @param to The recipient address
     * @param amount The token amount
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        RwaUsdStorage storage $ = _getRwaUsdStorage();

        if ($.transfersPaused) revert TransfersArePaused();
        if (from != address(0) && $.blocklist[from]) revert AddressIsBlocklisted(from);
        if (to != address(0) && $.blocklist[to]) revert AddressIsBlocklisted(to);

        super._beforeTokenTransfer(from, to, amount);
    }

    // ================================================================
    // │                     UUPS Upgrade Guard                       │
    // ================================================================

    /**
     * @notice Authorizes a contract upgrade (UUPS pattern)
     * @dev Called internally by upgradeTo() and upgradeToAndCall()
     * @param newImplementation The new implementation contract address
     * @custom:security Restricted to DEFAULT_ADMIN_ROLE — prevents unauthorized upgrades
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // ================================================================
    // │                        Internal                              │
    // ================================================================

    /**
     * @notice Returns a storage pointer to the RwaUsdStorage struct
     * @dev Uses ERC-7201 namespaced storage to avoid layout collisions with inherited contracts
     */
    function _getRwaUsdStorage() private pure returns (RwaUsdStorage storage $) {
        assembly {
            $.slot := RWA_USD_STORAGE_SLOT
        }
    }

    //new methods
    uint256 public newVariable;

    function newMethod() public pure returns (string memory) {
        return "new method";
    }

    function setNewVariable(uint256 value) public {
        newVariable = value;
    }
}
