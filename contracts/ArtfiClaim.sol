// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./ArtfiNFT.sol";
import "./abstract/EIP712.sol";

contract ArtfiClaim is Ownable, EIP712 {
    using SafeERC20 for IERC20;

    ArtfiNFT public immutable artfiNFT;

    mapping(address => uint) public userClaim;

    bool public claimEnabled;

    uint public claimCnt;
    address private signatureAddr;
    address public claimToken;

    event Claim(address indexed, uint, uint);

    /**
     * @notice Construct
     * @param _artfi  address of ArtfiNFT
     * @param _signatureAddr address of signature
     * @param _claimToken  Address of token
     */
    constructor(
        address _artfi, 
        address _signatureAddr,
        address _claimToken
    ) EIP712("ARTFIClaim", "1.0.0") {
        artfiNFT = ArtfiNFT(_artfi);
        signatureAddr = _signatureAddr;
        claimToken = _claimToken;
    }

    /**
     * @notice Set signature
     * @param _signatureAddr  address of signature
     */
    function setSignatureAddr(address _signatureAddr) external onlyOwner {
        signatureAddr = _signatureAddr;
    }

    /**
     * @notice Set new claim
     */
    function setClaim() external onlyOwner {
        claimCnt++;
    }

    /**
     * @notice Set claim token
     * @param _claimToken address of claim token
     * 
     */
    function setClaimToken(address _claimToken) external onlyOwner {
        claimToken = _claimToken;
    }

    /**
     * @notice Update claim enable
     * @param _flag bool for claim
     * 
     */
    function setClaimToken(bool _flag) external onlyOwner {
        claimEnabled = _flag;
    }

    /**
     * @notice Verify the signature
     * @param _user  Address of token
     * @param _amount  total price
     * @param _signature  bytes signature
     */
    function _verify(
        address _user,
        uint256 _amount,
        bytes calldata _signature
    ) private view returns (bool) {
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
            keccak256("Claim(address walletAddress,uint256 amount)"),
            _user,
            _amount
        )));

        return ECDSA.recover(digest, _signature) == signatureAddr;
    }

    /**
     * @notice Function to claim the reward
     * @param amount  claim amount
     * @param signature  verify signature
     */
    function claim(
        uint amount, 
        bytes calldata signature
    ) external {
        require(claimEnabled, "Claim paused");
        require(userClaim[msg.sender] < claimCnt, "Claimed already");
        require(_verify(msg.sender, amount, signature), "Invalid signature");

        IERC20(claimToken).safeTransfer(msg.sender, amount);
        userClaim[msg.sender]++;

        emit Claim(msg.sender, amount, block.timestamp);
    }
}