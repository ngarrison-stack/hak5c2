// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IERC20.sol";
import "../interfaces/IUniswapV2Router02.sol";

/// @title AutoTokenSale
/// @notice Sells a configured percentage of an ERC-20 token via a Uniswap V2-compatible DEX.
///         Designed to be called right after an airdrop lands in the owner's wallet.
contract AutoTokenSale {
    address public owner;
    IERC20 public immutable token;
    IUniswapV2Router02 public immutable router;
    address public immutable wrappedNative; // WETH, WBNB, etc.
    uint256 public sellPercentage; // basis points (4000 = 40%)
    uint256 public slippageBps; // max slippage in basis points (default 500 = 5%)

    event TokensSold(
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 amountOutActual
    );
    event PercentageUpdated(uint256 oldPct, uint256 newPct);
    event SlippageUpdated(uint256 oldSlip, uint256 newSlip);
    event OwnerUpdated(address oldOwner, address newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    /// @param _token        Address of the BDAG (or any ERC-20) token
    /// @param _router       Address of Uniswap V2-compatible router
    /// @param _sellPctBps   Percentage to sell in basis points (4000 = 40%)
    /// @param _slippageBps  Max slippage in basis points (500 = 5%)
    constructor(
        address _token,
        address _router,
        uint256 _sellPctBps,
        uint256 _slippageBps
    ) {
        require(_token != address(0), "Invalid token");
        require(_router != address(0), "Invalid router");
        require(_sellPctBps > 0 && _sellPctBps <= 10000, "Invalid percentage");
        require(_slippageBps <= 5000, "Slippage too high");

        owner = msg.sender;
        token = IERC20(_token);
        router = IUniswapV2Router02(_router);
        wrappedNative = router.WETH();
        sellPercentage = _sellPctBps;
        slippageBps = _slippageBps;
    }

    /// @notice Call this after the airdrop arrives. Sells `sellPercentage` of
    ///         the caller's token balance for native currency (ETH/BNB/etc.)
    ///         via the DEX router.
    /// @dev    Caller must have approved this contract to spend their tokens first.
    ///         Uses token -> WETH path. Proceeds are sent directly to the caller.
    function sellAirdrop() external onlyOwner {
        uint256 balance = token.balanceOf(msg.sender);
        require(balance > 0, "No tokens to sell");

        uint256 amountToSell = (balance * sellPercentage) / 10000;
        require(amountToSell > 0, "Sell amount is zero");

        // Transfer tokens from owner to this contract
        bool transferred = token.transferFrom(msg.sender, address(this), amountToSell);
        require(transferred, "Transfer failed");

        // Approve router to spend tokens
        token.approve(address(router), amountToSell);

        // Build swap path: TOKEN -> WETH (native)
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = wrappedNative;

        // Get expected output for slippage calculation
        uint256[] memory amountsOut = router.getAmountsOut(amountToSell, path);
        uint256 expectedOut = amountsOut[amountsOut.length - 1];
        uint256 amountOutMin = (expectedOut * (10000 - slippageBps)) / 10000;

        // Execute swap — proceeds go directly to msg.sender
        uint256[] memory amounts = router.swapExactTokensForETH(
            amountToSell,
            amountOutMin,
            path,
            msg.sender,
            block.timestamp + 300 // 5-minute deadline
        );

        emit TokensSold(amountToSell, amountOutMin, amounts[amounts.length - 1]);
    }

    /// @notice Sell a specific amount instead of percentage-based.
    /// @param amount Exact number of tokens to sell (in wei units).
    function sellExact(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount is zero");

        bool transferred = token.transferFrom(msg.sender, address(this), amount);
        require(transferred, "Transfer failed");

        token.approve(address(router), amount);

        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = wrappedNative;

        uint256[] memory amountsOut = router.getAmountsOut(amount, path);
        uint256 expectedOut = amountsOut[amountsOut.length - 1];
        uint256 amountOutMin = (expectedOut * (10000 - slippageBps)) / 10000;

        uint256[] memory amounts = router.swapExactTokensForETH(
            amount,
            amountOutMin,
            path,
            msg.sender,
            block.timestamp + 300
        );

        emit TokensSold(amount, amountOutMin, amounts[amounts.length - 1]);
    }

    // --- Configuration ---

    function setSellPercentage(uint256 _newPctBps) external onlyOwner {
        require(_newPctBps > 0 && _newPctBps <= 10000, "Invalid percentage");
        emit PercentageUpdated(sellPercentage, _newPctBps);
        sellPercentage = _newPctBps;
    }

    function setSlippage(uint256 _newSlippageBps) external onlyOwner {
        require(_newSlippageBps <= 5000, "Slippage too high");
        emit SlippageUpdated(slippageBps, _newSlippageBps);
        slippageBps = _newSlippageBps;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid owner");
        emit OwnerUpdated(owner, _newOwner);
        owner = _newOwner;
    }

    // --- Recovery ---

    /// @notice Recover any ERC-20 tokens accidentally sent to this contract.
    function recoverTokens(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(msg.sender, _amount);
    }

    /// @notice Recover any native currency (ETH/BNB) stuck in the contract.
    function recoverNative() external onlyOwner {
        (bool sent, ) = msg.sender.call{value: address(this).balance}("");
        require(sent, "Transfer failed");
    }

    receive() external payable {}
}
