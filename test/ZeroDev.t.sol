// SPDX-License-Identifier : MIT
pragma solidity ^0.8.0;

import {ZeroDev, PackedUserOperation} from "src/ZeroDev.sol";
import "forge-std/Test.sol";

contract ZeroDevTest is Test {
    ZeroDev private zd;

    function setUp() external {
        string memory bundler = vm.envString("TEST_BUNDLER");
        string memory rpc = vm.envString("TEST_RPC");
        string memory paymaster = vm.envString("TEST_PAYMASTER");
        zd = new ZeroDev(rpc, bundler, paymaster);
    }

    function test() external {
        PackedUserOperation memory op = PackedUserOperation({
            sender: address(0),
            nonce: 0,
            initCode: hex"",
            callData: hex"",
            accountGasLimits: bytes32(0),
            preVerificationGas: 0,
            gasFees: bytes32(0),
            paymasterAndData: hex"",
            signature: hex""
        });
        zd.estimateUserOperationGas(op);
    }

    function testChainId() external {
        uint256 id = zd.chainId();
        console.log("chain id : ", id);
    }

    function testSupportedEntrypoint() external {
        address[] memory supported = zd.supportedEntryPoints();
        for (uint256 i = 0; i < supported.length; i++) {
            console.log("supported : ", supported[i]);
        }
    }
}
