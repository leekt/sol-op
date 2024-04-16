//SPDX-License-Identifier :
pragma solidity ^0.8.0;

import {Surl} from "surl/Surl.sol";
import {VmSafe} from "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";
import {slice, toUint256} from "./BytesLib.sol";
import {LibString} from "solady/utils/LibString.sol";
import {IEntryPoint} from "./interfaces/IEntryPoint.sol";
import "./Structs.sol";
import {UserOperationLib} from "./UserOperationLib.sol";

address constant ENTRYPOINT_0_7 = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

/// @notice zerodev library to use with solidity directly
contract ZeroDev {
    error RequestFailed(uint256 status);

    VmSafe private constant vm = VmSafe(address(uint160(uint256(keccak256("hevm cheat code")))));

    using Surl for *;
    using UserOperationLib for PackedUserOperation;

    string public rpcNode;
    string public bundler;
    string public paymaster;
    uint256 public remoteChainId;

    constructor(string memory _rpc, string memory _bundler, string memory _paymaster) {
        rpcNode = _rpc;
        bundler = _bundler;
        paymaster = _paymaster;
        remoteChainId = chainId();
    }

    function getUserOpHash(PackedUserOperation calldata userOp) public view returns (bytes32) {
        return keccak256(abi.encode(userOp.hash(), address(ENTRYPOINT_0_7), remoteChainId));
    }

    function serializePaymasterPackedOp(PackedUserOperation memory op) internal returns (string memory json) {
        string memory obj = "sponsoredOp";
        vm.serializeUint(obj, "chainId", remoteChainId);
        string memory pop = op.serializePackedOp();
        vm.serializeString(obj, "userOp", pop);
        vm.serializeAddress(obj, "entryPointAddress", ENTRYPOINT_0_7);
        vm.serializeBool(obj, "shouldOverrideFee", true);
        json = vm.serializeBool(obj, "manualGasEstimation", false);
    }

    function rpcCall(string memory rpc, string memory method, string[] memory params, bool isResult32)
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
        (uint256 status, bytes memory rawResponse) = rpc.post(headers, payload);
        // check for error before this
        if (status >= 200 && status < 300) {
            console.log("RawResponse :", string(rawResponse));
            console.log("Encoded :");
            bytes memory encoded = vm.parseJson(string(rawResponse));
            console.logBytes(encoded);
            if (isResult32) {
                assembly ("memory-safe") {
                    data := mload(0x40)
                    mstore(data, 0x20)
                    mstore(add(data, 0x20), mload(add(encoded, 0x80)))
                    mstore(0x40, add(data, 0x40))
                }
            } else {
                assembly ("memory-safe") {
                    data := mload(0x40)
                    let offset := encoded // encoded offset
                    offset := add(add(offset, 0x40), mload(add(offset, 0x80)))
                    mstore(data, sub(add(add(encoded, mload(encoded)), 0x20), offset)) // length of data will be sub(encodedOffset + encodedLength - offset)
                    mcopy(add(data, 0x20), offset, mload(data))
                    mstore(0x40, add(add(data, 0x20), mload(data)))
                }
            }
        } else {
            revert RequestFailed(status);
        }
    }

    function estimateUserOperationGas(PackedUserOperation memory op) public returns (GasEstimationResult memory res) {
        string[] memory params = new string[](2);
        params[0] = op.serializePackedOp();
        params[1] = string(abi.encodePacked('"', LibString.toHexString(ENTRYPOINT_0_7), '"'));
        (RPCJson memory result, bytes memory data) = rpcCall(bundler, "eth_estimateUserOperationGas", params, false);
        bytes[] memory arr = parseDataDynamicArray(data, 5);
        uint256[] memory values = new uint256[](5);
        for (uint256 i = 0; i < arr.length; i++) {
            values[i] = uint256(dynamicToStatic(arr[i]));
        }
        // json is parsed on alphabetical order
        res.callGasLimit = values[0];
        res.paymasterPostOpGasLimit = values[1];
        res.paymasterVerificationGasLimit = values[2];
        res.preVerificationGas = values[3];
        res.verificationGasLimit = values[4];
    }

    function getUserOperationByHash(bytes32 userOpHash) public returns (PackedUserOperation memory) {}

    function getUserOperationGasPrice() public returns (GasPriceResult memory res) {
        string[] memory params = new string[](0);
        (RPCJson memory result, bytes memory data) = rpcCall(bundler, "zd_getUserOperationGasPrice", params, false);
        bytes[] memory structsData = parseDataStructArray(data, 3);
        GasPrice[] memory prices = new GasPrice[](3);
        for (uint256 i = 0; i < 3; i++) {
            bytes[] memory values = parseDataDynamicArray(structsData[i], 2);
            bytes32[] memory staticValues = new bytes32[](2);
            for (uint256 j = 0; j < 2; j++) {
                staticValues[j] = dynamicToStatic(values[j]);
            }
            prices[i].maxFeePerGas = uint256(staticValues[0]);
            prices[i].maxPriorityFeePerGas = uint256(staticValues[1]);
        }
        res.fast = prices[0];
        res.slow = prices[1];
        res.standard = prices[2];
    }

    function chainId() public returns (uint256 id) {
        string[] memory params = new string[](0);
        (RPCJson memory result, bytes memory data) = rpcCall(rpcNode, "eth_chainId", params, false);
        id = uint256(parseDataStatic(data));
    }

    function supportedEntryPoints() public returns (address[] memory entrypoints) {
        string[] memory params = new string[](0);
        (RPCJson memory result, bytes memory data) = rpcCall(bundler, "eth_supportedEntryPoints", params, false);
        bytes32[] memory arrs = parseDataStaticArray(data);
        entrypoints = new address[](arrs.length);
        for (uint256 i = 0; i < arrs.length; i++) {
            entrypoints[i] = address(uint160(uint256(arrs[i])));
        }
    }

    function parseDataStatic(bytes memory data) internal pure returns (bytes32 res) {
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

    function parseDataStaticArray(bytes memory data) internal pure returns (bytes32[] memory arr) {
        uint256 arrLen = uint256(bytes32(slice(data, 0, 32)));
        arr = new bytes32[](arrLen);
        require(data.length >= (arrLen + 1) * 32, "data too small for static array");
        for (uint256 i = 0; i < arrLen; i++) {
            arr[i] = bytes32(slice(data, (i + 1) * 32, 32));
        }
    }

    function parseDataDynamicArray(bytes memory data, uint256 len) internal pure returns (bytes[] memory arr) {
        arr = new bytes[](len);
        for (uint256 i = 0; i < len; i++) {
            uint256 offset = uint256(bytes32(slice(data, i * 32, 32)));
            uint256 datalen = uint256(bytes32(slice(data, offset, 32)));
            arr[i] = slice(data, offset + 32, datalen);
        }
    }

    function parseDataStructArray(bytes memory data, uint256 len) internal pure returns (bytes[] memory arr) {
        arr = new bytes[](len);
        for (uint256 i = 0; i < len; i++) {
            uint256 offset = uint256(bytes32(slice(data, i * 32, 32)));
            uint256 datalen =
                (i == len - 1) ? data.length - offset : uint256(bytes32(slice(data, (i + 1) * 32, 32))) - offset;
            arr[i] = slice(data, offset, datalen);
        }
    }

    function dynamicToStatic(bytes memory data) internal pure returns (bytes32 res) {
        require(data.length <= 32, "data size too big to convert to static");
        bytes memory value = slice(data, 0, data.length);
        assembly {
            res := mload(add(value, 0x20))
        }
        res = res >> ((32 - data.length) * 8);
    }

    function sendUserOperation(PackedUserOperation memory op) public returns (bytes32 userOpHash) {
        string[] memory params = new string[](2);
        params[0] = op.serializePackedOp();
        params[1] = string(abi.encodePacked('"', LibString.toHexString(ENTRYPOINT_0_7), '"'));
        (, bytes memory data) = rpcCall(bundler, "eth_sendUserOperation", params, true);
        userOpHash = bytes32(data);
    }

    function getUserOperationReceipt(bytes32 userOpHash) public returns (UserOperationReceipt memory) {}

    function sponsorUserOperation(PackedUserOperation memory op) public returns (SponsorUserOpResult memory res) {
        string[] memory params = new string[](1);
        string memory json = serializePaymasterPackedOp(op);
        params[0] = json;
        (, bytes memory data) = rpcCall(paymaster, "zd_sponsorUserOperation", params, false);
        PreFormatPaymasterResult memory preformat =
            abi.decode(abi.encodePacked(bytes32(uint256(32)), data), (PreFormatPaymasterResult));
        res.callGasLimit = uint256(dynamicToStatic(preformat.callGasLimit));
        res.paymaster = preformat.paymaster;
        res.paymasterData = preformat.paymasterData;
        res.paymasterPostOpGasLimit = uint256(dynamicToStatic(preformat.paymasterPostOpGasLimit));
        res.paymasterVerificationGasLimit = uint256(dynamicToStatic(preformat.paymasterVerificationGasLimit));
        res.preVerificationGas = uint256(dynamicToStatic(preformat.preVerificationGas));
        res.verificationGasLimit = uint256(dynamicToStatic(preformat.verificationGasLimit));
    }
}
