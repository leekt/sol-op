pragma solidity ^0.8.0;

bytes16 constant HEX_DIGITS = "0123456789abcdef";

/**
 * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
 */
function toHexString(uint256 value, uint256 length) pure returns (string memory) {
    uint256 localValue = value;
    bytes memory buffer = new bytes(2 * length + 2);
    buffer[0] = "0";
    buffer[1] = "x";
    for (uint256 i = 2 * length + 1; i > 1; --i) {
        buffer[i] = HEX_DIGITS[localValue & 0xf];
        localValue >>= 4;
    }
    require(localValue == 0, "StringsInsufficientHexLength");
    return string(buffer);
}

/**
 * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal
 * representation.
 */
function toHexString(address addr) pure returns (string memory) {
    return toHexString(uint256(uint160(addr)), 20);
}
