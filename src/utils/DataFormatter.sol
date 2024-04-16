pragma solidity ^0.8.0;

import "./BytesLib.sol";

library DataFormatter {
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
}
