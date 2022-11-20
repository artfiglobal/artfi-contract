// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "erc721a/contracts/ERC721A.sol";

contract ArtfiNFT is Ownable, ERC721A {
    mapping(uint => NftMeta) public nftMeta;
    struct NftMeta {
        uint fraction;
        uint parentId;
    }

    bool public mintPaused;

    address public whitelist;

    string private _baseTokenURI;

    event MintPaused(bool);

    /**
     * @notice Construct
     */
    constructor() ERC721A("Artfi", "ARTFI") {}

    modifier onlyWhitelist {
        require(msg.sender == whitelist, "Not allowed");
        _;
    }

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
     * @notice Set BaseURI
     * @param baseURI  String of BaseURI
     */
    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    /**
     * @notice View function to get BaseURI
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @notice Mint nft
     * @param to  Address of receiver
     * @param quantity  Amount of NFT to mint
     */
    function mint(address to, uint256 quantity) external onlyWhitelist {
        require(!mintPaused, "Mint is paused");

        _mint(to, quantity);
    }
}
