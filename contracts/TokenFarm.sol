// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract TokenFarm is Ownable {

    // tokenaddress -> owner address -> balance
    mapping(address => mapping(address => uint256)) public s_stakingBalance;
    mapping(address => uint256) public uniqueTokenStaked;
    mapping(address => address) public tokenPriceFeedMapping;
    address[] public stakers;
    address[] public s_allowedToken;
    IERC20 public dappToken;

    // stake Token
    function stakeTokens(uint256 amount, address token) public {

        require(amount > 0, "Amount cannot be 0");

        // Only allow credible tokens
        require(tokenIsAllowed(token), "You cannot stake this token");

        // Transfer the token from them to us(this contract)
        // Since we are calling transferFrom so user has to call the approve function not us.
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        updateUniqueTokenStaked(msg.sender, token);
        s_stakingBalance[token][msg.sender] += amount;
        if(uniqueTokenStaked[msg.sender] == 1) {
            stakers.push(msg.sender);
        }
    }

    function updateUniqueTokenStaked(address user, address token) internal {
        if(s_stakingBalance[token][user] <= 0) {
            uniqueTokenStaked[user] += 1;
        }
    }

    function addAllowedTokens(address token) public onlyOwner {
        s_allowedToken.push(token);
    }

    function tokenIsAllowed(address token) public returns (bool) {
        for(uint256 allowedTokensIndex = 0; allowedTokensIndex < s_allowedToken.length; allowedTokensIndex++){
            if(s_allowedToken[allowedTokensIndex] == token){
                return true;
            }
        }
        return false;
    }

    constructor(address _dappTokenAddress) public {
        dappToken = IERC20(_dappTokenAddress);
    }

    function setPriceFeedContract(address _token, address _priceFeed) public onlyOwner {
        tokenPriceFeedMapping[_token] = _priceFeed;
    }
 
    // issue Token
    function issueToken() public onlyOwner {
        //Issue tokens to all stakers
        for( uint256 stakersIndex = 0; stakersIndex < stakers.length; stakersIndex++) {
            address recipient = stakers[stakersIndex];
            uint256 userTotalValue = getUserTotalValue(recipient);
            //send them a token reward
            dappToken.transfer(recipient, userTotalValue);
            //based on their total value locked 
        }
    }

    function getUserTotalValue(address _user) public view returns (uint256) {
        uint256 totalValue = 0;
        require(uniqueTokenStaked[_user] > 0, "No token staked");
        for(uint256 allowedTokensIndex = 0; allowedTokensIndex < s_allowedToken.length; allowedTokensIndex++) {
            totalValue += getUserSingleTokenValue(_user, s_allowedToken[allowedTokensIndex]);
        }
        return totalValue;
    }

    // test this function.
    function getUserSingleTokenValue(address _user, address _token) public view returns (uint256) {
        if(uniqueTokenStaked[_user] <= 0) {
            return 0;
        }
        // Price of the token * stakingBalabce[_token][_user]
        (uint256 price, uint256 decimals) = getTokenValue(_token);
        // 10 ETH
        // ETH/USD -> 100
        //10 * 100 = 1000
        return (s_stakingBalance[_token][_user] * price / (10**decimals));
    }

    function getTokenValue(address _token ) public view returns (uint256, uint256) {
        address priceFeedAddress = tokenPriceFeedMapping[_token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);
        (,int256 price,,,) = priceFeed.latestRoundData();
        uint256 decimals = uint256(priceFeed.decimals());
        return(uint256(price), decimals);
    }

    // unstake Token

    function unstakedToken(address _token) public {
        uint256 balance = s_stakingBalance[_token][msg.sender];
        require(balance > 0, "Staking balance cannot be 0");
        IERC20(_token).transfer(msg.sender, balance);
        s_stakingBalance[_token][msg.sender] = 0;
        uniqueTokenStaked[msg.sender] = uniqueTokenStaked[msg.sender] - 1;

    }
}