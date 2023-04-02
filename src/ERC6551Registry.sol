// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/utils/introspection/ERC165Checker.sol";
import "openzeppelin-contracts/utils/Create2.sol";

import "./interfaces/IERC6551Registry.sol";
import "./interfaces/IERC6551Account.sol";
import "./lib/ERC6551AccountByteCode.sol";

contract ERC6551Registry is IERC6551Registry {
    error InvalidImplementation();
    error InitializationFailed();

    function createAccount(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 seed,
        bytes calldata initData
    ) external returns (address) {
        bytes32 salt = keccak256(abi.encode(chainId, tokenContract, tokenId, seed));
        bytes memory code = ERC6551AccountByteCode.createCode(
            implementation,
            chainId,
            tokenContract,
            tokenId,
            seed
        );

        address _account = Create2.deploy(0, salt, code);

        if (initData.length != 0) {
            (bool success, ) = _account.call(initData);
            if (!success) revert InitializationFailed();
        }

        bool isValidImplementation = ERC165Checker.supportsInterface(
            _account,
            type(IERC6551Account).interfaceId
        );

        if (!isValidImplementation) revert InvalidImplementation();

        emit AccountCreated(_account, implementation, chainId, tokenContract, tokenId, seed);

        return _account;
    }

    function account(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 seed
    ) external view returns (address) {
        bytes32 salt = keccak256(abi.encode(chainId, tokenContract, tokenId, seed));
        bytes32 bytecodeHash = keccak256(
            ERC6551AccountByteCode.createCode(implementation, chainId, tokenContract, tokenId, seed)
        );

        return Create2.computeAddress(salt, bytecodeHash);
    }
}
