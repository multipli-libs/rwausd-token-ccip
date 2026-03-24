// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IGetCCIPAdmin} from "@chainlink/contracts/src/v0.8/shared/interfaces/IGetCCIPAdmin.sol";
import {IBurnMintERC20} from "../interfaces/IBurnMintERC20.sol";

import {
    AccessControlDefaultAdminRulesUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {
    ERC20BurnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1822Proxiable} from "@openzeppelin/contracts/interfaces/draft-IERC1822.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract rwaUSD is
    Initializable,
    UUPSUpgradeable,
    IBurnMintERC20,
    IGetCCIPAdmin,
    PausableUpgradeable,
    IERC165,
    ERC20BurnableUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable
{
    error RwaUsd__MaxSupplyExceeded(uint256 supplyAfterMint);
    error RwaUsd__InvalidRecipient(address recipient);

    event CCIPAdminTransferred(address indexed previousAdmin, address indexed newAdmin);

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // ================================================================
    // │                         Storage                              │
    // ================================================================

    /// @custom:storage-location multipli.storage.rwaUSD
    struct RwaUsdStorage {
        /// @dev the CCIPAdmin can be used to register with the CCIP token admin registry, but has no other special powers,
        /// and can only be transferred by the owner.
        address ccipAdmin;
        /// @dev The number of decimals for the token
        uint8 decimals;
        /// @dev The maximum supply of the token, 0 if unlimited
        uint256 maxSupply;
    }

    // keccak256(abi.encode(uint256(keccak256("multipli.storage.rwaUSD")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant RWAUSD_STORAGE_LOCATION =
        0xc1a8840385e35995fb7aabd6059552ccaa64bb804485e90cb444ac534e5ef600;

    // solhint-disable-next-line chainlink-solidity/explicit-returns
    function _getRwaUsdStorage() private pure returns (RwaUsdStorage storage $) {
        assembly {
            $.slot := RWAUSD_STORAGE_LOCATION
        }
    }

    // ================================================================
    // │                            UUPS                              │
    // ================================================================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev the underscores in parameter names are used to suppress compiler warnings about shadowing ERC20 functions
    function initialize(
        string memory name,
        string memory symbol,
        uint8 decimals_,
        uint256 maxSupply_,
        uint256 preMint,
        address defaultAdmin,
        address defaultUpgrader
    ) public initializer {
        __RwaUsd_init(name, symbol, decimals_, maxSupply_, preMint, defaultAdmin, defaultUpgrader);
    }

    function __RwaUsd_init(
        string memory name,
        string memory symbol,
        uint8 decimals_,
        uint256 maxSupply_,
        uint256 preMint,
        address defaultAdmin,
        address defaultUpgrader
    ) internal onlyInitializing {
        require(defaultAdmin != address(0), "Admin address is 0");
        require(defaultUpgrader != address(0), "Upgrader address is 0");

        __ERC20_init(name, symbol);
        __ERC20Burnable_init();
        __AccessControl_init();
        __AccessControlDefaultAdminRules_init(1 hours, defaultAdmin);
        __RwaUsd_init_unchained(decimals_, maxSupply_, preMint, defaultAdmin, defaultUpgrader);
    }

    /// @custom:oz-upgrades-unsafe-allow missing-initializer-call
    // reference: https://forum.openzeppelin.com/t/potential-false-positive-missing-initializer-calls-for-one-or-more-parent-contracts/43911/3
    function __RwaUsd_init_unchained(
        uint8 decimals_,
        uint256 maxSupply_,
        uint256 preMint,
        address defaultAdmin,
        address defaultUpgrader
    ) internal onlyInitializing {
        RwaUsdStorage storage $ = _getRwaUsdStorage();

        $.decimals = decimals_;
        $.maxSupply = maxSupply_;

        $.ccipAdmin = defaultAdmin;

        if (preMint != 0) {
            if (maxSupply_ != 0 && preMint > maxSupply_) {
                revert RwaUsd__MaxSupplyExceeded(preMint);
            }
            _mint(defaultAdmin, preMint);
        }

        _grantRole(UPGRADER_ROLE, defaultUpgrader);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    // ================================================================
    // │                           ERC165                             │
    // ================================================================

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        pure
        virtual
        override(AccessControlDefaultAdminRulesUpgradeable, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC20).interfaceId || interfaceId == type(IBurnMintERC20).interfaceId
            || interfaceId == type(IERC165).interfaceId || interfaceId == type(IAccessControl).interfaceId
            || interfaceId == type(IERC1822Proxiable).interfaceId || interfaceId == type(IGetCCIPAdmin).interfaceId;
    }

    // ================================================================
    // │                            ERC20                             │
    // ================================================================

    /// @dev Returns the number of decimals used in its user representation.
    function decimals() public view virtual override returns (uint8) {
        return _getRwaUsdStorage().decimals;
    }

    /// @dev Returns the max supply of the token, 0 if unlimited.
    function maxSupply() public view virtual returns (uint256) {
        return _getRwaUsdStorage().maxSupply;
    }

    // ================================================================
    // │                      Burning & minting                       │
    // ================================================================

    /// @inheritdoc ERC20BurnableUpgradeable
    /// @dev Uses OZ ERC20Upgradeable _burn to disallow burning from address(0).
    /// @dev Decreases the total supply.
    function burn(uint256 amount) public override(IBurnMintERC20, ERC20BurnableUpgradeable) onlyRole(BURNER_ROLE) {
        super.burn(amount);
    }

    /// @inheritdoc IBurnMintERC20
    /// @dev Alias for BurnFrom for compatibility with the older naming convention.
    /// @dev Uses burnFrom for all validation & logic.
    function burn(address account, uint256 amount) public virtual override {
        burnFrom(account, amount);
    }

    /// @inheritdoc ERC20BurnableUpgradeable
    /// @dev Uses OZ ERC20Upgradeable _burn to disallow burning from address(0).
    /// @dev Decreases the total supply.
    function burnFrom(address account, uint256 amount)
        public
        override(IBurnMintERC20, ERC20BurnableUpgradeable)
        onlyRole(BURNER_ROLE)
    {
        super.burnFrom(account, amount);
    }

    /// @inheritdoc IBurnMintERC20
    /// @dev Uses OZ ERC20Upgradeable _mint to disallow minting to address(0).
    /// @dev Disallows minting to address(this) via _beforeTokenTransfer hook.
    /// @dev Increases the total supply.
    function mint(address account, uint256 amount) external override onlyRole(MINTER_ROLE) {
        uint256 _maxSupply = _getRwaUsdStorage().maxSupply;
        uint256 _totalSupply = totalSupply();

        if (_maxSupply != 0 && _totalSupply + amount > _maxSupply) {
            revert RwaUsd__MaxSupplyExceeded(_totalSupply + amount);
        }

        _mint(account, amount);
    }

    // ================================================================
    // │                            Roles                             │
    // ================================================================

    /// @notice grants both mint and burn roles to `burnAndMinter`.
    /// @dev calls public functions so this function does not require
    /// access controls. This is handled in the inner functions.
    function grantMintAndBurnRoles(address burnAndMinter) external {
        grantRole(MINTER_ROLE, burnAndMinter);
        grantRole(BURNER_ROLE, burnAndMinter);
    }

    /// @notice Returns the current CCIPAdmin
    function getCCIPAdmin() external view returns (address) {
        return _getRwaUsdStorage().ccipAdmin;
    }

    /// @notice Transfers the CCIPAdmin role to a new address
    /// @dev only the owner can call this function, NOT the current ccipAdmin, and 1-step ownership transfer is used.
    /// @param newAdmin The address to transfer the CCIPAdmin role to. Setting to address(0) is a valid way to revoke
    /// the role
    function setCCIPAdmin(address newAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        RwaUsdStorage storage $ = _getRwaUsdStorage();
        address currentAdmin = $.ccipAdmin;

        $.ccipAdmin = newAdmin;

        emit CCIPAdminTransferred(currentAdmin, newAdmin);
    }

    // ================================================================
    // │                          Pausing                             │
    // ================================================================

    /// @notice Pauses the implementation.
    /// @dev Requires the caller to have the PAUSER_ROLE.
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();

        emit Paused(msg.sender);
    }

    /// @notice Unpauses the implementation.
    /// @dev Requires the caller to have the DEFAULT_ADMIN_ROLE.
    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();

        emit Unpaused(msg.sender);
    }

    // ================================================================
    // │                            ERC20                             │
    // ================================================================

    /// @dev Disallows sending, minting and burning if implementation is paused.
    function _update(address from, address to, uint256 value) internal virtual override {
        _requireNotPaused();
        if (to == address(this)) revert RwaUsd__InvalidRecipient(to);
        super._update(from, to, value);
    }

    /// @dev Disallows approving if implementation is paused.
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual override {
        _requireNotPaused();
        if (spender == address(this)) revert RwaUsd__InvalidRecipient(spender);

        super._approve(owner, spender, value, emitEvent);
    }
}
