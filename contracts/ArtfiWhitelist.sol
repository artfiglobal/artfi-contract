// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./ArtfiNFT.sol";

contract ArtfiWhitelist is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    mapping(address => bool) public payToken;
    mapping(uint => Whitelist) public whitelist;
    mapping(address => mapping(uint => UserInfo)) public userInfo;

    struct Whitelist {
        uint startTime;
        uint lockTime;
        uint maxFraction;
        uint totalFraction;
        bytes name;
    }

    struct UserInfo {
        uint amount;
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
    uint public currentIndex;

    address public treasury;
    address public constant wmatic = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

    event AddWhitelist(Whitelist whitelist);
    event Mint(address indexed user, uint whitelist);
    event Claim(address indexed user, uint whitelist);
    event Deposit(address indexed user, uint whitelist, uint amount, address indexed token);
    event Redeposit(address indexed user, uint whitelist, uint amount, address indexed token);

    /**
     * @notice Construct
     * @param _artfi  address of ArtfiNFT
     */
    constructor(address _artfi) {
        artfiNFT = ArtfiNFT(_artfi);
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
     * @notice Add new whitelist
     * @param _whitelist  Whitelist info
     */
    function addWhitelist(Whitelist calldata _whitelist) external onlyOwner {
        ++currentIndex;
        whitelist[currentIndex] = _whitelist;

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
     * @notice Deposit with Stablecoin
     * @param _token  Address of stablecoin
     * @param _amount  Amount of stablecoin
     */
    function deposit(
        address _token,
        uint _amount
    ) external payable nonReentrant {
        require(_amount != 0, "Invalid amount");
        require(payToken[_token], "Invalid token");

        if(_token == wmatic) require(msg.value == _amount, "Invalid matic");
        else IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        UserInfo storage info = userInfo[msg.sender][currentIndex];
        info.amount = _amount;
        info.token = _token;

        emit Deposit(msg.sender, currentIndex, _amount, _token);
    }

    /**
     * @notice Withdraw without mint
     */
    function claim() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender][currentIndex];
        require(user.amount != 0, "Not whitelisted");
        require(user.stat == Stat.Deposit, "Can not withdraw");

        Whitelist storage info = whitelist[currentIndex];
        require(info.startTime + info.lockTime >= block.timestamp, "Wait");

        user.stat = Stat.Claim;
        if(user.token == wmatic) {
            (bool success, ) = payable(msg.sender).call{value: user.amount}("");
            require(success, "Failed to send matic");
        } else {
            IERC20(user.token).safeTransfer(msg.sender, user.amount);
        }

        emit Claim(msg.sender, currentIndex);
    }

    /**
     * @notice Mint NFT
     */
    function mint() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender][currentIndex];
        require(user.amount != 0, "Not whitelisted");
        require(user.stat == Stat.Deposit, "Can not mint");

        Whitelist storage info = whitelist[currentIndex];
        require(info.startTime + info.lockTime >= block.timestamp, "Wait");

        user.stat = Stat.Mint;

        // distribute reward
        _distribute(user.token, user.amount);

        artfiNFT.mint(msg.sender, 1);

        emit Mint(msg.sender, currentIndex);
    }

    /**
     * @notice Redeposit after claim
     * @param _token  Address of token
     * @param _amount  Amount of token
     */
    function redeposit(
        address _token,
        uint _amount
    ) external payable nonReentrant {
        UserInfo storage user = userInfo[msg.sender][currentIndex];
        require(user.amount != 0, "Not whitelisted");
        require(user.stat == Stat.Claim, "Can not redeposit");

        Whitelist storage info = whitelist[currentIndex];
        require(info.startTime + info.lockTime >= block.timestamp, "Wait");

        if(_token == wmatic) require(msg.value == _amount, "Invalid matic");
        else IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        user.stat = Stat.Redeposit;
        user.amount = _amount;
        user.token = _token;

        // distribute reward
        _distribute(_token, _amount);

        artfiNFT.mint(msg.sender, 1);

        emit Redeposit(msg.sender, currentIndex, _amount, _token);
    }
}