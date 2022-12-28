// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./ArtfiNFT.sol";

import "./abstract/EIP712.sol";
import "./library/Strings.sol";

contract ArtfiWhitelist is Ownable, EIP712, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Strings for string;

    mapping(uint => NftMeta) public nftMeta;
    mapping(address => bool) public payToken;
    mapping(bytes32 => Whitelist) public whitelist;
    // user_address => whitelistID => userinfo
    mapping(address => mapping(bytes32 => UserInfo)) public userInfo;
    
    struct NftMeta {
        uint fraction;
        address owner;
        bytes32 whitelist;
    }

    struct Whitelist {
        uint startTime;
        uint lockTime;
        uint maxFraction;
        uint totalFraction;
    }

    struct UserInfo {
        uint amount;
        uint price;
        address token;
        Stat stat;
    }

    enum Stat {
        Deposit,
        Claim,
        Mint,
        Redeposit
    }

    ArtfiNFT public immutable artfiNFT;

    uint public taxPercent;

    address public treasury;
    address public constant wmatic = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

    address private whitelister;

    event AddWhitelist(Whitelist whitelist);
    event Mint(address indexed user, bytes32 whitelist);
    event Claim(address indexed user, bytes32 whitelist);
    event Deposit(address indexed user, bytes32 whitelist, uint amount, address indexed token);
    event Redeposit(address indexed user, bytes32 whitelist, uint amount, address indexed token);

    /**
     * @notice Construct
     * @param _artfi  address of ArtfiNFT
     * @param _whitelister  address of whitelister
     */
    constructor(address _artfi, address _whitelister) EIP712("ARTFI", "1.0.0") {
        artfiNFT = ArtfiNFT(_artfi);
        whitelister = _whitelister;
    }

    /**
     * @notice Add or remove pay token
     * @param _token  address of token
     * @param _flag  bool flag for token
     */
    function updateToken(address _token, bool _flag) external onlyOwner {
        payToken[_token] = _flag;
    }

    /**
     * @notice Set treasury
     * @param _treasury  address of treasury wallet
     */
    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    /**
     * @notice Set whitelister
     * @param _whitelister  address of whitelister
     */
    function setWhitelister(address _whitelister) external onlyOwner {
        whitelister = _whitelister;
    }

    /**
     * @notice Add new whitelist
     * @param _whitelist  Whitelist info
     */
    function addWhitelist(
        bytes32 _whitelistID,
        Whitelist calldata _whitelist
    ) external onlyOwner {
        whitelist[_whitelistID] = _whitelist;
        emit AddWhitelist(_whitelist);
    }

    /**
     * @notice Distribute assets
     * @param _token  Address of token
     * @param _amount  Amount of token
     */
    function _distribute(
        address _token,
        uint _amount
    ) private {

    }

    /**
     * @notice Verify the signature
     * @param _user  Address of token
     * @param _fractions  Amount of token
     * @param _price  total price
     * @param _signature  bytes signature
     */
    function _verify(
        address _user,
        uint256 _price,
        bytes memory _signature,
        string memory _fractions
    ) private view returns (bool) {
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
            keccak256("Fraction(address walletAddress, string fractionInfo, uint256 price)"),
            _user,
            _fractions,
            _price
        )));

        return ECDSA.recover(digest, _signature) == whitelister;
    }

    /**
     * @notice Deposit with Stablecoin
     * @param _token  Address of stablecoin
     * @param _fractions  Amount of token
     * @param _price  total price
     * @param _signature  bytes info for verification
     */
    function doWhitelist(
        address _token,
        uint256 _price,
        bytes32 _whitelist,
        string memory _fractions,
        bytes calldata _signature
    ) external payable nonReentrant {
        require(payToken[_token], "Invalid token");

        Whitelist storage info = whitelist[_whitelist];
        require(info.startTime <= block.timestamp && 
            info.startTime + info.lockTime >= block.timestamp, "Invalid whitelist");

        string[] memory fractions = _fractions.split(",");
        uint256 _amount = fractions.length;
        require(_amount > 0, "Invalid fractions");

        require(_verify(msg.sender, _price, _signature, _fractions), "Invalid signature");

        // receive token
        if(_token == wmatic) require(msg.value == _price, "Invalid matic");
        else IERC20(_token).safeTransferFrom(msg.sender, address(this), _price);

        UserInfo storage userItem = userInfo[msg.sender][_whitelist];
        userItem.amount = _amount;
        userItem.token = _token;
        userItem.price = _price;

        emit Deposit(msg.sender, _whitelist, _amount, _token);
    }

    /**
     * @notice Withdraw without mint
     * @param _whitelist  ID of whitelist
     */
    function claim(bytes32 _whitelist) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender][_whitelist];
        require(user.amount != 0, "Not whitelisted");
        require(user.stat == Stat.Deposit, "Can not withdraw");

        Whitelist storage info = whitelist[_whitelist];
        require(info.startTime + info.lockTime >= block.timestamp, "Wait");

        user.stat = Stat.Claim;
        if(user.token == wmatic) {
            (bool success, ) = payable(msg.sender).call{value: user.amount}("");
            require(success, "Failed to send matic");
        } else {
            IERC20(user.token).safeTransfer(msg.sender, user.amount);
        }

        emit Claim(msg.sender, _whitelist);
    }

    /**
     * @notice Mint NFT
     * @param _whitelist  whitelist id
     */
    function mint(bytes32 _whitelist) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender][_whitelist];
        require(user.amount != 0, "Not whitelisted");
        require(user.stat == Stat.Deposit, "Can not mint");

        Whitelist storage info = whitelist[_whitelist];
        require(info.startTime + info.lockTime >= block.timestamp, "Wait");

        user.stat = Stat.Mint;

        // distribute reward
        _distribute(user.token, user.amount);

        artfiNFT.mint(msg.sender, 1);

        emit Mint(msg.sender, _whitelist);
    }

    /**
     * @notice Redeposit after claim
     * @param _token  Address of token
     * @param _amount  Amount of token
     * @param _whitelist  whitelist ID
     */
    function reWhitelist(
        address _token,
        uint _amount,
        bytes32 _whitelist
    ) external payable nonReentrant {
        UserInfo storage user = userInfo[msg.sender][_whitelist];
        require(user.amount != 0, "Not whitelisted");
        require(user.stat == Stat.Claim, "Can not redeposit");

        Whitelist storage info = whitelist[_whitelist];
        require(info.startTime + info.lockTime >= block.timestamp, "Wait");

        if(_token == wmatic) require(msg.value == _amount, "Invalid matic");
        else IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        user.stat = Stat.Redeposit;
        user.amount = _amount;
        user.token = _token;

        // distribute reward
        _distribute(_token, _amount);

        artfiNFT.mint(msg.sender, 1);

        emit Redeposit(msg.sender, _whitelist, _amount, _token);
    }
}