pragma solidity ^0.8.0;

import "../Structs.sol";
import {Surl} from "surl/Surl.sol";
import {Vm} from "forge-std/Vm.sol";

Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

library RPC {
    using Surl for *;

    error RequestFailed(uint256 status);

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
        if (status >= 200 && status < 300) {
            // TODO : there can be error even if status is 200
            bytes memory encoded = vm.parseJson(string(rawResponse));
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
}
