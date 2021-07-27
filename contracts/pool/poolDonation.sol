// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

// This contract is used for those who are non-members but want to
// contribute to some group
// That person gets some different token,
// but even then, 1 token = 1 USD
// This should be able to take multiple token name - address pairs and
// take donations in those tokens
// Also it should use Chainlink to convert token value to USD value
// and transfer same amount of token to donator

// Optionally and preferrably, use Uniswap to swap recieved token type to accepted token in pool
// and transfer it to the pool from here
