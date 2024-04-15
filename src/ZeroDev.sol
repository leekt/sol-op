//SPDX-License-Identifier :
pragma solidity ^0.8.0;

import {Surl} from "surl/Surl.sol";
import {VmSafe} from "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";
import {slice, toUint256} from "./BytesLib.sol";
import {toHexString} from "./StringLib.sol";

import "./Structs.sol";

address constant ENTRYPOINT_0_7 = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

/// @notice zerodev library to use with solidity directly
contract ZeroDev {
    error RequestFailed(uint256 status);

    VmSafe private constant vm = VmSafe(address(uint160(uint256(keccak256("hevm cheat code")))));

    using Surl for *;

    string public rpcNode;
    string public bundler;
    string public paymaster;

    constructor(string memory _rpc, string memory _bundler, string memory _paymaster) {
        rpcNode = _rpc;
        bundler = _bundler;
        paymaster = _paymaster;
    }

    function serializePackedOp(PackedUserOperation memory op) internal returns (string memory json) {
        string memory obj = "op";
        vm.serializeAddress(obj, "sender", op.sender);
        vm.serializeUint(obj, "nonce", op.nonce);
        if (op.initCode.length > 0) {
            vm.serializeAddress(obj, "factory", address(bytes20(slice(op.initCode, 0, 20))));
            vm.serializeBytes(obj, "factoryData", slice(op.initCode, 20, op.initCode.length - 20));
        } else {
            //vm.serializeBytes(obj, "factory", hex"");
            //vm.serializeBytes(obj, "factoryData", hex"");
        }
        vm.serializeBytes(obj, "callData", op.callData);
        vm.serializeUint(obj, "callGasLimit", uint128(uint256(op.accountGasLimits)));
        vm.serializeUint(obj, "verificationGasLimit", uint128(uint256(op.accountGasLimits >> 128)));
        vm.serializeUint(obj, "preVerificationGas", op.preVerificationGas);
        vm.serializeUint(obj, "maxFeePerGas", uint128(uint256(op.gasFees)));
        vm.serializeUint(obj, "maxPriorityFeePerGas", uint128(uint256(op.gasFees >> 128)));
        if (op.paymasterAndData.length > 0) {
            vm.serializeAddress(obj, "paymaster", address(bytes20(slice(op.paymasterAndData, 0, 20))));
            vm.serializeUint(obj, "paymasterVerificationGasLimit", uint128(bytes16(slice(op.paymasterAndData, 20, 16))));
            vm.serializeUint(obj, "paymasterPostOpGasLimit", uint128(bytes16(slice(op.paymasterAndData, 36, 52))));
            vm.serializeBytes(obj, "paymasterData", slice(op.paymasterAndData, 52, op.paymasterAndData.length - 52));
        } else {
            //vm.serializeBytes(obj, "paymaster", hex"");
            //vm.serializeUint(obj, "paymasterVerificationGasLimit", 0);
            //vm.serializeUint(obj, "paymasterPostOpGasLimit", 0);
            //vm.serializeBytes(obj, "paymasterAndData", hex"");
        }
        json = vm.serializeBytes(obj, "signature", op.signature);
    }

    function rpcCall(string memory rpc, string memory method, string[] memory params)
        internal
        returns (RPCJson memory response, bytes memory data)
    {
        string[] memory headers = new string[](1);
        headers[0] = "Content-Type: application/json";
        string memory payload = '{"id":1, "jsonrpc": "2.0", "method": "';
        payload = string(abi.encodePacked(payload, method, '","params": ['));
        for (uint256 i = 0; i < params.length; i++) {
            if (i != params.length - 1) {
                payload = string(abi.encodePacked(payload, params[i], ","));
            } else {
                payload = string(abi.encodePacked(payload, params[i]));
            }
        }
        payload = string(abi.encodePacked(payload, "]}"));
        console.log("Payload :", payload);
        (uint256 status, bytes memory rawResponse) = rpc.post(headers, payload);
        console.log("RawResponse : ", string(rawResponse));
        // parse response
        if (status >= 200 && status < 300) {
            bytes memory encoded = vm.parseJson(string(rawResponse));
            console.log("Encoded :");
            console.logBytes(encoded);
            bytes32 debug;
            assembly ("memory-safe") {
                data := mload(0x40)
                let offset := encoded // encoded offset
                debug := mload(offset)
                offset := add(add(offset, 0x40), mload(add(offset, 0x80)))
                debug := offset
                debug := encoded
                mstore(data, sub(add(add(encoded, mload(encoded)), 0x20), offset)) // length of data will be sub(encodedOffset + encodedLength - offset)
                mcopy(add(data, 0x20), offset, mload(data))
                mstore(0x40, add(add(data, 0x20), mload(data)))
            }
        } else {
            revert RequestFailed(status);
        }
    }

    function estimateUserOperationGas(PackedUserOperation memory op) public returns (uint256) {
        string[] memory params = new string[](2);
        params[0] = serializePackedOp(op);
        params[1] = string(abi.encodePacked('"', toHexString(ENTRYPOINT_0_7), '"'));
        console.log("EP", params[1]);
        (RPCJson memory result, bytes memory data) = rpcCall(bundler, "eth_estimateUserOperationGas", params);
        console.log("DEBUG");
        console.logBytes(data);
    }

    function getUserOperationByHash(bytes32 hash) public returns (PackedUserOperation memory) {}

    function getUserOperationReceipt(bytes32 hash) public returns (UserOperationReceipt memory) {}

    function chainId() public returns (uint256 id) {
        string[] memory params = new string[](0);
        (RPCJson memory result, bytes memory data) = rpcCall(rpcNode, "eth_chainId", params);
        id = uint256(parseDataStatic(data));
    }

    function supportedEntryPoints() public returns (address[] memory entrypoints) {
        string[] memory params = new string[](0);
        (RPCJson memory result, bytes memory data) = rpcCall(bundler, "eth_supportedEntryPoints", params);
        bytes32[] memory arrs = parseDataStaticArray(data);
        entrypoints = new address[](arrs.length);
        for (uint256 i = 0; i < arrs.length; i++) {
            entrypoints[i] = address(uint160(uint256(arrs[i])));
        }
    }

    function parseDataStatic(bytes memory data) internal view returns (bytes32 res) {
        uint256 dataSize = uint256(bytes32(slice(data, 0, 32)));
        require(data.length >= dataSize + 32, "data too small for static");
        require(dataSize <= 32, "data size too big for static");
        if (dataSize < 32) {
            bytes memory value = slice(data, 32, dataSize);
            assembly {
                res := mload(add(value, 0x20))
            }
            return res >> ((32 - dataSize) * 8);
        }
    }

    function parseDataStaticArray(bytes memory data) internal view returns (bytes32[] memory arr) {
        uint256 arrLen = uint256(bytes32(slice(data, 0, 32)));
        arr = new bytes32[](arrLen);
        require(data.length >= (arrLen + 1) * 32, "data too small for static array");
        for (uint256 i = 0; i < arrLen; i++) {
            arr[i] = bytes32(slice(data, (i + 1) * 32, 32));
        }
    }

    function sendUserOperation(PackedUserOperation memory op) public returns (bytes32 userOpHash) {
        string[] memory params = new string[](2);
        params[0] = serializePackedOp(op);
        params[1] = toHexString(ENTRYPOINT_0_7);
        (, bytes memory data) = rpcCall(bundler, "eth_sendUserOperation", params);
        userOpHash = parseDataStatic(data);
    }

    function sponsorUserOperation(PackedUserOperation memory op) public returns (PackedUserOperation memory) {}
}
