//SPDX-License-Identifier : MIT
pragma solidity ^0.8.0;

import {Surl} from "surl/Surl.sol";
import {VmSafe} from "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";
import {LibString} from "solady/utils/LibString.sol";
import {IEntryPoint} from "./interfaces/IEntryPoint.sol";
import "./Structs.sol";
import {UserOperationLib} from "./utils/UserOperationLib.sol";
import {RPC} from "./utils/Rpc.sol";
import {DataFormatter} from "./utils/DataFormatter.sol";

address constant ENTRYPOINT_0_7 = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

struct ZD {
    string rpc;
    string bundler;
    string paymaster;
    uint256 remoteChainId;
}

/// @notice zerodev library to use with solidity directly
library ZeroDev {

    VmSafe private constant vm = VmSafe(address(uint160(uint256(keccak256("hevm cheat code")))));
    using RPC for string;
    using DataFormatter for bytes;

    using Surl for *;
    using UserOperationLib for PackedUserOperation;

    function newZD(string memory _rpc, string memory _bundler, string memory _paymaster) internal returns(ZD memory) {
        ZD memory zd = ZD({
            rpc : _rpc,
            bundler : _bundler,
            paymaster : _paymaster,
            remoteChainId : 0
        });
        zd.remoteChainId = chainId(zd);
        return zd;
    }

    function getUserOpHash(ZD memory zd, PackedUserOperation calldata userOp) public view returns (bytes32) {
        return keccak256(abi.encode(userOp.hash(), address(ENTRYPOINT_0_7), zd.remoteChainId));
    }

    function serializePaymasterPackedOp(ZD memory zd, PackedUserOperation memory op) internal returns (string memory json) {
        string memory obj = "sponsoredOp";
        vm.serializeUint(obj, "chainId", zd.remoteChainId);
        string memory pop = op.serializePackedOp();
        vm.serializeString(obj, "userOp", pop);
        vm.serializeAddress(obj, "entryPointAddress", ENTRYPOINT_0_7);
        vm.serializeBool(obj, "shouldOverrideFee", true);
        json = vm.serializeBool(obj, "manualGasEstimation", false);
    }

    function estimateUserOperationGas(ZD memory zd, PackedUserOperation memory op) public returns (GasEstimationResult memory res) {
        string[] memory params = new string[](2);
        params[0] = op.serializePackedOp();
        params[1] = string(abi.encodePacked('"', LibString.toHexString(ENTRYPOINT_0_7), '"'));
        (RPCJson memory result, bytes memory data) = zd.bundler.rpcCall("eth_estimateUserOperationGas", params, false);
        bytes[] memory arr = data.parseDataDynamicArray(5);
        uint256[] memory values = new uint256[](5);
        for (uint256 i = 0; i < arr.length; i++) {
            values[i] = uint256(arr[i].dynamicToStatic());
        }
        // json is parsed on alphabetical order
        res.callGasLimit = values[0];
        res.paymasterPostOpGasLimit = values[1];
        res.paymasterVerificationGasLimit = values[2];
        res.preVerificationGas = values[3];
        res.verificationGasLimit = values[4];
    }

    function getUserOperationGasPrice(ZD memory zd) public returns (GasPriceResult memory res) {
        string[] memory params = new string[](0);
        (RPCJson memory result, bytes memory data) = zd.bundler.rpcCall("zd_getUserOperationGasPrice", params, false);
        bytes[] memory structsData = data.parseDataStructArray(3);
        GasPrice[] memory prices = new GasPrice[](3);
        for (uint256 i = 0; i < 3; i++) {
            bytes[] memory values = structsData[i].parseDataDynamicArray(2);
            bytes32[] memory staticValues = new bytes32[](2);
            for (uint256 j = 0; j < 2; j++) {
                staticValues[j] = values[j].dynamicToStatic();
            }
            prices[i].maxFeePerGas = uint256(staticValues[0]);
            prices[i].maxPriorityFeePerGas = uint256(staticValues[1]);
        }
        res.fast = prices[0];
        res.slow = prices[1];
        res.standard = prices[2];
    }

    function chainId(ZD memory zd) public returns (uint256 id) {
        string[] memory params = new string[](0);
        (RPCJson memory result, bytes memory data) = zd.rpc.rpcCall("eth_chainId", params, false);
        id = uint256(data.parseDataStatic());
    }

    function supportedEntryPoints(ZD memory zd) public returns (address[] memory entrypoints) {
        string[] memory params = new string[](0);
        (RPCJson memory result, bytes memory data) = zd.bundler.rpcCall("eth_supportedEntryPoints", params, false);
        bytes32[] memory arrs = data.parseDataStaticArray();
        entrypoints = new address[](arrs.length);
        for (uint256 i = 0; i < arrs.length; i++) {
            entrypoints[i] = address(uint160(uint256(arrs[i])));
        }
    }

    function sendUserOperation(ZD memory zd, PackedUserOperation memory op) public returns (bytes32 userOpHash) {
        string[] memory params = new string[](2);
        params[0] = op.serializePackedOp();
        params[1] = string(abi.encodePacked('"', LibString.toHexString(ENTRYPOINT_0_7), '"'));
        (, bytes memory data) = zd.bundler.rpcCall("eth_sendUserOperation", params, true);
        userOpHash = bytes32(data);
    }

    function sponsorUserOperation(ZD memory zd, PackedUserOperation memory op) public returns (SponsorUserOpResult memory res) {
        string[] memory params = new string[](1);
        string memory json = serializePaymasterPackedOp(zd, op);
        params[0] = json;
        (, bytes memory data) = zd.paymaster.rpcCall("zd_sponsorUserOperation", params, false);
        PreFormatPaymasterResult memory preformat =
            abi.decode(abi.encodePacked(bytes32(uint256(32)), data), (PreFormatPaymasterResult));
        res.callGasLimit = uint256(preformat.callGasLimit.dynamicToStatic());
        res.paymaster = preformat.paymaster;
        res.paymasterData = preformat.paymasterData;
        res.paymasterPostOpGasLimit = uint256(preformat.paymasterPostOpGasLimit.dynamicToStatic());
        res.paymasterVerificationGasLimit = uint256(preformat.paymasterVerificationGasLimit.dynamicToStatic());
        res.preVerificationGas = uint256(preformat.preVerificationGas.dynamicToStatic());
        res.verificationGasLimit = uint256(preformat.verificationGasLimit.dynamicToStatic());
    }

    function getUserOperationByHash(bytes32 userOpHash) public returns (PackedUserOperation memory) {}

    function getUserOperationReceipt(bytes32 userOpHash) public returns (UserOperationReceipt memory) {}
}
