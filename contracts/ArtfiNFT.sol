// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "erc721a/contracts/ERC721A.sol";

contract ArtfiNFT is Ownable, ERC721A {
    bool public mintPaused;
    address public whitelist;

    event MintPaused(bool);

    /**
     * @notice Constructor
     */
    constructor() ERC721A("Artfi", "ARTFI") {}

    /**
     * @notice Set whitelist
     * @param _whitelist  Address of whitelist
     */
    function setWhitelist(address _whitelist) external onlyOwner {
        whitelist = _whitelist;
    }

    /**
     * @notice Pause minting
     * @param _paused  Bool flag
     */
    function pauseMint(bool _paused) external onlyOwner {
        require(!mintPaused, "Contract paused");
        mintPaused = _paused;
        emit MintPaused(_paused);
    }

    /**
     * @notice Mint nft
     * @param to  Address of receiver
     * @param quantity  Amount of NFT to mint
     */
    function mint(address to, uint256 quantity) external returns(uint _tokenId) {
        require(msg.sender == whitelist, "Not allowed");
        require(!mintPaused, "Mint is paused");

        _tokenId = _nextTokenId();
        _mint(to, quantity);
    }
}
