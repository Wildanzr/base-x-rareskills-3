// SPDX-License-Identifier: MIT
// THIS CODE IS FOR LEARNING PURPOSES AND DEMONSTRATES THE BASIC FUNCTIONALITY OF AN ERC721 CONTRACT
// FOR THE SAKE OF SIMPLICITY, ATOMIC SWAP, WITHDRAW, MINT IS IMPLEMENTED IN THE SAME CONTRACT

pragma solidity >=0.8.25 <0.9.0;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BXRNFT is ERC721, AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public nftCount = 0;
    uint256 public MIN_MINT_FEES = 1_000_000; // 1 USDC
    IERC20 public usdc;

    mapping(uint256 nftId => uint256 price) public nftPrices;

    constructor(address _usdc) ERC721("BaseXRareSkills", "BXR") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        usdc = IERC20(_usdc);
    }

    error InsufficientBalance(uint256 available, uint256 required);
    error InsufficientAllowance(uint256 available, uint256 required);
    error AccountError(string message);

    event Minted(address indexed to, uint256 tokenId, uint256 fees);
    event SetMinMintFees(uint256 minMintFees);
    event WithdrawFees(address indexed to, uint256 amount);
    event ListedNFT(uint256 indexed nftId, uint256 price);
    event UnlistedNFT(uint256 indexed nftId);
    event BoughtNFT(address indexed buyer, uint256 indexed nftId, uint256 price);

    function publicMint(uint256 _feeAmount) external {
        if (_feeAmount < MIN_MINT_FEES) {
            revert AccountError("Fee amount is less than minimum mint fees");
        }
        uint256 allowance = usdc.allowance(msg.sender, address(this));
        if (allowance < _feeAmount) {
            revert InsufficientAllowance(allowance, _feeAmount);
        }
        usdc.safeTransferFrom(msg.sender, address(this), _feeAmount);
        nftCount++;
        _safeMint(msg.sender, nftCount);

        emit Minted(msg.sender, nftCount, _feeAmount);
    }

    function mint(address _to) external onlyRole(MINTER_ROLE) {
        nftCount++;
        _safeMint(_to, nftCount);

        emit Minted(_to, nftCount, 0);
    }

    function setMinMintFees(uint256 _minMintFees) external onlyRole(DEFAULT_ADMIN_ROLE) {
        MIN_MINT_FEES = _minMintFees;

        emit SetMinMintFees(_minMintFees);
    }

    function withdrawFees(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = usdc.balanceOf(address(this));
        if (balance < _amount) {
            revert InsufficientBalance(balance, _amount);
        }
        usdc.safeTransfer(msg.sender, _amount);

        emit WithdrawFees(msg.sender, _amount);
    }

    function listNFT(uint256 _nftId, uint256 _price) external {
        if (msg.sender != ownerOf(_nftId)) {
            revert AccountError("You are not the owner of this NFT");
        }
        address operator = IERC721(address(this)).getApproved(_nftId);
        if (operator != address(this)) {
            revert AccountError("Operator is not approved to manage this NFT");
        }
        nftPrices[_nftId] = _price;

        emit ListedNFT(_nftId, _price);
    }

    function unlistNFT(uint256 _nftId) external {
        if (msg.sender != ownerOf(_nftId)) {
            revert AccountError("You are not the owner of this NFT");
        }
        address operator = IERC721(address(this)).getApproved(_nftId);
        if (operator != address(this)) {
            revert AccountError("Operator is not approved to manage this NFT");
        }
        nftPrices[_nftId] = 0;

        emit UnlistedNFT(_nftId);
    }

    function buyNFT(uint256 _nftId, uint256 _maxPrice) external {
        uint256 price = nftPrices[_nftId];
        if (price == 0) {
            revert AccountError("NFT is not listed for sale");
        }
        if (price > _maxPrice) {
            revert AccountError("Price exceeds max price");
        }
        uint256 allowance = usdc.allowance(msg.sender, address(this));
        if (allowance < price) {
            revert InsufficientAllowance(allowance, price);
        }

        nftPrices[_nftId] = 0;
        address owner = ownerOf(_nftId);
        usdc.safeTransferFrom(msg.sender, owner, price);
        IERC721(address(this)).safeTransferFrom(owner, msg.sender, _nftId);

        emit BoughtNFT(msg.sender, _nftId, price);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
