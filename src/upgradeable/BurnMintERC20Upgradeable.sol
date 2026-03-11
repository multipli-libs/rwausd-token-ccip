// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import {IGetCCIPAdmin} from "@chainlink/contracts/src/v0.8/shared/interfaces/IGetCCIPAdmin.sol";
import {IBurnMintERC20} from "../interfaces/IBurnMintERC20.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

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

    // ================================================================
    // │                     ERC-7201 Storage                         │
    // ================================================================

    struct BurnMintERC20Storage {
        uint8 decimals;
        uint256 maxSupply;
        address ccipAdmin;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256("burnminterc20.storage.BurnMintERC20Storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BURN_MINT_ERC20_STORAGE_SLOT =
       0x9d50aa6d2a9beb43604b360b2b318af4a5163378f001e45a83887b785af66300;

    function _getBurnMintStorage() private pure returns (BurnMintERC20Storage storage $) {
        assembly {
            $.slot := BURN_MINT_ERC20_STORAGE_SLOT
        }
    }

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

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
        __AccessControl_init();
        __BurnMintERC20_init_unchained(decimals_, maxSupply_, preMint, admin_);
    }

    function __BurnMintERC20_init_unchained(uint8 decimals_, uint256 maxSupply_, uint256 preMint, address admin_)
        internal
        onlyInitializing
    {
        BurnMintERC20Storage storage $ = _getBurnMintStorage();
        $.decimals = decimals_;
        $.maxSupply = maxSupply_;
        $.ccipAdmin = admin_;

        if (preMint != 0) _mint(admin_, preMint);
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        pure
        virtual
        override(AccessControlUpgradeable, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC20).interfaceId || interfaceId == type(IBurnMintERC20).interfaceId
            || interfaceId == type(IERC165).interfaceId || interfaceId == type(IAccessControl).interfaceId
            || interfaceId == type(IGetCCIPAdmin).interfaceId;
    }

    function decimals() public view virtual override returns (uint8) {
        return _getBurnMintStorage().decimals;
    }

    function maxSupply() public view virtual returns (uint256) {
        return _getBurnMintStorage().maxSupply;
    }

    function _update(address from, address to, uint256 value) internal virtual override {
        if (to == address(this)) revert InvalidRecipient(to);
        super._update(from, to, value);
    }

    function _approve(address owner, address spender, uint256 amount, bool emitEvent) internal virtual override {
        if (spender == address(this)) revert InvalidRecipient(spender);
        super._approve(owner, spender, amount, emitEvent);
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
        BurnMintERC20Storage storage $ = _getBurnMintStorage();
        if (account == address(this)) revert InvalidRecipient(account);
        if ($.maxSupply != 0 && totalSupply() + amount > $.maxSupply) revert MaxSupplyExceeded(totalSupply() + amount);
        _mint(account, amount);
    }

    function grantMintAndBurnRoles(address burnAndMinter) external {
        grantRole(MINTER_ROLE, burnAndMinter);
        grantRole(BURNER_ROLE, burnAndMinter);
    }

    function getCCIPAdmin() external view returns (address) {
        return _getBurnMintStorage().ccipAdmin;
    }

    function setCCIPAdmin(address newAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        BurnMintERC20Storage storage $ = _getBurnMintStorage();
        address currentAdmin = $.ccipAdmin;
        $.ccipAdmin = newAdmin;
        emit CCIPAdminTransferred(currentAdmin, newAdmin);
    }
}