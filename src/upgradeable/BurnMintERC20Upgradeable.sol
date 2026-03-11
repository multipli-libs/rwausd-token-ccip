// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import {IGetCCIPAdmin} from "@chainlink/contracts/src/v0.8/shared/interfaces/IGetCCIPAdmin.sol";
import {IBurnMintERC20} from "../interfaces/IBurnMintERC20.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {
    ERC20BurnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

/// @notice Upgradeable version of BurnMintERC20.
contract BurnMintERC20Upgradeable is
    IBurnMintERC20,
    IGetCCIPAdmin,
    IERC165,
    ERC20BurnableUpgradeable,
    AccessControlUpgradeable
{
    error MaxSupplyExceeded(uint256 supplyAfterMint);
    error InvalidRecipient(address recipient);

    event CCIPAdminTransferred(address indexed previousAdmin, address indexed newAdmin);

    // No longer immutable — moved to ERC-7201 storage in RwaUsd
    // but kept here as internal state for base contract use
    uint8 private s_decimals;
    uint256 private s_maxSupply;
    address internal s_ccipAdmin;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /// @dev Replaces the constructor for upgradeable context
    function __BurnMintERC20_init(
        string memory name,
        string memory symbol,
        uint8 decimals_,
        uint256 maxSupply_,
        uint256 preMint,
        address admin_
    ) internal onlyInitializing {
        __ERC20_init(name, symbol);
        __ERC20Burnable_init();
        __BurnMintERC20_init_unchained(decimals_, maxSupply_, preMint, admin_);
        __AccessControl_init();
    }

    function __BurnMintERC20_init_unchained(uint8 decimals_, uint256 maxSupply_, uint256 preMint, address admin_)
        internal
        onlyInitializing
    {
        s_decimals = decimals_;
        s_maxSupply = maxSupply_;
        s_ccipAdmin = admin_;

        if (preMint != 0) _mint(admin_, preMint);

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        pure
        virtual
        override(AccessControlUpgradeable, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC20Upgradeable).interfaceId || interfaceId == type(IBurnMintERC20).interfaceId
            || interfaceId == type(IERC165).interfaceId || interfaceId == type(IAccessControl).interfaceId
            || interfaceId == type(IGetCCIPAdmin).interfaceId;
    }

    function decimals() public view virtual override returns (uint8) {
        return s_decimals;
    }

    function maxSupply() public view virtual returns (uint256) {
        return s_maxSupply;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual override {
        if (to == address(this)) revert InvalidRecipient(to);
        super._transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual override {
        if (spender == address(this)) revert InvalidRecipient(spender);
        super._approve(owner, spender, amount);
    }

    function burn(uint256 amount) public override(IBurnMintERC20, ERC20BurnableUpgradeable) onlyRole(BURNER_ROLE) {
        super.burn(amount);
    }

    function burn(address account, uint256 amount) public virtual override {
        burnFrom(account, amount);
    }

    function burnFrom(address account, uint256 amount)
        public
        override(IBurnMintERC20, ERC20BurnableUpgradeable)
        onlyRole(BURNER_ROLE)
    {
        super.burnFrom(account, amount);
    }

    function mint(address account, uint256 amount) external override onlyRole(MINTER_ROLE) {
        if (account == address(this)) revert InvalidRecipient(account);
        if (s_maxSupply != 0 && totalSupply() + amount > s_maxSupply) revert MaxSupplyExceeded(totalSupply() + amount);
        _mint(account, amount);
    }

    function grantMintAndBurnRoles(address burnAndMinter) external {
        grantRole(MINTER_ROLE, burnAndMinter);
        grantRole(BURNER_ROLE, burnAndMinter);
    }

    function getCCIPAdmin() external view returns (address) {
        return s_ccipAdmin;
    }

    function setCCIPAdmin(address newAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        address currentAdmin = s_ccipAdmin;
        s_ccipAdmin = newAdmin;
        emit CCIPAdminTransferred(currentAdmin, newAdmin);
    }
}
