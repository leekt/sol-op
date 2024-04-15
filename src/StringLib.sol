pragma solidity ^0.8.0;

function toAsciiString(address x) pure returns (string memory) {
    bytes memory s = new bytes(40);
    for (uint256 i = 0; i < 20; i++) {
        bytes1 b = bytes1(uint8(uint256(uint160(x)) / (2 ** (8 * (19 - i)))));
        bytes1 hi = bytes1(uint8(b) / 16);
        bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
        s[2 * i] = hi;
        s[2 * i + 1] = lo;
    }
    return string(s);
}
