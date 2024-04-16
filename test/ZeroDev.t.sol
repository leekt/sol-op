// SPDX-License-Identifier : MIT
pragma solidity ^0.8.0;

import {ZeroDev, PackedUserOperation} from "src/ZeroDev.sol";
import {KernelLib} from "src/KernelLib.sol";
import {Kernel} from "kernel_v3/src/Kernel.sol";
import {EntryPointLib} from "src/EntryPointLib.sol";
import {VALIDATION_TYPE_ROOT} from "kernel_v3/src/types/Constants.sol";
import {GasEstimationResult, GasPriceResult} from "src/Structs.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {UserOperationLib} from "src/UserOperationLib.sol";
import "forge-std/Test.sol";

contract ZeroDevTest is Test {
    using UserOperationLib for PackedUserOperation;

    ZeroDev private zd;
    address owner;
    uint256 ownerKey;

    function setUp() external {
        string memory bundler = vm.envString("TEST_BUNDLER");
        string memory rpc = vm.envString("TEST_RPC");
        string memory paymaster = vm.envString("TEST_PAYMASTER");
        uint256 fork = vm.createFork(rpc);
        vm.selectFork(fork);
        zd = new ZeroDev(rpc, bundler, paymaster);
        (owner, ownerKey) = makeAddrAndKey("Owner");
        EntryPointLib.deploy();
        KernelLib.deploy();
    }

    //function test() external {
    //    PackedUserOperation memory op = PackedUserOperation({
    //        sender: address(0),
    //        nonce: 0,
    //        initCode: hex"",
    //        callData: hex"",
    //        accountGasLimits: bytes32(0),
    //        preVerificationGas: 0,
    //        gasFees: bytes32(0),
    //        paymasterAndData: hex"",
    //        signature: hex""
    //    });
    //    zd.estimateUserOperationGas(op);
    //}

    function testKernel() external {
        Kernel kernel = KernelLib.getAddress(owner);
        console.log("Kernel : ", address(kernel));
        PackedUserOperation memory op = KernelLib.prepareUserOp(
            kernel, owner, VALIDATION_TYPE_ROOT, KernelLib.encodeExecute(owner, 1, hex""), false
        );
        zd.estimateUserOperationGas(op);
        GasPriceResult memory res = zd.getUserOperationGasPrice();
        op.applyGasPrice(res.fast);
        bytes32 hash = zd.getUserOpHash(op);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, ECDSA.toEthSignedMessageHash(hash));
        op.signature = abi.encodePacked(r, s, v);
        zd.sendUserOperation(op);
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
