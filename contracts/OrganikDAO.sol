/** /
    ORGANIK DAO
    February 2022
    Deployed by Organik, INC.
/**/
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// OpenZeppelin Contracts v4.4.1 (token/ERC20/ERC20.sol)
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.4/contracts/token/ERC20/ERC20.sol"
// Organik Contracts v0.0.1 (contracts/OrganikDAO.sol)
contract OrganikDao is ReentrancyGuard, AccessControl, ERC20 {

    constructor () public ERC20 ("OrganikDAO", "ORGANIK") {
        _mint(msg.sender, 1000000 * (10 ** uint256(decimals()) ) )
        // This line will mint 1M coins to the Contract Address.
    }

    bytes32 public constant FARMER = keccak256("FARMER");
    bytes32 public constant MEMBER = keccak256("MEMBER");
    bytes32 public constant STAKEHOLDER = keccak256("STAKEHOLDER");

    uint32 constant votingPeriodA = 1 day;
    uint32 constant votingPeriodB = 2 days;
    uint32 constant votingPeriodC = 3 days;

    uint256 public proposalsCount = 0;
    uint256 public eventsCount = 0;
    uint256 public bookingsCount = 0;

}